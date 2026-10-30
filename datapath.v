//agregar los 4 registros del pipeline, el registro de IF/ID,
//el registro de ID/EX, el registro de EX/MEM y el registro de MEM/WB.
// Cada uno de estos registros debe almacenar la información relevante
//para cada etapa del pipeline, como la instrucción, los operandos,
//los resultados intermedios, etc. Además, se deben agregar las señales
//de control necesarias para manejar el flujo de datos entre las etapas
//del pipeline y evitar conflictos de datos (hazards).

module datapath(
    input          clk,
    input          reset,

    input  [1:0]  ResultSrcD,
    input          MemWriteD,
    input          MemReadD,
    input          BranchD,
    input          JumpD,
    input          ALUSrcD,
    input          RegWriteD,
    input  [1:0]  ImmSrcD,
    input  [2:0]  ALUControlD,
    input  [4:0]  DualRs1D,
    input  [4:0]  DualRs2D,

    input          StallF,
    input          StallD,
    input          FlushE,
    input          FlushD,
    input  [1:0]  ForwardAE,
    input  [1:0]  ForwardBE,

    output reg [31:0] PCF,
    input      [31:0] InstrF,
    output     [31:0] ALUResultM,
    output     [31:0] WriteDataM,
    input      [31:0] ReadDataM,
    output            MemWriteM,

    // INTERFAZ HAZARD UNIT
    output     [4:0]  Rs1E,
    output     [4:0]  Rs2E,
    output     [4:0]  RdE,
    output     [4:0]  RdM,
    output     [4:0]  RdW,
    output            RegWriteM,
    output            RegWriteW,
    output            MemReadE,
    output     [31:0] InstrD, 
    output     [31:0] MainRD1D,
    output     [31:0] MainRD2D,
    output     [31:0] DualRD1D,
    output     [31:0] DualRD2D,
    output            PCSrcE  //Para que la Hazard Unit sepa cuándo limpiar el pipeline (Flush) debido a un salto tomado, necesita recibir la señal PCSrcE
  );

localparam WIDTH = 32;

// --- SEÑALES INTERNAS ---
// Fetch (F)
wire [31:0] PCNextF;
wire [31:0] PCPlus4F;
wire [31:0] PCTargetE;
wire [31:0] InstrDecompF;  // Cable para la instrucción expandida a 32 bits
wire [31:0] PCIncF;         // Incremento dinámico (+2 o +4)
wire [31:0] InstrF_Aligned; // Instrucción alineada a límites de 2 bytes

// Decode (D)
reg  [31:0] PCD;
reg  [31:0] PCPlus4D;
reg  [31:0] InstrD_reg;
wire [31:0] RD1D;
wire [31:0] RD2D;
wire [31:0] ImmExtD;

// Execute (E)
reg  [31:0] RD1E;
reg  [31:0] RD2E;
reg  [31:0] PCD_E;
reg  [31:0] ImmExtE;
reg  [31:0] PCPlus4E;
reg  [4:0]  Rs1E_reg;
reg  [4:0]  Rs2E_reg;
reg  [4:0]  RdE_reg;
reg          RegWriteE;
reg          MemWriteE;
reg          MemReadE_reg;
reg          JumpE;
reg          BranchE;
reg          ALUSrcE; 
reg  [1:0]  ResultSrcE;
reg  [2:0]  ALUControlE;
reg  [2:0]  Funct3E;  // Captura el tipo de Branch (beq, bne, blt, bge)
reg  [6:0]  OpcodeE;  // Captura el tipo de Jump (jal, jalr)
wire [31:0] SrcAE;
wire [31:0] SrcBE;
wire [31:0] WriteDataE;
wire [31:0] ALUResultE;
wire        ZeroE;
reg          TakeBranchE;
wire [31:0] PCBaseE;

// Memory (M)
reg  [31:0] ALUResultM_reg;
reg  [31:0] WriteDataM_reg;
reg  [31:0] PCPlus4M;
reg  [4:0]  RdM_reg;
reg          RegWriteM_reg;
reg          MemWriteM_reg;
reg  [1:0]  ResultSrcM;

// Writeback (W)
reg  [31:0] ALUResultW;
reg  [31:0] ReadDataW;
reg  [31:0] PCPlus4W;
reg  [4:0]  RdW_reg;
reg          RegWriteW_reg;
reg  [1:0]  ResultSrcW;
wire [31:0] ResultW;


// ==========================================
// ETAPA FETCH (F) - MODIFICADA PARA RVC
// ==========================================
always @(posedge clk or posedge reset) begin
    if (reset)
        PCF <= 32'd0;
    else if (!StallF)
        PCF <= PCNextF;
end

// 1. Alineación a 2 bytes (Half-word)
// Si PCF[1] es 1, la instrucción comprimida está guardada en la mitad superior de los 32 bits [31:16]
assign InstrF_Aligned = (PCF[1]) ? {16'd0, InstrF[31:16]} : InstrF;

// 2. Instanciación del módulo Descompresor
decompressor dec (
    .instr_in  (InstrF_Aligned),
    .instr_out (InstrDecompF)
);

// 3. Cálculo de incremento dinámico del PC
// Si los bits [1:0] de la instrucción alineada NO son 2'b11, es una instrucción comprimida de 16 bits (+2 bytes)
assign PCIncF = (InstrF_Aligned[1:0] != 2'b11) ? 32'd2 : 32'd4;
assign PCPlus4F = PCF + PCIncF; // Mantiene el nombre original para no alterar el resto del pipeline

mux2 #(WIDTH) pcmux (
    .d0 (PCPlus4F),
    .d1 (PCTargetE),
    .s  (PCSrcE),
    .y  (PCNextF)
);


// ==========================================
// --- REGISTRO IF/ID --- MODIFICADO PARA RVC
// ==========================================
always @(posedge clk or posedge reset) begin
    if (reset | FlushD) begin
        InstrD_reg <= 32'd0;
        PCD        <= 32'd0;
        PCPlus4D   <= 32'd0;
    end else if (!StallD) begin
        InstrD_reg <= InstrDecompF; // <--- Guarda la instrucción ya traducida/expandida a 32 bits
        PCD        <= PCF;
        PCPlus4D   <= PCPlus4F;
    end
end

assign InstrD = InstrD_reg;


// ==========================================
// ETAPA DECODE (D)
// ==========================================
  regfile rf (
    .clk (clk),
    .we3 (RegWriteW_reg),
    .a1  (InstrD[19:15]),
    .a2  (InstrD[24:20]),
    .a3  (RdW_reg),
    .a4  (DualRs1D),
    .a5  (DualRs2D),
    .wd3 (ResultW),
    .rd1 (RD1D),
    .rd2 (RD2D),
    .rd4 (DualRD1D),
    .rd5 (DualRD2D)
  );

 assign MainRD1D = RD1D;
 assign MainRD2D = RD2D;

extend ext (
    .instr   (InstrD[31:7]),
    .immsrc  (ImmSrcD),
    .immext  (ImmExtD)
);


// ==========================================
// --- REGISTRO ID/EX ---
// ==========================================
always @(posedge clk or posedge reset) begin
    if (reset | FlushE) begin
        RegWriteE    <= 1'b0;
        MemWriteE    <= 1'b0;
        MemReadE_reg <= 1'b0;
        JumpE        <= 1'b0;
        BranchE      <= 1'b0;
        ALUSrcE      <= 1'b0;
        ResultSrcE   <= 2'b00;
        ALUControlE  <= 3'b000;
        RD1E         <= 32'd0;
        RD2E         <= 32'd0;
        PCD_E        <= 32'd0;
        ImmExtE      <= 32'd0;
        PCPlus4E     <= 32'd0;
        Rs1E_reg     <= 5'd0;
        Rs2E_reg     <= 5'd0;
        RdE_reg      <= 5'd0;
        Funct3E      <= 3'b000;
        OpcodeE      <= 7'b0000000;
    end else begin
        RegWriteE    <= RegWriteD;
        MemWriteE    <= MemWriteD;
        MemReadE_reg <= MemReadD;
        JumpE        <= JumpD;
        BranchE      <= BranchD;
        ALUSrcE      <= ALUSrcD;
        ResultSrcE   <= ResultSrcD;
        ALUControlE  <= ALUControlD;
        RD1E         <= RD1D;
        RD2E         <= RD2D;
        PCD_E        <= PCD;
        ImmExtE      <= ImmExtD;
        PCPlus4E     <= PCPlus4D;
        Rs1E_reg     <= InstrD[19:15];
        Rs2E_reg     <= InstrD[24:20];
        RdE_reg      <= InstrD[11:7];
        Funct3E      <= InstrD[14:12]; // Propaga funct3 para discriminar branches
        OpcodeE      <= InstrD[6:0];   // Propaga opcode para discriminar jalr
    end
end

assign Rs1E     = Rs1E_reg;
assign Rs2E     = Rs2E_reg;
assign RdE      = RdE_reg;
assign MemReadE = MemReadE_reg;


// ==========================================
// ETAPA EXECUTE (E)
// ==========================================
mux3 #(WIDTH) fa_mux (
    .d0 (RD1E),
    .d1 (ResultW),
    .d2 (ALUResultM),
    .s  (ForwardAE),
    .y  (SrcAE)
);

mux3 #(WIDTH) fb_mux (
    .d0 (RD2E),
    .d1 (ResultW),
    .d2 (ALUResultM),
    .s  (ForwardBE),
    .y  (WriteDataE)
);

mux2 #(WIDTH) srcbmux (
    .d0 (WriteDataE),
    .d1 (ImmExtE),
    .s  (ALUSrcE),
    .y  (SrcBE)
);

alu alu (
    .a          (SrcAE),
    .b          (SrcBE),
    .alucontrol (ALUControlE),
    .result     (ALUResultE),
    .zero       (ZeroE)
);

// Unidad de Evaluación de Ramas (Soporta beq, bne, blt, bge)
always @(*) begin
    case (Funct3E)
        3'b000:  TakeBranchE = ZeroE;                             // beq
        3'b001:  TakeBranchE = ~ZeroE;                            // bne
        3'b100:  TakeBranchE = ($signed(SrcAE) < $signed(SrcBE));   // blt
        3'b101:  TakeBranchE = ($signed(SrcAE) >= $signed(SrcBE));  // bge
        default: TakeBranchE = 1'b0;
    endcase
end

// Selección de base para el cálculo del objetivo del salto (jalr usa SrcAE)
assign PCBaseE   = (OpcodeE == 7'b1100111) ? SrcAE : PCD_E;
assign PCSrcE    = JumpE | (BranchE & TakeBranchE);

wire [31:0] PCTargetRawE;

adder pcaddbranch (
    .a (PCBaseE),
    .b (ImmExtE),
    .y (PCTargetRawE)  // FIX: conectar al wire Raw, no al wire final
);

// jalr/c.jr/c.jalr fuerzan el bit 0 del destino a 0, como indica RV32I.
assign PCTargetE = (OpcodeE == 7'b1100111) ? {PCTargetRawE[31:1], 1'b0} : PCTargetRawE;


// ==========================================
// --- REGISTRO EX/MEM ---
// ==========================================
always @(posedge clk or posedge reset) begin
    if (reset) begin
        RegWriteM_reg  <= 1'b0;
        MemWriteM_reg  <= 1'b0;
        ResultSrcM     <= 2'b00;
        ALUResultM_reg <= 32'd0;
        WriteDataM_reg <= 32'd0;
        RdM_reg        <= 5'd0;
        PCPlus4M       <= 32'd0;
    end else begin
        RegWriteM_reg  <= RegWriteE;
        MemWriteM_reg  <= MemWriteE;
        ResultSrcM     <= ResultSrcE;
        ALUResultM_reg <= ALUResultE;
        WriteDataM_reg <= WriteDataE;
        RdM_reg        <= RdE_reg;
        PCPlus4M       <= PCPlus4E;
    end
end

assign ALUResultM = ALUResultM_reg;
assign WriteDataM = WriteDataM_reg;
assign MemWriteM  = MemWriteM_reg;
assign RegWriteM  = RegWriteM_reg;
assign RdM        = RdM_reg;


// ==========================================
// ETAPA MEMORY (MEM)
// ==========================================
// --- REGISTRO MEM/WB ---
always @(posedge clk or posedge reset) begin
    if (reset) begin
        RegWriteW_reg <= 1'b0;
        ResultSrcW    <= 2'b00;
        ALUResultW    <= 32'd0;
        ReadDataW     <= 32'd0;
        RdW_reg       <= 5'd0;
        PCPlus4W      <= 32'd0;
    end else begin
        RegWriteW_reg <= RegWriteM_reg;
        ResultSrcW    <= ResultSrcM;
        ALUResultW    <= ALUResultM_reg;
        ReadDataW     <= ReadDataM;
        RdW_reg       <= RdM_reg;
        PCPlus4W      <= PCPlus4M;
    end
end

assign RegWriteW = RegWriteW_reg;
assign RdW       = RdW_reg;


// ==========================================
// ETAPA WRITEBACK (WB)
// ==========================================
mux3 #(WIDTH) resultmux (
    .d0 (ALUResultW),
    .d1 (ReadDataW),
    .d2 (PCPlus4W),
    .s  (ResultSrcW),
    .y  (ResultW)
);

endmodule

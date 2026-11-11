//forwarding + stalling + flushing
module hazard(
    // Identificadores de registros
    input  [4:0]  Rs1E,
    input  [4:0]  Rs2E,
    input  [4:0]  RdE,
    input  [4:0]  RdM,
    input  [4:0]  RdW,
    input  [31:0] InstrD,      // Para extraer Rs1D y Rs2D
    
    // Señales de control para evaluación
    input         RegWriteM,
    input         RegWriteW,
    input         MemReadE,    // Para detectar Load-Use
    input         PCSrcE,      // Salto tomado en la etapa Execute
    
    // Salidas hacia el Datapath
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE,
    output           StallF,
    output           StallD,
    output           FlushE,
    output           FlushD
);

    // Extracción de los registros fuente en la etapa Decode
    wire [4:0] Rs1D = InstrD[19:15];
    wire [4:0] Rs2D = InstrD[24:20];
    wire [6:0] opD = InstrD[6:0];
    wire uses_rs1 = (opD == 7'b0000011) || (opD == 7'b0100011) ||
                    (opD == 7'b0110011) || (opD == 7'b0010011) ||
                    (opD == 7'b1100011) || (opD == 7'b1100111);
    wire uses_rs2 = (opD == 7'b0100011) || (opD == 7'b0110011) ||
                    (opD == 7'b1100011);
    
    wire lwStall; // Cable interno para detectar dependencia Load-Use

    // Adelantamiento a EX: MEM tiene prioridad sobre WB.
    always @(*) begin
        // Forwarding para el operando A (Rs1E)
        if ((Rs1E == RdM) && RegWriteM && (Rs1E != 0)) begin
            ForwardAE = 2'b10; // Adelanta desde MEM
        end else if ((Rs1E == RdW) && RegWriteW && (Rs1E != 0)) begin
            ForwardAE = 2'b01; // Adelanta desde WB
        end else begin
            ForwardAE = 2'b00; // Toma el valor normal del registro
        end

        // Forwarding para el operando B (Rs2E)
        if ((Rs2E == RdM) && RegWriteM && (Rs2E != 0)) begin
            ForwardBE = 2'b10; // Adelanta desde MEM
        end else if ((Rs2E == RdW) && RegWriteW && (Rs2E != 0)) begin
            ForwardBE = 2'b01; // Adelanta desde WB
        end else begin
            ForwardBE = 2'b00; // Toma el valor normal del registro
        end
    end

    // Detiene una dependencia de carga solo si D usa el registro fuente.
    assign lwStall = MemReadE & (RdE != 5'd0) &
                     ((uses_rs1 & (RdE == Rs1D)) |
                      (uses_rs2 & (RdE == Rs2D)));

    // Si hay un riesgo Load-Use, congelamos Fetch y Decode
    assign StallF = lwStall;
    assign StallD = lwStall;

    // 3. LÓGICA DE FLUSHING (Limpieza del pipeline)
    // - FlushE ocurre si hubo un Stall (para insertar una burbuja) O un salto tomado
    // - FlushD ocurre si un salto se hace efectivo en EX, descartando la instrucción incorrecta
    assign FlushE = lwStall | PCSrcE;
    assign FlushD = PCSrcE;

endmodule

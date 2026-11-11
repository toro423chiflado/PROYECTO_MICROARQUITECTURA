module riscv_pipeline(
    input         clk, reset,
    output [31:0] PCF,
    input  [31:0] InstrF,
    output        MemWriteM,
    output [31:0] ALUResultM, WriteDataM,
    input  [31:0] ReadDataM,
    input  [31:0] DualInstrD0, DualInstrD1,
    output [31:0] MainRD1D, MainRD2D,
    output [31:0] DualRD1D, DualRD2D,
    output        FrontendStallD, FrontendFlushD
);

    // Cables internos Control <-> Datapath
    wire [1:0] ResultSrcD, ALUSrcAD;
    wire [2:0] ImmSrcD;
    wire [3:0] ALUControlD;
    wire MemWriteD, MemReadD, BranchD, JumpD, ALUSrcD, RegWriteD;
    
    // Cables internos Hazard <-> Datapath
    wire [31:0] InstrD;
    wire [4:0]  Rs1E, Rs2E, RdE, RdM, RdW;
    wire        RegWriteM, RegWriteW, MemReadE, PCSrcE;
    wire [1:0]  ForwardAE, ForwardBE;
    wire        StallF, StallD, FlushE, FlushD;

    assign FrontendStallD = StallD;
    assign FrontendFlushD = FlushD;

    // 1. Unidad de Control
    controller c(
        .op         (InstrD[6:0]),
        .funct3     (InstrD[14:12]),
        .funct7b5   (InstrD[30]),
        .ResultSrcD (ResultSrcD),
        .MemWriteD  (MemWriteD),
        .MemReadD   (MemReadD),
        .BranchD    (BranchD),
        .JumpD      (JumpD),
        .ALUSrcD    (ALUSrcD),
        .RegWriteD  (RegWriteD),
        .ImmSrcD    (ImmSrcD),
        .ALUControlD(ALUControlD),
        .ALUSrcAD   (ALUSrcAD)
    );

    // 2. Datapath Segmentado
    datapath dp(
        .clk        (clk),
        .reset      (reset),
        // Control
        .ResultSrcD (ResultSrcD),
        .MemWriteD  (MemWriteD),
        .MemReadD   (MemReadD),
        .BranchD    (BranchD),
        .JumpD      (JumpD),
        .ALUSrcD    (ALUSrcD),
        .RegWriteD  (RegWriteD),
        .ImmSrcD    (ImmSrcD),
        .ALUControlD(ALUControlD),
        .ALUSrcAD   (ALUSrcAD),
        .DualRs1D   (DualInstrD1[19:15]),
        .DualRs2D   (DualInstrD1[24:20]),
        // Hazard
        .StallF     (StallF),
        .StallD     (StallD),
        .FlushE     (FlushE),
        .FlushD     (FlushD),
        .ForwardAE  (ForwardAE),
        .ForwardBE  (ForwardBE),
        // Entradas/Salidas de Memoria
        .PCF        (PCF),
        .InstrF     (InstrF),
        .ALUResultM (ALUResultM),
        .WriteDataM (WriteDataM),
        .ReadDataM  (ReadDataM),
        .MemWriteM  (MemWriteM),
        // Retroalimentación a Hazard y Control
        .Rs1E       (Rs1E),
        .Rs2E       (Rs2E),
        .RdE        (RdE),
        .RdM        (RdM),
        .RdW        (RdW),
        .RegWriteM  (RegWriteM),
        .RegWriteW  (RegWriteW),
        .MemReadE   (MemReadE),
        .InstrD     (InstrD),
        .MainRD1D   (MainRD1D),
        .MainRD2D   (MainRD2D),
        .DualRD1D   (DualRD1D),
        .DualRD2D   (DualRD2D),
        .PCSrcE     (PCSrcE)
    );

    // 3. Unidad de Riesgos
    hazard hu(
        .Rs1E       (Rs1E),
        .Rs2E       (Rs2E),
        .RdE        (RdE),
        .RdM        (RdM),
        .RdW        (RdW),
        .InstrD     (InstrD),
        .RegWriteM  (RegWriteM),
        .RegWriteW  (RegWriteW),
        .MemReadE   (MemReadE),
        .PCSrcE     (PCSrcE),
        .ForwardAE  (ForwardAE),
        .ForwardBE  (ForwardBE),
        .StallF     (StallF),
        .StallD     (StallD),
        .FlushE     (FlushE),
        .FlushD     (FlushD)
    );

endmodule

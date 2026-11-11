module top #(
    parameter PROGRAM = "test_e2p2.mem"
)(
    input         clk, reset,
    output [31:0] WriteData, DataAdr,
    output        MemWrite,
    output [31:0] DualPCF1, DualInstrD0, DualInstrD1,
    output        DualValidD0, DualValidD1, DualIssueD1, DualIssue,
    output [31:0] DualALUResult0, DualALUResult1,
    output        DualValidE0, DualValidE1,
    output        RetireW,   // medicion: instruccion retirada este ciclo
    output        HaltW      // medicion: halt (jal x0, 0) llego a WB
);
  
  wire [31:0] PC, Instr, Instr1, ReadData;
  wire [31:0] InstrD0, InstrD1;
  wire ValidD0, ValidD1, IssueD1, DualIssueNow;
  wire FrontendStallD, FrontendFlushD;
  wire [31:0] MainRD1D, MainRD2D, DualRD1D, DualRD2D;
  
  // Instanciamos el procesador Pipelined
  riscv_pipeline rvpipe(
    .clk        (clk), 
    .reset      (reset), 
    .PCF        (PC), 
    .InstrF     (Instr), 
    .MemWriteM  (MemWrite), 
    .ALUResultM (DataAdr), 
    .WriteDataM (WriteData), 
    .ReadDataM  (ReadData),
    .DualInstrD0(InstrD0),
    .DualInstrD1(InstrD1),
    .MainRD1D   (MainRD1D),
    .MainRD2D   (MainRD2D),
    .DualRD1D   (DualRD1D),
    .DualRD2D   (DualRD2D),
    .FrontendStallD(FrontendStallD),
    .FrontendFlushD(FrontendFlushD),
    .RetireW    (RetireW),
    .HaltW      (HaltW)
  ); 

  imem #(.PROGRAM(PROGRAM)) imem(
     .a  (PC),
     .rd (Instr),
     .a1 (PC + 32'd4),
     .rd1(Instr1)
   );

  dual_issue_frontend frontend(
     .clk      (clk),
     .reset    (reset),
     .StallD   (FrontendStallD),
     .FlushD   (FrontendFlushD),
     .PCF      (PC),
     .InstrF0  (Instr),
     .InstrF1  (Instr1),
     .PCF1     (DualPCF1),
     .InstrD0  (InstrD0),
     .InstrD1  (InstrD1),
     .ValidD0  (ValidD0),
     .ValidD1  (ValidD1),
     .IssueD1  (IssueD1),
     .DualIssueD(DualIssueNow)
  );

  assign DualInstrD0 = InstrD0;
  assign DualInstrD1 = InstrD1;
  assign DualValidD0 = ValidD0;
  assign DualValidD1 = ValidD1;
  assign DualIssueD1 = IssueD1;
  assign DualIssue   = DualIssueNow;

  dual_issue_datapath dual_dp(
     .InstrD0   (InstrD0),
     .InstrD1   (InstrD1),
     .RD1D      (MainRD1D),
     .RD2D      (MainRD2D),
     .RD1D_lane1(DualRD1D),
     .RD2D_lane1(DualRD2D),
     .ValidD0   (ValidD0),
     .IssueD1    (IssueD1),
     .ALUResult0 (DualALUResult0),
     .ALUResult1 (DualALUResult1),
     .ValidE0    (DualValidE0),
     .ValidE1    (DualValidE1)
  );

  dmem dmem(
    .clk (clk), 
    .we  (MemWrite), 
    .a   (DataAdr), 
    .wd  (WriteData), 
    .rd  (ReadData)
  ); 
endmodule

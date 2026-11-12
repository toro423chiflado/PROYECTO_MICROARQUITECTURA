`timescale 1ns/1ps
// =============================================================================
// testbench_ondas_e1: banco para observar ondas (configuracion A y frontend dual de E1)
// Expone con nombre las senales usadas en las figuras del informe y genera
// testbench_ondas_e1.vcd. En Vivado: Simulation Top = testbench_ondas_e1, parametros PROGRAM/DATA y
// agregar al visor las senales del modulo testbench_ondas_e1.
// =============================================================================
module testbench_ondas_e1;
  parameter PROGRAM = "test2_forwarding.mem";
  parameter DATA    = "";
  parameter T_END   = 300;   // ns de simulacion despues del reset
  reg clk = 0, reset = 1;
  always #5 clk = ~clk;
  top #(.PROGRAM(PROGRAM)) dut(.clk(clk), .reset(reset));
  wire [31:0] PCF=dut.rvpipe.dp.PCF, InstrD=dut.rvpipe.InstrD, SrcAE=dut.rvpipe.dp.SrcAE, SrcBE=dut.rvpipe.dp.SrcBE, WriteDataE=dut.rvpipe.dp.WriteDataE;
  wire [31:0] ALUResultE=dut.rvpipe.dp.ALUResultE, ALUResultM=dut.rvpipe.dp.ALUResultM_reg, ResultW=dut.rvpipe.dp.ResultW, ReadDataM=dut.dmem.rd, WriteDataM=dut.WriteData;
  wire [31:0] PCD_E=dut.rvpipe.dp.PCD_E, PCTargetE=dut.rvpipe.dp.PCTargetE, RD1D=dut.rvpipe.dp.RD1D, ImmExtE=dut.rvpipe.dp.ImmExtE;
  wire [1:0] ForwardAE=dut.rvpipe.ForwardAE, ForwardBE=dut.rvpipe.ForwardBE;
  wire [3:0] ALUControlE=dut.rvpipe.dp.ALUControlE;
  wire [4:0] Rs1D=dut.rvpipe.InstrD[19:15], Rs2D=dut.rvpipe.InstrD[24:20], Rs1E=dut.rvpipe.Rs1E, Rs2E=dut.rvpipe.Rs2E, RdE=dut.rvpipe.RdE, RdM=dut.rvpipe.RdM, RdW=dut.rvpipe.RdW;
  wire RegWriteM=dut.rvpipe.RegWriteM, RegWriteW=dut.rvpipe.RegWriteW, MemReadE=dut.rvpipe.MemReadE, MemWriteM=dut.MemWrite;
  wire StallF=dut.rvpipe.StallF, StallD=dut.rvpipe.StallD, FlushD=dut.rvpipe.FlushD, FlushE=dut.rvpipe.FlushE, PCSrcE=dut.rvpipe.PCSrcE;
  wire BranchE=dut.rvpipe.dp.BranchE, TakeBranchE=dut.rvpipe.dp.TakeBranchE;
  wire [31:0] DualInstrD0=dut.DualInstrD0, DualInstrD1=dut.DualInstrD1, InstrF0=dut.imem.rd, InstrF1=dut.imem.rd1, DualALUResult0=dut.DualALUResult0, DualALUResult1=dut.DualALUResult1;
  wire DualValidD0=dut.DualValidD0, DualValidD1=dut.DualValidD1, DualIssueD1=dut.DualIssueD1;
  integer i;
  initial begin
    $dumpfile("testbench_ondas_e1.vcd"); $dumpvars(0, testbench_ondas_e1);
    #1;
    for (i = 0; i < 32; i = i + 1) dut.rvpipe.dp.rf.rf[i] = 0;
    if (DATA != "") $readmemh(DATA, dut.dmem.RAM);
    #21 reset = 0;
    #(T_END) $finish;
  end
endmodule

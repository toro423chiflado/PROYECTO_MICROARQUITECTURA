`timescale 1ns/1ps
// =============================================================================
// testbench_ondas_e2: banco para observar ondas (configuracion B, dual-issue)
// Expone con nombre las senales usadas en las figuras del informe y genera
// testbench_ondas_e2.vcd. En Vivado: Simulation Top = testbench_ondas_e2, parametros PROGRAM/DATA y
// agregar al visor las senales del modulo testbench_ondas_e2.
// =============================================================================
module testbench_ondas_e2;
  parameter PROGRAM = "e2_demo_issue.mem";
  parameter DATA    = "";
  parameter T_END   = 300;   // ns de simulacion despues del reset
  reg clk = 0, reset = 1;
  always #5 clk = ~clk;
  e2_top #(.PROGRAM(PROGRAM)) dut(.clk(clk), .reset(reset));
  wire [31:0] PCF=dut.PCF, InstrF0=dut.core.InstrF0, InstrF1=dut.core.InstrF1;
  wire [31:0] PCD0=dut.core.dp[0], InstrD0=dut.core.di[0], InstrD1=dut.core.di[1];
  wire ValidD0=dut.core.dv[0], ValidD1=dut.core.dv[1], pair_ok=dut.core.pair_ok, load_stall0=dut.core.load_stall0, load_stall1=dut.core.load_stall1;
  wire Issue0=dut.Issue0, Issue1=dut.Issue1;
  wire [31:0] InstrE0=dut.core.ei[0], InstrE1=dut.core.ei[1], SrcAE0=dut.core.xa[0], SrcBE0=dut.core.xb[0], SrcAE1=dut.core.xa[1], SrcBE1=dut.core.xb[1];
  wire [31:0] ALUResultE0=dut.core.xr[0], ALUResultE1=dut.core.xr[1];
  wire ValidE0=dut.core.ev[0], ValidE1=dut.core.ev[1], control_lane0=dut.core.control_lane0, ctaken=dut.core.ctaken, RedirectE=dut.RedirectE;
  wire [31:0] RedirectTargetE=dut.RedirectTargetE;
  wire [31:0] InstrM0=dut.core.mi[0], InstrM1=dut.core.mi[1], ResultM0=dut.core.mr[0], ResultM1=dut.core.mr[1];
  wire ValidM0=dut.core.mv[0], ValidM1=dut.core.mv[1], memlane=dut.core.memlane, MemWriteM=dut.MemWrite;
  wire [31:0] DataAdrM=dut.DataAdr, WriteDataM=dut.WriteData, ReadDataM=dut.core.ReadDataM;
  wire ValidW0=dut.core.wv[0], ValidW1=dut.core.wv[1], WriteW0=dut.core.rf.we3, WriteW1=dut.core.rf.we6;
  wire [4:0] RdW0=dut.core.wi[0][11:7], RdW1=dut.core.wi[1][11:7];
  wire [31:0] ResultW0=dut.core.wr[0], ResultW1=dut.core.wr[1];
  wire [1:0] RetireCnt=dut.RetireCnt;
  integer i;
  initial begin
    $dumpfile("testbench_ondas_e2.vcd"); $dumpvars(0, testbench_ondas_e2);
    #1;
    for (i = 0; i < 32; i = i + 1) dut.core.rf.rf[i] = 0;
    if (DATA != "") $readmemh(DATA, dut.dmem.RAM);
    #21 reset = 0;
    #(T_END) $finish;
  end
endmodule

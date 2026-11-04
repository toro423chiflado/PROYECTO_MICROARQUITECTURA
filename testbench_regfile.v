`timescale 1ns/1ps
module testbench_regfile;
  reg clk = 0;
  reg we3 = 0;
  reg [4:0] a1 = 0, a2 = 0, a3 = 0, a4 = 0, a5 = 0;
  reg [31:0] wd3 = 0;
  wire [31:0] rd1, rd2, rd4, rd5;

  regfile dut(clk, we3, a1, a2, a3, a4, a5, wd3, rd1, rd2, rd4, rd5);
  always #5 clk = ~clk;

  initial begin
    // Initialize a stored value, then check that a pending write overrides it.
    a3 = 5; wd3 = 32'h12345678; we3 = 1;
    @(negedge clk);
    a1 = 5; a2 = 5; a4 = 5; a5 = 5;
    wd3 = 32'h87654321;
    #1;
    if ({rd1, rd2, rd4, rd5} !== {4{32'h87654321}})
      $fatal(1, "WB bypass failed on one or more read ports");
    a3 = 6;
    #1;
    if ({rd1, rd2, rd4, rd5} !== {4{32'h12345678}})
      $fatal(1, "Unmatched write must not bypass stored data");
    a3 = 5;
    we3 = 0;
    #1;
    if ({rd1, rd2, rd4, rd5} !== {4{32'h12345678}})
      $fatal(1, "Disabled write must not bypass stored data");
    we3 = 1;
    @(posedge clk);
    if ({rd1, rd2, rd4, rd5} !== {4{32'h87654321}})
      $fatal(1, "Decode did not see the WB value at the active edge");
    @(negedge clk);
    we3 = 1; a3 = 0; wd3 = 32'hffffffff;
    a1 = 0; a2 = 0; a4 = 0; a5 = 0;
    #1;
    if ({rd1, rd2, rd4, rd5} !== 128'b0)
      $fatal(1, "x0 must read zero even during a write to x0");
    @(negedge clk);
    we3 = 0;
    #1;
    if ({rd1, rd2, rd4, rd5} !== 128'b0)
      $fatal(1, "x0 must read zero after a write to x0");
    $display("PASS: regfile WB/Decode bypass and x0");
    $finish;
  end
endmodule

`timescale 1ns/1ps
module testbench_regfile_dual;
  reg clk = 0, we3 = 0, we6 = 0;
  reg [4:0] a1 = 0, a2 = 0, a3 = 0, a4 = 0, a5 = 0, a6 = 0;
  reg [31:0] wd3 = 0, wd6 = 0;
  wire [31:0] rd1, rd2, rd4, rd5;
  wire [31:0] legacy_rd;

  regfile dut (.clk(clk), .we3(we3), .a1(a1), .a2(a2), .a3(a3),
              .a4(a4), .a5(a5), .wd3(wd3), .rd1(rd1), .rd2(rd2),
              .rd4(rd4), .rd5(rd5), .we6(we6), .a6(a6), .wd6(wd6));
  // E1 uses named connections and leaves the younger write port floating.
  regfile legacy (.clk(clk), .we3(we3), .a1(a1), .a2(a2), .a3(a3),
                 .a4(a4), .a5(a5), .wd3(wd3), .rd1(legacy_rd),
                 .rd2(), .rd4(), .rd5());
  always #5 clk = ~clk;

  initial begin
    // Each pending write bypasses to two independent read ports.
    a3 = 5; wd3 = 32'h11111111; we3 = 1;
    a6 = 6; wd6 = 32'h22222222; we6 = 1;
    a1 = 5; a2 = 6; a4 = 5; a5 = 6;
    #1;
    if ({rd1, rd2, rd4, rd5} !== {wd3, wd6, wd3, wd6})
      $fatal(1, "dual bypass failed");
    @(negedge clk); we3 = 0; we6 = 0; #1;
    if ({rd1, rd2, rd4, rd5} !== {32'h11111111, 32'h22222222, 32'h11111111, 32'h22222222})
      $fatal(1, "dual write did not persist");
    if (legacy_rd !== 32'h11111111)
      $fatal(1, "unconnected second port changed E1 write");

    // Conflict: every read sees the younger value before and after the edge.
    a3 = 5; wd3 = 32'h33333333; we3 = 1;
    a6 = 5; wd6 = 32'h44444444; we6 = 1;
    a1 = 5; a2 = 5; a4 = 5; a5 = 5; #1;
    if ({rd1, rd2, rd4, rd5} !== {4{wd6}})
      $fatal(1, "younger bypass must win");
    @(negedge clk); we3 = 0; we6 = 0; #1;
    if ({rd1, rd2, rd4, rd5} !== {4{32'h44444444}})
      $fatal(1, "younger write must win");
    if (legacy_rd !== 32'h33333333)
      $fatal(1, "floating younger enable must not write or bypass");

    // Disable each port in turn while both destinations match.
    we3 = 1; we6 = 0; wd3 = 32'h55555555; #1;
    if ({rd1, rd2, rd4, rd5} !== {4{wd3}}) $fatal(1, "older bypass failed");
    we3 = 0; we6 = 1; wd6 = 32'h66666666; #1;
    if ({rd1, rd2, rd4, rd5} !== {4{wd6}}) $fatal(1, "younger bypass failed");
    we6 = 1'bx; #1;
    if ({rd1, rd2, rd4, rd5} !== {4{32'h44444444}})
      $fatal(1, "unknown younger enable must not bypass");
    @(negedge clk); we6 = 0; #1;
    if (rd1 !== 32'h44444444) $fatal(1, "unknown younger enable wrote");

    // Writes to x0 cannot bypass, change x0, or block the other port.
    a3 = 0; wd3 = 32'hffffffff; we3 = 1;
    a6 = 7; wd6 = 32'h77777777; we6 = 1;
    a1 = 0; a2 = 7; a4 = 0; a5 = 7; #1;
    if ({rd1, rd2, rd4, rd5} !== {32'b0, wd6, 32'b0, wd6}) $fatal(1, "older x0 write");
    @(negedge clk);
    a3 = 8; wd3 = 32'h88888888; a6 = 0; wd6 = 32'hffffffff;
    a1 = 8; a2 = 0; a4 = 8; a5 = 0; #1;
    if ({rd1, rd2, rd4, rd5} !== {wd3, 32'b0, wd3, 32'b0}) $fatal(1, "younger x0 write");
    @(negedge clk); we3 = 0; we6 = 0; #1;
    if ({rd1, rd2, rd4, rd5} !== {32'h88888888, 32'b0, 32'h88888888, 32'b0})
      $fatal(1, "x0 or independent write failed after edge");
    a1 = 7; #1;
    if (rd1 !== 32'h77777777) $fatal(1, "younger write lost alongside x0");
    $display("PASS: dual regfile writes, priority, x0, bypass and E1 compatibility");
    $finish;
  end
endmodule

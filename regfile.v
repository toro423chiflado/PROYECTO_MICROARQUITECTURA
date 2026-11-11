module regfile(input  clk, 
               input  we3, 
               input  [ 4:0] a1, a2, a3, a4, a5,
               input  [31:0] wd3, 
               output [31:0] rd1, rd2, rd4, rd5,
               input we6,
               input [4:0] a6,
               input [31:0] wd6);

  reg [31:0] rf[31:0]; 

  // Port 6 belongs to the younger instruction and wins conflicts.
  wire write6 = (we6 === 1'b1);
  always @(posedge clk) begin 
    if (we3 && a3 != 0 && !(write6 && a6 == a3)) rf[a3] <= wd3;
    if (write6 && a6 != 0) rf[a6] <= wd6;
  end
  
  // Combinational reads bypass the concurrent write; x0 always reads as zero.
  assign rd1 = (a1 == 0) ? 32'b0 : (write6 && a1 == a6) ? wd6 : (we3 && a1 == a3) ? wd3 : rf[a1];
  assign rd2 = (a2 == 0) ? 32'b0 : (write6 && a2 == a6) ? wd6 : (we3 && a2 == a3) ? wd3 : rf[a2];
  assign rd4 = (a4 == 0) ? 32'b0 : (write6 && a4 == a6) ? wd6 : (we3 && a4 == a3) ? wd3 : rf[a4];
  assign rd5 = (a5 == 0) ? 32'b0 : (write6 && a5 == a6) ? wd6 : (we3 && a5 == a3) ? wd3 : rf[a5];
endmodule

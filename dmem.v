module dmem #(parameter DEPTH = 256)   // palabras de 32 bits (1 KB)
           (input  clk, we,
            input  [31:0] a, wd,
            output [31:0] rd);
  
  localparam AW = $clog2(DEPTH);
  reg [31:0] RAM[0:DEPTH-1];
  integer i;

  // Contenido inicial en cero (los bancos pueden sobrescribirlo)
  initial for (i = 0; i < DEPTH; i = i + 1) RAM[i] = 32'd0;

  assign rd = RAM[a[AW+1:2]]; // word aligned

  always @(posedge clk) begin 
    if (we) RAM[a[AW+1:2]] <= wd; 
  end
endmodule
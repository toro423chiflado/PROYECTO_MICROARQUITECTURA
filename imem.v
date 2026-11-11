module imem #(
            parameter PROGRAM = "test_e2p2.mem",
            parameter DEPTH   = 256              // palabras de 32 bits (1 KB)
            )(
            input  [31:0] a,
            output [31:0] rd,
            input  [31:0] a1,
            output [31:0] rd1);
  
  localparam AW = $clog2(DEPTH);
  reg [31:0] RAM[0:DEPTH-1];
  integer i;

  initial begin
       for (i = 0; i < DEPTH; i = i + 1)
           RAM[i] = 32'h00000013; // NOP para las posiciones no usadas
       $readmemh(PROGRAM, RAM);
  end

   assign rd = RAM[a[AW+1:2]]; // word aligned
   assign rd1 = RAM[a1[AW+1:2]]; // segunda lectura del Dual Fetch
endmodule

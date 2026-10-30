module imem #(
            parameter PROGRAM = "test_e2p2.mem"
            )(
            input  [31:0] a,
            output [31:0] rd,
            input  [31:0] a1,
            output [31:0] rd1);
  
  reg [31:0] RAM[63:0]; 
  integer i;

  initial begin
       for (i = 0; i < 64; i = i + 1)
           RAM[i] = 32'h00000013; // NOP para las posiciones no usadas
       $readmemh(PROGRAM, RAM);
  end

   assign rd = RAM[a[31:2]]; // word aligned
   assign rd1 = RAM[a1[31:2]]; // segunda lectura del Dual Fetch
endmodule

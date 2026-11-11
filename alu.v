module alu(
    input  [31:0] a, b,
    input  [3:0]  alucontrol,
    output [31:0] result,
    output zero
);
  
  wire [31:0] condinvb, sum; 
  wire        v; // overflow
  wire        isAddSub; 

  reg [31:0] result_reg; 
  assign result = result_reg;

  assign condinvb = alucontrol[0] ? ~b : b; 
  assign sum = a + condinvb + alucontrol[0]; 
  assign isAddSub = ~alucontrol[2] & ~alucontrol[1] |
                    ~alucontrol[1] & alucontrol[0]; 

  //Mapeamos los casos para que coincidan con controller.v
  always @(*) begin
      case (alucontrol)
          4'b0000: result_reg = sum;                     // add / addi
          4'b0001: result_reg = sum;                     // sub
          4'b0010: result_reg = a & b;                   // and / andi
          4'b0011: result_reg = a | b;                   // or / ori
          4'b0100: result_reg = a ^ b;                   // xor / xori
          4'b0101: result_reg = a << b[4:0];             // sll / slli
          4'b0110: result_reg = a >> b[4:0];             // srl / srli
          4'b0111: result_reg = $signed(a) >>> b[4:0];   // sra / srai (El '>>>' preserva el signo)
          4'b1000: result_reg = {31'b0, $signed(a) < $signed(b)}; // slt / slti
          4'b1001: result_reg = {31'b0, a < b};                   // sltu / sltiu
          default: result_reg = 32'bx;
      endcase
  end

  assign zero = (result == 32'b0); 
  assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub; 
  
endmodule

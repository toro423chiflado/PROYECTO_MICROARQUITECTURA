module alu(
    input  [31:0] a, b,
    input  [2:0]  alucontrol,
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
          3'b000:  result_reg = sum;                     // add / addi
          3'b001:  result_reg = sum;                     // sub
          3'b010:  result_reg = a & b;                   // and / andi
          3'b011:  result_reg = a | b;                   // or / ori
          3'b100:  result_reg = a ^ b;                   // xor / xori
          3'b101:  result_reg = a << b[4:0];             // sll / slli
          3'b110:  result_reg = a >> b[4:0];             // srl / srli
          3'b111:  result_reg = $signed(a) >>> b[4:0];   // sra / srai (El '>>>' preserva el signo)
          default: result_reg = 32'bx;
      endcase
  end

  assign zero = (result == 32'b0); 
  assign v = ~(alucontrol[0] ^ a[31] ^ b[31]) & (a[31] ^ sum[31]) & isAddSub; 
  
endmodule

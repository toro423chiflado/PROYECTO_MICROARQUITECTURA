module controller(
    input  [6:0] op,
    input  [2:0] funct3,
    input        funct7b5,      // Proveniente de InstrD[30] (para sub, sra, srai)
    output reg [1:0] ResultSrcD,
    output reg       MemWriteD,
    output reg       MemReadD,  // Esencial para la Hazard Unit (Load-Use)
    output reg       BranchD,
    output reg       JumpD,
    output reg       ALUSrcD,
    output reg       RegWriteD,
    output reg [1:0] ImmSrcD,
    output reg [2:0] ALUControlD
);

    reg [1:0] ALUOp;

    // DECODIFICADOR PRINCIPAL
    always @(*) begin
        case (op)
            7'b0000011: begin // lw
                RegWriteD   = 1'b1;
                ImmSrcD     = 2'b00; // Tipo-I
                ALUSrcD     = 1'b1;  // Usa Inmediato
                MemWriteD   = 1'b0;
                MemReadD    = 1'b1;  // Habilitado para detectar Load-Use
                ResultSrcD  = 2'b01; // El dato viene de la Memoria
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b00; // ADD (Dirección: base + offset)
            end
            
            7'b0100011: begin // sw
                RegWriteD   = 1'b0;
                ImmSrcD     = 2'b01; // Tipo-S
                ALUSrcD     = 1'b1;  // Usa Inmediato
                MemWriteD   = 1'b1;  // Escribe en memoria
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00; // No importa
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b00; // ADD
            end
            
            7'b0110011: begin // Tipo-R (add, sub, sll, srl, sra, xor, or, and)
                RegWriteD   = 1'b1;
                ImmSrcD     = 2'b00; // No importa
                ALUSrcD     = 1'b0;  // Usa registro rs2
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00; // El dato viene de la ALU
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b10; // Determinado por funct3 y funct7
            end
            
            7'b0010011: begin // Tipo-I ALU (addi, slli, srli, srai, xori, ori, andi)
                RegWriteD   = 1'b1;
                ImmSrcD     = 2'b00; // Tipo-I
                ALUSrcD     = 1'b1;  // Usa Inmediato
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00; // El dato viene de la ALU
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b11; // Determinado por funct3 y funct7
            end
            
            7'b1100011: begin // Branches (beq, bne, blt, bge)
                RegWriteD   = 1'b0;
                ImmSrcD     = 2'b10; // Tipo-B
                ALUSrcD     = 1'b0;  // Compara registros
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00; // No importa
                BranchD     = 1'b1;  // Activa línea de branch
                JumpD       = 1'b0;
                ALUOp       = 2'b01; // SUB (ALU compara mediante resta)
            end
            
            7'b1101111: begin // jal (Jump and Link)
                RegWriteD   = 1'b1;
                ImmSrcD     = 2'b11; // Tipo-J
                ALUSrcD     = 1'bx;  
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b10; // Guarda PC + 4 en el destino
                BranchD     = 1'b0;
                JumpD       = 1'b1;
                ALUOp       = 2'b00;
            end
            
            7'b1100111: begin // jalr (Jump and Link Register)
                RegWriteD   = 1'b1;
                ImmSrcD     = 2'b00; // Usa inmediato estructurado como Tipo-I
                ALUSrcD     = 1'b1;  
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b10; // Guarda PC + 4 en el destino
                BranchD     = 1'b0;
                JumpD       = 1'b1;
                ALUOp       = 2'b00; // ALU suma base + offset
            end
            
            default: begin // NOP / Estado seguro
                RegWriteD   = 1'b0;
                ImmSrcD     = 2'b00;
                ALUSrcD     = 1'b0;
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00;
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b00;
            end
        endcase
    end

    // DECODIFICADOR DE LA ALU
    always @(*) begin
        case (ALUOp)
            2'b00: ALUControlD = 3'b000; // Suma fija (Direcciones)
            2'b01: ALUControlD = 3'b001; // Resta fija (Branches)
            
            default: begin // Modos dinámicos 2'b10 (Tipo-R) y 2'b11 (Tipo-I ALU)
                case (funct3)
                    3'b000: if (ALUOp == 2'b10 && funct7b5) 
                                 ALUControlD = 3'b001; // sub
                             else 
                                 ALUControlD = 3'b000; // add / addi
                    3'b001: ALUControlD = 3'b101; // sll / slli
                    3'b100: ALUControlD = 3'b100; // xor / xori
                    3'b101: if (funct7b5)
                                 ALUControlD = 3'b111; // sra / srai
                             else
                                 ALUControlD = 3'b110; // srl / srli
                    3'b110: ALUControlD = 3'b011; // or / ori
                    3'b111: ALUControlD = 3'b010; // and / andi
                    default: ALUControlD = 3'b000;
                endcase
            end
        endcase
    end
endmodule

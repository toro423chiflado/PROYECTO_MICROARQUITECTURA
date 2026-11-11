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
    output reg [2:0] ImmSrcD,     // 000 I, 001 S, 010 B, 011 J, 100 U
    output reg [3:0] ALUControlD,
    output reg [1:0] ALUSrcAD     // Operando A de la ALU: 00 rs1, 01 PC (auipc), 10 cero (lui)
);

    reg [1:0] ALUOp;

    // DECODIFICADOR PRINCIPAL
    always @(*) begin
        ALUSrcAD = 2'b00; // por defecto el operando A es rs1
        case (op)
            7'b0000011: begin // lw
                RegWriteD   = 1'b1;
                ImmSrcD     = 3'b000; // Tipo-I
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
                ImmSrcD     = 3'b001; // Tipo-S
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
                ImmSrcD     = 3'b000; // No importa
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
                ImmSrcD     = 3'b000; // Tipo-I
                ALUSrcD     = 1'b1;  // Usa Inmediato
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00; // El dato viene de la ALU
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b11; // Determinado por funct3 y funct7
            end
            
            7'b1100011: begin // Branches (beq, bne, blt, bge, bltu, bgeu)
                RegWriteD   = 1'b0;
                ImmSrcD     = 3'b010; // Tipo-B
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
                ImmSrcD     = 3'b011; // Tipo-J
                ALUSrcD     = 1'bx;  
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b10; // Guarda la direccion de la siguiente instruccion
                BranchD     = 1'b0;
                JumpD       = 1'b1;
                ALUOp       = 2'b00;
            end
            
            7'b1100111: begin // jalr (Jump and Link Register)
                RegWriteD   = 1'b1;
                ImmSrcD     = 3'b000; // Usa inmediato estructurado como Tipo-I
                ALUSrcD     = 1'b1;  
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b10; // Guarda la direccion de la siguiente instruccion
                BranchD     = 1'b0;
                JumpD       = 1'b1;
                ALUOp       = 2'b00; // ALU suma base + offset
            end
            
            7'b0110111: begin // lui: rd = 0 + inmediato U
                RegWriteD   = 1'b1;
                ImmSrcD     = 3'b100; // Tipo-U
                ALUSrcD     = 1'b1;
                ALUSrcAD    = 2'b10;  // operando A = 0
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00;
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b00;  // suma
            end

            7'b0010111: begin // auipc: rd = PC + inmediato U
                RegWriteD   = 1'b1;
                ImmSrcD     = 3'b100; // Tipo-U
                ALUSrcD     = 1'b1;
                ALUSrcAD    = 2'b01;  // operando A = PC
                MemWriteD   = 1'b0;
                MemReadD    = 1'b0;
                ResultSrcD  = 2'b00;
                BranchD     = 1'b0;
                JumpD       = 1'b0;
                ALUOp       = 2'b00;  // suma
            end

            default: begin // NOP / Estado seguro
                RegWriteD   = 1'b0;
                ImmSrcD     = 3'b000;
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
            2'b00: ALUControlD = 4'b0000; // Suma fija (Direcciones)
            2'b01: ALUControlD = 4'b0001; // Resta fija (Branches)
            
            default: begin // Modos dinámicos 2'b10 (Tipo-R) y 2'b11 (Tipo-I ALU)
                case (funct3)
                    3'b000: if (ALUOp == 2'b10 && funct7b5) 
                                 ALUControlD = 4'b0001; // sub
                             else 
                                 ALUControlD = 4'b0000; // add / addi
                    3'b001: ALUControlD = 4'b0101; // sll / slli
                    3'b010: ALUControlD = 4'b1000; // slt / slti
                    3'b011: ALUControlD = 4'b1001; // sltu / sltiu
                    3'b100: ALUControlD = 4'b0100; // xor / xori
                    3'b101: if (funct7b5)
                                 ALUControlD = 4'b0111; // sra / srai
                             else
                                 ALUControlD = 4'b0110; // srl / srli
                    3'b110: ALUControlD = 4'b0011; // or / ori
                    3'b111: ALUControlD = 4'b0010; // and / andi
                    default: ALUControlD = 4'b0000;
                endcase
            end
        endcase
    end
endmodule

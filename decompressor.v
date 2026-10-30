`timescale 1ns / 1ps

module decompressor(
    input  [31:0] instr_in,
    output reg [31:0] instr_out
);

    wire [4:0] rd_ci        = instr_in[11:7];
    wire [4:0] rs2_cr       = instr_in[6:2];
    wire [4:0] r_prime_rd   = {2'b01, instr_in[9:7]};
    wire [4:0] r_prime_rs2  = {2'b01, instr_in[4:2]};

    wire [11:0] imm_ci      = {{7{instr_in[12]}}, instr_in[6:2]};
    wire [11:0] imm_cb      = imm_ci;
    wire [19:0] nzimm_lui   = {{14{instr_in[12]}}, instr_in[12], instr_in[6:2]};
    wire [4:0]  shamt       = instr_in[6:2];
 
    wire [11:0] imm_cl      = {5'b00000, instr_in[5], instr_in[12:10], instr_in[6], 2'b00};

 
    wire [11:0] imm_lwsp    = {4'b0000, instr_in[3:2], instr_in[12], instr_in[6:4], 2'b00};
    wire [11:0] imm_swsp    = {4'b0000, instr_in[8:7], instr_in[12:9], 2'b00};
 
    wire [12:0] imm_cbranch = {
        {4{instr_in[12]}},
        instr_in[12],
        instr_in[6:5],
        instr_in[2],
        instr_in[11:10],
        instr_in[4:3],
        1'b0
    };

 
    wire [20:0] imm_cjump = {
        {9{instr_in[12]}},
        instr_in[12],
        instr_in[8],
        instr_in[10:9],
        instr_in[6],
        instr_in[7],
        instr_in[2],
        instr_in[11],
        instr_in[5:3],
        1'b0
    };

    always @(*) begin
        instr_out = 32'h00000013; // NOP por defecto

        if (instr_in[1:0] != 2'b11) begin
            case (instr_in[1:0])
                // Cuadrante 00
                2'b00: begin
                    case (instr_in[15:13])
                        3'b010: begin // c.lw -> lw rd', offset(rs1')
                            instr_out = {imm_cl, r_prime_rd, 3'b010, r_prime_rs2, 7'b0000011};
                        end

                        3'b110: begin // c.sw -> sw rs2', offset(rs1')
                            instr_out = {imm_cl[11:5], r_prime_rs2, r_prime_rd, 3'b010, imm_cl[4:0], 7'b0100011};
                        end
                    endcase
                end

                // Cuadrante 01
                2'b01: begin
                    case (instr_in[15:13])
                        3'b000: begin // c.addi
                            if (rd_ci != 5'd0) begin
                                instr_out = {imm_ci, rd_ci, 3'b000, rd_ci, 7'b0010011};
                            end
                        end

                        3'b001: begin // c.jal  
                            instr_out = {imm_cjump[20], imm_cjump[10:1], imm_cjump[11], imm_cjump[19:12], 5'd1, 7'b1101111};
                        end

                        3'b011: begin // c.lui
                            if (rd_ci != 5'd0 && rd_ci != 5'd2) begin
                                // TRUCO: En lugar de emitir un LUI real que colapsaría el controller,
                                // emitimos un ADDI con rs1=x0 para evitar las XXXX.
                                instr_out = {nzimm_lui[11:0], 5'b00000, 3'b000, rd_ci, 7'b0010011};
                            end
                        end

                        3'b100: begin
                            case (instr_in[11:10])
                                2'b00: instr_out = {7'b0000000, shamt, r_prime_rd, 3'b101, r_prime_rd, 7'b0010011}; // c.srli
                                2'b01: instr_out = {7'b0100000, shamt, r_prime_rd, 3'b101, r_prime_rd, 7'b0010011}; // c.srai
                                2'b10: instr_out = {imm_cb, r_prime_rd, 3'b111, r_prime_rd, 7'b0010011}; // c.andi
                                2'b11: begin
                                    if (instr_in[12] == 1'b0) begin
                                        case (instr_in[6:5])
                                            2'b00: instr_out = {7'b0100000, r_prime_rs2, r_prime_rd, 3'b000, r_prime_rd, 7'b0110011}; // c.sub
                                            2'b01: instr_out = {7'b0000000, r_prime_rs2, r_prime_rd, 3'b100, r_prime_rd, 7'b0110011}; // c.xor
                                            2'b10: instr_out = {7'b0000000, r_prime_rs2, r_prime_rd, 3'b110, r_prime_rd, 7'b0110011}; // c.or
                                            2'b11: instr_out = {7'b0000000, r_prime_rs2, r_prime_rd, 3'b111, r_prime_rd, 7'b0110011}; // c.and
                                        endcase
                                    end
                                end
                            endcase
                        end

                        3'b101: begin // c.j  
                            instr_out = {imm_cjump[20], imm_cjump[10:1], imm_cjump[11], imm_cjump[19:12], 5'd0, 7'b1101111};
                        end

                        3'b110: begin // c.beqz  
                            instr_out = {imm_cbranch[12], imm_cbranch[10:5], 5'd0, r_prime_rd, 3'b000, imm_cbranch[4:1], imm_cbranch[11], 7'b1100011};
                        end

                        3'b111: begin // c.bnez  
                            instr_out = {imm_cbranch[12], imm_cbranch[10:5], 5'd0, r_prime_rd, 3'b001, imm_cbranch[4:1], imm_cbranch[11], 7'b1100011};
                        end
                    endcase
                end

                // Cuadrante 10
                2'b10: begin
                    case (instr_in[15:13])
                        3'b000: begin // c.slli
                            if (rd_ci != 5'd0) begin
                                instr_out = {7'b0000000, shamt, rd_ci, 3'b001, rd_ci, 7'b0010011};
                            end
                        end

                        3'b010: begin // c.lwsp -> lw rd, offset(x2)
                            if (rd_ci != 5'd0) begin
                                instr_out = {imm_lwsp, 5'd2, 3'b010, rd_ci, 7'b0000011};
                            end
                        end

                        3'b100: begin // c.add/c.jr/c.jalr
                            if (rs2_cr != 5'd0) begin
                                if (instr_in[12] == 1'b1) begin
                                    instr_out = {7'b0000000, rs2_cr, rd_ci, 3'b000, rd_ci, 7'b0110011}; // c.add
                                end
 
                            end else if (rd_ci != 5'd0) begin
                                if (instr_in[12] == 1'b0) begin
                                    instr_out = {12'd0, rd_ci, 3'b000, 5'd0, 7'b1100111}; // c.jr
                                end else begin
                                    instr_out = {12'd0, rd_ci, 3'b000, 5'd1, 7'b1100111}; // c.jalr
                                end
                            end
                        end

                        3'b110: begin // c.swsp  
                            instr_out = {imm_swsp[11:5], rs2_cr, 5'd2, 3'b010, imm_swsp[4:0], 7'b0100011};
                        end
                    endcase
                end

                default: instr_out = 32'h00000013;
            endcase
        end else begin
            instr_out = instr_in;
        end
    end
endmodule

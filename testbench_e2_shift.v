`timescale 1ns/1ps
// Self-contained E2 pipeline test; no program or data memory files required.
// iverilog -g2012 -s testbench_e2_shift -o /tmp/e2_shift testbench_e2_shift.v e2_pipeline.v regfile.v
// vvp /tmp/e2_shift
module testbench_e2_shift;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    reg [31:0] program_mem [0:63];
    wire [31:0] pc, instr0, instr1, address, write_data, target;
    wire mem_write, issue0, issue1, redirect;
    assign instr0 = (pc < 256) ? program_mem[pc >> 2] : 32'h00000013;
    assign instr1 = (pc < 252) ? program_mem[(pc >> 2) + 1] : 32'h00000013;

    e2_pipeline dut(.clk(clk), .reset(reset), .PCF(pc),
        .InstrF0(instr0), .InstrF1(instr1), .MemWriteM(mem_write),
        .ALUResultM(address), .WriteDataM(write_data), .ReadDataM(32'b0),
        .Issue0(issue0), .Issue1(issue1), .RedirectE(redirect),
        .RedirectTargetE(target));

    function [31:0] addi(input [4:0] rd, rs, input integer imm);
        reg [11:0] value;
        begin value = imm; addi = {value, rs, 3'b000, rd, 7'h13}; end
    endfunction
    function [31:0] shift_reg(input arithmetic, input [4:0] rd, rs1, rs2);
        begin shift_reg = {arithmetic ? 7'h20 : 7'h00, rs2, rs1, 3'b101, rd, 7'h33}; end
    endfunction
    function [31:0] srai(input [4:0] rd, rs, shamt);
        begin srai = {7'h20, shamt, rs, 3'b101, rd, 7'h13}; end
    endfunction

    reg [31:0] expected [0:31];
    reg [31:0] seen = 0;
    integer i, lane, cycles = 0, retired = 0;
    reg forwarded_operands = 0, forwarded_result = 0;

    task check_write(input [31:0] instruction, input [31:0] value);
        reg [4:0] rd;
        begin
            rd = instruction[11:7];
            if (rd != 0) begin
                if (rd > 14 || seen[rd])
                    $fatal(1, "Unexpected or duplicate write x%0d instruction=%h", rd, instruction);
                if (value !== expected[rd])
                    $fatal(1, "x%0d=%h expected=%h instruction=%h", rd, value, expected[rd], instruction);
                seen[rd] = 1;
                retired = retired + 1;
            end
        end
    endtask

    initial begin
        for (i = 0; i < 64; i = i + 1) program_mem[i] = 32'h00000013;
        for (i = 0; i < 32; i = i + 1) begin
            expected[i] = 0;
            dut.rf.rf[i] = 0;
        end
        program_mem[0]  = addi(1, 0, -16);
        program_mem[1]  = addi(2, 0, 2);
        program_mem[2]  = shift_reg(1, 3, 1, 2); // Both inputs forwarded.
        program_mem[3]  = srai(4, 3, 1);           // Consume forwarded SRA.
        program_mem[4]  = shift_reg(0, 5, 1, 2); // Logical shift of negative.
        program_mem[5]  = srai(6, 1, 31);
        program_mem[6]  = srai(7, 1, 0);
        program_mem[7]  = addi(8, 0, 64);
        program_mem[8]  = shift_reg(1, 9, 8, 2);
        program_mem[9]  = srai(10, 8, 2);
        program_mem[10] = shift_reg(0, 11, 8, 2);
        program_mem[11] = addi(12, 3, 1);
        program_mem[12] = addi(13, 0, 34);
        program_mem[13] = shift_reg(1, 14, 1, 13); // Only low five bits count.

        expected[1] = 32'hfffffff0; expected[2] = 2;
        expected[3] = 32'hfffffffc; expected[4] = 32'hfffffffe;
        expected[5] = 32'h3ffffffc; expected[6] = 32'hffffffff;
        expected[7] = 32'hfffffff0; expected[8] = 64;
        expected[9] = 16; expected[10] = 16; expected[11] = 16;
        expected[12] = 32'hfffffffd; expected[13] = 34;
        expected[14] = 32'hfffffffc;
        repeat (2) @(negedge clk);
        reset = 0;
        wait (retired == 14);
        @(negedge clk);
        if (!forwarded_operands || !forwarded_result)
            $fatal(1, "Forwarding coverage: operands=%b result=%b", forwarded_operands, forwarded_result);
        for (i = 1; i <= 14; i = i + 1)
            if (dut.rf.rf[i] !== expected[i])
                $fatal(1, "Final x%0d=%h expected=%h", i, dut.rf.rf[i], expected[i]);
        $display("PASS E2 shifts: 14 register results and forwarding coverage");
        $finish;
    end

    always @(posedge clk) if (!reset) begin
        cycles = cycles + 1;
        if (cycles > 80) $fatal(1, "Timeout after %0d writes", retired);
        if (mem_write !== 1'b0 || redirect !== 1'b0)
            $fatal(1, "Unexpected memory write or redirect");
        for (lane = 0; lane < 2; lane = lane + 1) begin
            if (dut.ev[lane] && dut.ep[lane] == 8 &&
                dut.mv[0] && dut.mi[0][11:7] == 1 &&
                dut.mv[1] && dut.mi[1][11:7] == 2 &&
                dut.xa[lane] === 32'hfffffff0 && dut.xb[lane] === 32'd2)
                forwarded_operands = 1;
            if (dut.ev[lane] && dut.ep[lane] == 12 &&
                ((dut.mv[0] && dut.mi[0][11:7] == 3) ||
                 (dut.mv[1] && dut.mi[1][11:7] == 3)) &&
                dut.xa[lane] === 32'hfffffffc)
                forwarded_result = 1;
        end
        if (dut.wv[0] === 1'b1) check_write(dut.wi[0], dut.wr[0]);
        else if (dut.wv[0] !== 1'b0) $fatal(1, "Unknown WB valid lane 0");
        if (dut.wv[1] === 1'b1) check_write(dut.wi[1], dut.wr[1]);
        else if (dut.wv[1] !== 1'b0) $fatal(1, "Unknown WB valid lane 1");
    end
endmodule

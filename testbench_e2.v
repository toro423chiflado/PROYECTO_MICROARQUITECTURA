`timescale 1ns/1ps
// E2 specification test for e2_top/e2_pipeline; run from the project root.
// Decode issue and WB are sampled before the rising edge, oldest lane first.
// WB instructions identify retirement because this core does not retain WB PCs.
// The indicated issue pairs and jump positions are deliberately strict: they
// test regrouping and resource combinations, not just architectural results.
module testbench_e2;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;
    e2_top #(.PROGRAM("testbench_e2.mem")) dut(.clk(clk), .reset(reset));

    reg [8*1024-1:0] vcd_path;
    initial if ($value$plusargs("vcd=%s", vcd_path)) begin
        $dumpfile(vcd_path);
        $dumpvars(0, testbench_e2);
    end

    reg [31:0] image [0:63];
    reg [31:0] pc_expected [0:22];
    reg [4:0] rd_expected [0:22];
    reg [31:0] data_expected [0:22];
    reg store_expected [0:22];
    reg [31:0] addr_expected [0:22];
    integer n = 0, retired = 0, stores = 0, cycles = 0, i;
    reg pair_alu = 0, pair_mem_alu = 0, pair_alu_mem = 0;
    reg pair_jump = 0, jump_first = 0, regroup = 0, dual_write = 0;
    reg completed = 0;

    task expect_reg;
        input [31:0] pc;
        input [4:0] rd;
        input [31:0] value;
        begin
            pc_expected[n] = pc; rd_expected[n] = rd;
            data_expected[n] = value; store_expected[n] = 0;
            addr_expected[n] = 0; n = n + 1;
        end
    endtask

    task expect_store;
        input [31:0] pc, addr, value;
        begin
            pc_expected[n] = pc; rd_expected[n] = 0;
            data_expected[n] = value; store_expected[n] = 1;
            addr_expected[n] = addr; n = n + 1;
        end
    endtask

    task check_retire;
        input [31:0] ins;
        input we;
        input [4:0] rd;
        input [31:0] data;
        begin
            if (retired >= n) $fatal(1, "Unexpected WB instruction %h", ins);
            if (ins !== image[pc_expected[retired] >> 2])
                $fatal(1, "WB %0d: instruction=%h expected=%h at PC=%h", retired,
                       ins, image[pc_expected[retired] >> 2], pc_expected[retired]);
            if (we !== (rd_expected[retired] != 0) ||
                (we && rd !== rd_expected[retired]))
                $fatal(1, "PC=%h: register write enable=%b rd=%0d expected rd=%0d",
                       pc_expected[retired], we, rd, rd_expected[retired]);
            if (rd_expected[retired] != 0 && data !== data_expected[retired])
                $fatal(1, "PC=%h: x%0d=%h expected %h", pc_expected[retired],
                       rd_expected[retired], data, data_expected[retired]);
            retired = retired + 1;
        end
    endtask

    initial begin
        expect_reg( 0, 1, 5);    expect_reg( 4, 2, 7);
        expect_reg( 8, 3, 12);   expect_reg(12, 4, 17);
        expect_store(16, 0, 12); expect_reg(20, 5, 12);
        expect_reg(24, 6, 19);   expect_reg(28, 7, 9);
        expect_store(32, 4, 19); expect_reg(36, 8, 11);
        expect_reg(40, 9, 13);   expect_reg(44, 10, 19);
        expect_reg(48, 11, 1);   expect_reg(52, 12, 56);
        expect_reg(60, 14, 64);  expect_reg(68, 13, 3);
        expect_reg(72, 15, 4);   expect_reg(76, 16, 5);
        expect_reg(80, 17, 6);   expect_store(84, 8, 5);
        expect_store(88, 12, 6); expect_reg(92, 18, 1);
        expect_store(96, 16, 1);

        for (i = 0; i < 64; i = i + 1) image[i] = 32'h00000013;
        $readmemh("testbench_e2.mem", image, 0, 25);
        // Wait for the DUT's own initial memory loading before replacing it.
        #1;
        for (i = 0; i < 64; i = i + 1) begin
            dut.imem.RAM[i] = image[i];
            dut.dmem.RAM[i] = 0;
        end
        #11 reset = 0;
        wait (completed);
        // Observe the memory after the completion store's nonblocking updates.
        #1;
        if (dut.dmem.RAM[0] !== 12 || dut.dmem.RAM[1] !== 19 ||
            dut.dmem.RAM[2] !== 5 || dut.dmem.RAM[3] !== 6 ||
            dut.dmem.RAM[4] !== 1)
            $fatal(1, "Incorrect final data memory");
        for (i = 5; i < 64; i = i + 1)
            if (dut.dmem.RAM[i] !== 0) $fatal(1, "Unexpected memory write at word %0d", i);
        if (!(pair_alu && pair_mem_alu && pair_alu_mem && pair_jump &&
              jump_first && regroup && dual_write))
            $fatal(1, "Coverage: ALU=%b mem+ALU=%b ALU+mem=%b jump1=%b jump0=%b regroup=%b dualWB=%b",
                   pair_alu, pair_mem_alu, pair_alu_mem, pair_jump, jump_first, regroup, dual_write);
        $display("PASS E2: %0d ordered retirements, memory and directed issue coverage", retired);
        $finish;
    end

    always @(posedge clk) if (!reset && !completed) begin
        cycles = cycles + 1;
        if (cycles > 300) $fatal(1, "Timeout after %0d retirements", retired);
        if (dut.core.Issue0 === 1'b1 && dut.core.Issue1 === 1'b1) begin
            if (dut.core.dp[0] == 0  && dut.core.dp[1] == 4)  pair_alu = 1;
            if (dut.core.dp[0] == 32 && dut.core.dp[1] == 36) pair_mem_alu = 1;
            if (dut.core.dp[0] == 40 && dut.core.dp[1] == 44) pair_alu_mem = 1;
            if (dut.core.dp[0] == 48 && dut.core.dp[1] == 52) pair_jump = 1;
            if (dut.core.dp[0] == 76 && dut.core.dp[1] == 80) regroup = 1;
            if (dut.core.dp[0] == 16 && dut.core.dp[1] == 20)
                $fatal(1, "Two memory instructions accepted together on one port");
        end
        if (dut.core.Issue0 === 1'b1 && dut.core.dp[0] == 60) jump_first = 1;
        if (dut.core.wv[0] === 1'b1 && dut.core.wv[1] === 1'b1 &&
            dut.core.rf.we3 === 1'b1 && dut.core.rf.we6 === 1'b1 &&
            dut.core.wi[0][11:7] != 0 && dut.core.wi[1][11:7] != 0) dual_write = 1;
        if (dut.MemWrite === 1'b1) begin
            case (stores)
                0: if (dut.DataAdr !== 0  || dut.WriteData !== 12) $fatal(1, "Bad store 0");
                1: if (dut.DataAdr !== 4  || dut.WriteData !== 19) $fatal(1, "Bad store 1");
                2: if (dut.DataAdr !== 8  || dut.WriteData !== 5)  $fatal(1, "Bad store 2");
                3: if (dut.DataAdr !== 12 || dut.WriteData !== 6)  $fatal(1, "Bad store 3");
                4: if (dut.DataAdr !== 16 || dut.WriteData !== 1)  $fatal(1, "Bad store 4");
                default: $fatal(1, "Unexpected store");
            endcase
            stores = stores + 1;
        end else if (dut.MemWrite !== 1'b0) $fatal(1, "Unknown MemWrite");
        if (dut.core.wv[0] === 1'b1)
            check_retire(dut.core.wi[0], dut.core.rf.we3, dut.core.rf.a3, dut.core.rf.wd3);
        else if (dut.core.wv[0] !== 1'b0) $fatal(1, "Unknown WB valid 0");
        if (dut.core.wv[1] === 1'b1) begin
            // The terminal self-loop can share WB with the completion store.
            if (retired == n) begin
                if (dut.core.wi[1] !== 32'h0000006f)
                    $fatal(1, "Unexpected instruction after completion: %h", dut.core.wi[1]);
            end else check_retire(dut.core.wi[1], dut.core.rf.we6, dut.core.rf.a6, dut.core.rf.wd6);
        end
        else if (dut.core.wv[1] !== 1'b0) $fatal(1, "Unknown WB valid 1");
        if (retired == n && stores != 5) $fatal(1, "Expected five stores, got %0d", stores);
        if (retired == n) completed = 1;
    end
endmodule

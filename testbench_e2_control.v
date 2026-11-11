`timescale 1ns/1ps
// Self-contained directed integration tests. Run from the project root:
// iverilog -g2012 -s testbench_e2_control -o /tmp/e2_control testbench_e2_control.v e2_top.v e2_pipeline.v imem.v dmem.v regfile.v
// vvp /tmp/e2_control
module testbench_e2_control;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;
    e2_top #(.PROGRAM("testbench_e2_control.mem")) dut(.clk(clk), .reset(reset));

    reg [8*1024-1:0] vcd_path;
    initial if ($value$plusargs("vcd=%s", vcd_path)) begin
        $dumpfile(vcd_path);
        $dumpvars(0, testbench_e2_control);
    end

    integer scenario, cycles, stores, seen_control, seen_redirect;
    integer seen_pair, seen_forward, seen_waw, i;
    reg active = 0;
    reg [31:0] control_pc, target, completion_value;
    reg expected_taken;
    integer expected_lane;

    function [31:0] addi(input [4:0] rd, rs, input integer imm);
        reg [11:0] v;
        begin v = imm; addi = {v, rs, 3'b000, rd, 7'h13}; end
    endfunction
    function [31:0] beq(input [4:0] rs1, rs2, input integer offset);
        reg [12:0] v;
        begin v = offset; beq = {v[12],v[10:5],rs2,rs1,3'b000,v[4:1],v[11],7'h63}; end
    endfunction
    function [31:0] jal(input [4:0] rd, input integer offset);
        reg [20:0] v;
        begin v = offset; jal = {v[20],v[10:1],v[11],v[19:12],rd,7'h6f}; end
    endfunction
    function [31:0] jalr(input [4:0] rd, rs, input integer imm);
        reg [11:0] v;
        begin v = imm; jalr = {v,rs,3'b000,rd,7'h67}; end
    endfunction
    function [31:0] sw(input [4:0] rs, input integer offset);
        reg [11:0] v;
        begin v = offset; sw = {v[11:5],rs,5'd0,3'b010,v[4:0],7'h23}; end
    endfunction

    task prepare;
        begin
            @(negedge clk); reset = 1; active = 0;
            for (i = 0; i < 64; i = i + 1) begin
                dut.imem.RAM[i] = 32'h00000013;
                dut.dmem.RAM[i] = 32'hdeadbeef;
            end
            for (i = 0; i < 32; i = i + 1) dut.core.rf.rf[i] = 0;
            dut.core.rf.rf[1] = 7;
            dut.core.rf.rf[2] = 2;
            cycles = 0; stores = 0; seen_control = 0; seen_redirect = 0;
            seen_pair = 0; seen_forward = 0; seen_waw = 0;
            target = 24;
            dut.imem.RAM[7] = jal(0, 0);
        end
    endtask

    task run_case;
        begin
            // Reset is held through a rising edge after memory initialization.
            @(negedge clk); reset = 0; active = 1;
            while (stores == 0 && cycles < 60) @(negedge clk);
            if (stores == 0) $fatal(1, "case %0d: timeout", scenario);
            repeat (4) @(negedge clk);
            active = 0;
            if (seen_control != 1 || seen_redirect != expected_taken || !seen_pair)
                $fatal(1, "case %0d: control=%0d redirect=%0d pair=%0d", scenario, seen_control, seen_redirect, seen_pair);
            if (dut.dmem.RAM[0] !== completion_value)
                $fatal(1, "case %0d: completion=%h expected=%h", scenario, dut.dmem.RAM[0], completion_value);
            if (dut.dmem.RAM[1] !== (expected_taken ? 32'hdeadbeef : 32'd0))
                $fatal(1, "case %0d: wrong-path/fall-through store: %h", scenario, dut.dmem.RAM[1]);
            for (i = 2; i < 64; i = i + 1)
                if (dut.dmem.RAM[i] !== 32'hdeadbeef) $fatal(1, "case %0d: unexpected memory word %0d", scenario, i);
            if (scenario < 4) begin
                if (dut.core.rf.rf[20] !== (expected_taken ? 32'd0 : 32'd20))
                    $fatal(1, "case %0d: companion x20=%h", scenario, dut.core.rf.rf[20]);
                if (expected_lane == 1 && dut.core.rf.rf[21] !== 9)
                    $fatal(1, "case %0d: older companion did not survive", scenario);
            end
            if (scenario == 4 || scenario == 5) begin
                if (dut.core.rf.rf[10] !== control_pc + 4)
                    $fatal(1, "case %0d: link=%h", scenario, dut.core.rf.rf[10]);
                if (dut.core.rf.rf[20] !== 0 || (scenario == 5 && dut.core.rf.rf[21] !== 9))
                    $fatal(1, "case %0d: jump flush was not selective", scenario);
            end
            if (scenario == 6 && (!seen_forward || !seen_waw || dut.core.rf.rf[5] !== 2))
                $fatal(1, "WAW/forward coverage: forward=%0d waw=%0d x5=%h", seen_forward, seen_waw, dut.core.rf.rf[5]);
            $display("PASS case %0d: lane=%0d taken=%0d cycles=%0d", scenario, expected_lane, expected_taken, cycles);
        end
    endtask

    always @(posedge clk) if (active && !reset) begin
        cycles = cycles + 1;
        if (dut.core.Issue0 && dut.core.Issue1 &&
            ((expected_lane == 0 && dut.core.dp[0] == control_pc) ||
             (expected_lane == 1 && dut.core.dp[1] == control_pc))) seen_pair = 1;
        if ((dut.core.ev[0] && dut.core.ep[0] == control_pc) ||
            (dut.core.ev[1] && dut.core.ep[1] == control_pc)) begin
            seen_control = seen_control + 1;
            if (!(dut.core.ev[expected_lane] && dut.core.ep[expected_lane] == control_pc))
                $fatal(1, "case %0d: control issued in wrong lane", scenario);
            if (dut.RedirectE !== expected_taken)
                $fatal(1, "case %0d: redirect=%b expected=%b", scenario, dut.RedirectE, expected_taken);
            if (expected_taken && dut.RedirectTargetE !== target)
                $fatal(1, "case %0d: target=%h expected=%h", scenario, dut.RedirectTargetE, target);
            if (scenario == 6 && dut.core.mv[0] && dut.core.mv[1] &&
                dut.core.mi[0][11:7] == 5 && dut.core.mi[1][11:7] == 5 &&
                dut.core.xa[0] === 2 && dut.core.xb[0] === 2) seen_forward = 1;
        end
        if (dut.RedirectE && dut.core.cp == control_pc) seen_redirect = seen_redirect + 1;
        if (scenario == 6 && dut.core.wv[0] && dut.core.wv[1] &&
            dut.core.rf.we3 && dut.core.rf.we6 && dut.core.rf.a3 == 5 &&
            dut.core.rf.a6 == 5 && dut.core.rf.wd3 == 1 && dut.core.rf.wd6 == 2) seen_waw = 1;
        if (dut.MemWrite === 1'b1) begin
            if (dut.DataAdr === 0) begin
                if (stores != 0 || dut.WriteData !== completion_value)
                    $fatal(1, "case %0d: unexpected completion store %h", scenario, dut.WriteData);
                stores = stores + 1;
            end else if (dut.DataAdr !== 4 || expected_taken || dut.WriteData !== 0)
                $fatal(1, "case %0d: unexpected store addr=%h data=%h", scenario, dut.DataAdr, dut.WriteData);
        end else if (dut.MemWrite !== 1'b0) $fatal(1, "case %0d: unknown MemWrite", scenario);
    end

    initial begin
        // Four BEQ combinations. The companion is younger in lane 0 and older in lane 1.
        for (scenario = 0; scenario < 4; scenario = scenario + 1) begin
            prepare();
            expected_lane = scenario / 2; expected_taken = !(scenario % 2);
            control_pc = expected_lane * 4; completion_value = 7;
            if (expected_lane == 0) begin
                dut.imem.RAM[0] = beq(1, expected_taken ? 1 : 2, 24);
                dut.imem.RAM[1] = addi(20, 0, 20);
            end else begin
                dut.imem.RAM[0] = addi(21, 0, 9);
                dut.imem.RAM[1] = beq(1, expected_taken ? 1 : 2, 20);
                dut.imem.RAM[2] = addi(20, 0, 20);
            end
            dut.imem.RAM[3] = sw(0, 4);
            dut.imem.RAM[6] = sw(1, 0);
            run_case();
        end
        // JAL in lane 0 and JALR in lane 1, including JALR bit-zero clearing.
        for (scenario = 4; scenario <= 5; scenario = scenario + 1) begin
            prepare(); expected_lane = scenario - 4; expected_taken = 1;
            control_pc = expected_lane * 4; completion_value = control_pc + 4;
            if (scenario == 4) begin
                dut.imem.RAM[0] = jal(10, 24);
                dut.imem.RAM[1] = addi(20, 0, 20);
            end else begin
                dut.core.rf.rf[1] = 23;
                dut.imem.RAM[0] = addi(21, 0, 9);
                dut.imem.RAM[1] = jalr(10, 1, 2);
                dut.imem.RAM[2] = addi(20, 0, 20);
            end
            dut.imem.RAM[3] = sw(0, 4);
            dut.imem.RAM[6] = sw(10, 0);
            run_case();
        end
        // Two same-cycle writers to x5, followed by a branch dependent on x5.
        scenario = 6; prepare(); expected_lane = 0; expected_taken = 1;
        control_pc = 8; completion_value = 2;
        dut.imem.RAM[0] = addi(5, 0, 1);
        dut.imem.RAM[1] = addi(5, 0, 2);
        dut.imem.RAM[2] = beq(5, 2, 16);
        dut.imem.RAM[3] = sw(0, 4);
        dut.imem.RAM[6] = sw(5, 0);
        run_case();
        $display("PASS E2 control: 7 directed integration scenarios");
        $finish;
    end
endmodule

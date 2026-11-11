`timescale 1ns/1ps
// Self-contained integration test. From the project root:
// iverilog -g2012 -s testbench_e2_directed -o /tmp/e2_directed testbench_e2_directed.v e2_pipeline.v regfile.v && vvp /tmp/e2_directed
module testbench_e2_directed;
    reg clk = 0, reset = 1, active = 0;
    always #5 clk = ~clk;
    reg [31:0] program_mem [0:63], data_mem [0:63];
    wire [31:0] pc, address, data, target;
    wire issue0, issue1, redirect, mem_write;
    wire [31:0] ins0 = pc < 256 ? program_mem[pc >> 2] : 32'h00000013;
    wire [31:0] ins1 = pc < 252 ? program_mem[(pc >> 2)+1] : 32'h00000013;
    wire [31:0] read_data = address < 256 ? data_mem[address >> 2] : 32'hxxxxxxxx;
    e2_pipeline dut(.clk(clk), .reset(reset), .PCF(pc), .InstrF0(ins0), .InstrF1(ins1),
        .MemWriteM(mem_write), .ALUResultM(address), .WriteDataM(data), .ReadDataM(read_data),
        .Issue0(issue0), .Issue1(issue1), .RedirectE(redirect), .RedirectTargetE(target));

    function [31:0] addi(input [4:0] rd, rs, input integer imm);
        reg [11:0] v; begin v=imm; addi={v,rs,3'b000,rd,7'h13}; end
    endfunction
    function [31:0] add(input [4:0] rd, a, b);
        begin add={7'b0,b,a,3'b000,rd,7'h33}; end
    endfunction
    function [31:0] lw(input [4:0] rd, base, input integer off);
        reg [11:0] v; begin v=off; lw={v,base,3'b010,rd,7'h03}; end
    endfunction
    function [31:0] sw(input [4:0] rs, base, input integer off);
        reg [11:0] v; begin v=off; sw={v[11:5],rs,base,3'b010,v[4:0],7'h23}; end
    endfunction
    function [31:0] branch(input [2:0] f, input [4:0] a, b, input integer off);
        reg [12:0] v; begin v=off; branch={v[12],v[10:5],b,a,f,v[4:1],v[11],7'h63}; end
    endfunction
    function [31:0] jal(input integer off);
        reg [20:0] v; begin v=off; jal={v[20],v[10:1],v[11],v[19:12],5'b0,7'h6f}; end
    endfunction

    integer i, lane, cycles, scenario, stores, intermediate_stores, controls, redirects;
    integer f, taken, pos;
    reg [2:0] funct;
    reg [31:0] control_pc;
    reg expected_taken;
    reg branch_pair, raw_pair_block, load_block, mem_block, waw_pair, waw_write, cross_forward;
    reg [31:0] expected_regs [0:31];

    task prepare;
        begin
            @(negedge clk); active=0; reset=1;
            for (i=0;i<64;i=i+1) begin program_mem[i]=32'h00000013; data_mem[i]=32'hdeadbeef; end
            for (i=0;i<32;i=i+1) begin dut.rf.rf[i]=0; expected_regs[i]=0; end
            cycles=0; stores=0; intermediate_stores=0; controls=0; redirects=0;
            branch_pair=0; raw_pair_block=0; load_block=0; mem_block=0; waw_pair=0; waw_write=0; cross_forward=0;
        end
    endtask
    task start_case;
        begin @(negedge clk); reset=0; active=1; end
    endtask
    task finish_case;
        begin
            while (stores == 0 && cycles < 100) @(negedge clk);
            if (stores == 0) $fatal(1,"case %0d timeout at pc=%h",scenario,pc);
            repeat (5) @(negedge clk);
            active=0;
            for (i=0;i<32;i=i+1)
                if (dut.rf.rf[i] !== expected_regs[i])
                    $fatal(1,"case %0d x%0d=%h expected=%h",scenario,i,dut.rf.rf[i],expected_regs[i]);
        end
    endtask

    always @(posedge clk) if (active && !reset) begin
        cycles=cycles+1;
        if (cycles > 100) $fatal(1,"case %0d timeout",scenario);
        if (issue0 !== 1'b0 && issue0 !== 1'b1) $fatal(1,"unknown issue0");
        if (issue1 !== 1'b0 && issue1 !== 1'b1) $fatal(1,"unknown issue1");
        if (redirect !== 1'b0 && redirect !== 1'b1) $fatal(1,"unknown redirect");
        if (scenario < 20) begin
            if (issue0 && issue1 && dut.dp[pos] == control_pc) branch_pair=1;
            if ((dut.ev[0] && dut.ep[0] == control_pc) || (dut.ev[1] && dut.ep[1] == control_pc)) begin
                controls=controls+1;
                if (!dut.ev[pos] || dut.ep[pos] !== control_pc || redirect !== expected_taken)
                    $fatal(1,"case %0d branch lane/decision incorrect",scenario);
                if (expected_taken && target !== 24) $fatal(1,"case %0d target=%h",scenario,target);
            end
            if (redirect && dut.cp == control_pc) redirects=redirects+1;
        end else begin
            if (dut.dv[0] && dut.dv[1] && dut.dp[0]==0 && dut.dp[1]==4 && issue0 && !issue1) raw_pair_block=1;
            if (dut.dv[0] && dut.dp[0]==20 && dut.load_stall0 && !issue0) load_block=1;
            if (dut.dv[0] && dut.dv[1] && dut.dp[0]==28 && dut.dp[1]==32 && issue0 && !issue1) mem_block=1;
            if (issue0 && issue1 && dut.dp[0]==44 && dut.dp[1]==48) waw_pair=1;
            if (dut.wv[0] && dut.wv[1] && dut.rf.we3 && dut.rf.we6 &&
                dut.rf.a3==9 && dut.rf.a6==9 && dut.rf.wd3===32'd11 && dut.rf.wd6===32'd22) waw_write=1;
            for (lane=0;lane<2;lane=lane+1)
                if (dut.ev[lane] && dut.ep[lane]==52 && dut.mv[0] && dut.mv[1] &&
                    dut.mi[0][11:7]==9 && dut.mi[1][11:7]==9 && dut.xa[lane]===32'd22)
                    cross_forward=1;
        end
        if (mem_write === 1'b1) begin
            if (scenario < 20) begin
                if (address !== 0 || data !== 32'd77 || stores != 0)
                    $fatal(1,"case %0d unexpected store address=%h data=%h",scenario,address,data);
                stores=stores+1;
            end else if (address === 0 && data === 32'd15 && stores == 0 && intermediate_stores == 0)
                intermediate_stores=1;
            else if (address === 4 && data === 32'd22 && stores == 0 && intermediate_stores == 1) stores=1;
            else $fatal(1,"case %0d unexpected store address=%h data=%h",scenario,address,data);
            if (address[1:0] !== 0 || address >= 256) $fatal(1,"invalid store address");
            data_mem[address >> 2] <= data;
        end else if (mem_write !== 1'b0) $fatal(1,"unknown memory write");
    end

    initial begin
        // BNE, BLT, BGE, BLTU, BGEU, both outcomes and both lanes.
        for (f=0;f<5;f=f+1) for (pos=0;pos<2;pos=pos+1) for (taken=0;taken<2;taken=taken+1) begin
            scenario=f*4+pos*2+taken; prepare();
            case (f) 0: funct=1; 1: funct=4; 2: funct=5; 3: funct=6; 4: funct=7; endcase
            // x1=-1 and x2=1 make signed and unsigned comparisons differ.
            dut.rf.rf[1]=32'hffffffff; dut.rf.rf[2]=1; dut.rf.rf[3]=77;
            expected_regs[1]=32'hffffffff; expected_regs[2]=1; expected_regs[3]=77;
            expected_taken=taken; control_pc=pos*4;
            if (pos==1) begin program_mem[0]=addi(21,0,9); expected_regs[21]=9; end
            if (f==0) program_mem[pos]=branch(funct,1,taken ? 2 : 1,24-control_pc);
            else if (f==1 || f==4) program_mem[pos]=branch(funct,taken ? 1 : 2,taken ? 2 : 1,24-control_pc);
            else program_mem[pos]=branch(funct,taken ? 2 : 1,taken ? 1 : 2,24-control_pc);
            if (pos==0) program_mem[1]=addi(20,0,20);
            else program_mem[2]=addi(20,0,20);
            if (!taken) expected_regs[20]=20;
            program_mem[6]=sw(3,0,0); program_mem[7]=jal(0);
            start_case(); finish_case();
            if (controls != 1 || redirects != taken || !branch_pair)
                $fatal(1,"case %0d coverage control=%0d redirect=%0d pair=%b",scenario,controls,redirects,branch_pair);
            if (data_mem[0] !== 77) $fatal(1,"case %0d completion memory",scenario);
            for (i=1;i<64;i=i+1) if (data_mem[i] !== 32'hdeadbeef) $fatal(1,"case %0d memory %0d",scenario,i);
            $display("PASS branch case %0d funct=%0d lane=%0d taken=%0d",scenario,funct,pos,taken);
        end
        scenario=20; prepare();
        program_mem[0]=addi(1,0,7); program_mem[1]=addi(2,1,3);
        program_mem[2]=addi(3,0,5); program_mem[3]=add(4,2,3);
        program_mem[4]=lw(5,0,8); program_mem[5]=add(6,5,4);
        program_mem[6]=addi(7,0,15); program_mem[7]=sw(7,0,0);
        program_mem[8]=lw(8,0,0); program_mem[9]=addi(11,8,1);
        program_mem[10]=addi(12,0,3);
        program_mem[11]=addi(9,0,11); program_mem[12]=addi(9,0,22);
        program_mem[13]=addi(10,9,0); program_mem[14]=sw(10,0,4); program_mem[15]=jal(0);
        data_mem[2]=12;
        expected_regs[1]=7; expected_regs[2]=10; expected_regs[3]=5; expected_regs[4]=15;
        expected_regs[5]=12; expected_regs[6]=27; expected_regs[7]=15; expected_regs[8]=15;
        expected_regs[9]=22; expected_regs[10]=22; expected_regs[11]=16; expected_regs[12]=3;
        start_case(); finish_case();
        if (!(raw_pair_block && load_block && mem_block && waw_pair && waw_write && cross_forward))
            $fatal(1,"hazard coverage raw=%b load=%b mem=%b waw_issue=%b waw_wb=%b forward=%b",raw_pair_block,load_block,mem_block,waw_pair,waw_write,cross_forward);
        if (data_mem[0] !== 15 || data_mem[1] !== 22 || data_mem[2] !== 12) $fatal(1,"data memory mismatch");
        for (i=3;i<64;i=i+1) if (data_mem[i] !== 32'hdeadbeef) $fatal(1,"unexpected memory word %0d",i);
        $display("PASS hazards: RAW, load-use, memory conflict, WAW and forwarding");
        $display("PASS E2 directed: 21 scenarios");
        $finish;
    end
endmodule

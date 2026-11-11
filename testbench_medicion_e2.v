`timescale 1ns/1ps
module testbench_medicion_e2;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;
    wire [31:0] a1, d1, a2, d2;
    wire s1, s2;
    top #(.PROGRAM("benchmark_e1_e2.mem")) e1(
        .clk(clk), .reset(reset), .DataAdr(a1), .WriteData(d1), .MemWrite(s1));
    e2_top #(.PROGRAM("benchmark_e1_e2.mem")) e2(
        .clk(clk), .reset(reset), .DataAdr(a2), .WriteData(d2), .MemWrite(s2));

    reg [31:0] image[0:24], expected_pc[0:22], expected_reg[0:31];
    reg [31:0] sd, se, sm, sw, mpc[0:1], wpc[0:1];
    reg vd = 0, ve = 0, vm = 0, vw = 0;
    integer cycles = 0, n1 = 0, n2 = 0, c1 = 0, c2 = 0;
    integer stores1 = 0, stores2 = 0, i, drain = 0;
    integer e1_discard = 0, e2_discard = 0, e1_stalls = 0, e2_load_stalls = 0;

    task check_store;
        input integer which, n;
        input [31:0] addr, data;
        begin
            case (n)
                0: if (addr !== 0  || data !== 12) $fatal(1,"E%0d store 0",which);
                1: if (addr !== 4  || data !== 19) $fatal(1,"E%0d store 1",which);
                2: if (addr !== 8  || data !== 5)  $fatal(1,"E%0d store 2",which);
                3: if (addr !== 12 || data !== 6)  $fatal(1,"E%0d store 3",which);
                4: if (addr !== 16 || data !== 1)  $fatal(1,"E%0d store 4",which);
                default: $fatal(1,"E%0d unexpected store %0d",which,n);
            endcase
        end
    endtask

    task retire1;
        input [31:0] pc;
        begin
            if (n1 >= 23 || pc !== expected_pc[n1])
                $fatal(1,"E1 retirement %0d pc=%h expected=%h",n1,pc,expected_pc[n1]);
            n1 = n1 + 1;
            if (n1 == 23) c1 = cycles;
        end
    endtask
    task retire2;
        input [31:0] pc, ins;
        begin
            if (n2 >= 23 || pc !== expected_pc[n2] || ins !== image[pc >> 2])
                $fatal(1,"E2 retirement %0d pc=%h ins=%h expected pc=%h",n2,pc,ins,expected_pc[n2]);
            n2 = n2 + 1;
            if (n2 == 23) c2 = cycles;
        end
    endtask

    initial begin
        $readmemh("benchmark_e1_e2.mem", image);
        for (i=0; i<23; i=i+1)
            expected_pc[i] = (i < 14) ? 4*i : (i == 14) ? 60 : 4*(i+2);
        for (i=0; i<32; i=i+1) expected_reg[i]=0;
        expected_reg[1]=5; expected_reg[2]=7; expected_reg[3]=12; expected_reg[4]=17;
        expected_reg[5]=12; expected_reg[6]=19; expected_reg[7]=9; expected_reg[8]=11;
        expected_reg[9]=13; expected_reg[10]=19; expected_reg[11]=1; expected_reg[12]=56;
        expected_reg[13]=3; expected_reg[14]=64; expected_reg[15]=4; expected_reg[16]=5;
        expected_reg[17]=6; expected_reg[18]=1;
        #1;
        for (i=0; i<64; i=i+1) begin
            e1.dmem.RAM[i]=0; e2.dmem.RAM[i]=0;
        end
        for (i=0; i<32; i=i+1) begin
            e1.rvpipe.dp.rf.rf[i]=0; e2.core.rf.rf[i]=0;
        end
        @(negedge clk); reset=0;
    end

    // Shadow E1 tags follow its actual stall and flush controls to WB.
    always @(posedge clk) begin
        if (reset) begin
            vd <= 0; ve <= 0; vm <= 0; vw <= 0;
        end else begin
            cycles = cycles+1;
            if (cycles > 100) $fatal(1,"Timeout E1=%0d E2=%0d",n1,n2);
            if (e1.rvpipe.StallD) e1_stalls=e1_stalls+1;
            if (e2.core.load_stall0 || e2.core.load_stall1) e2_load_stalls=e2_load_stalls+1;
            if (vd && e1.rvpipe.PCSrcE && e1.rvpipe.FlushE && (sd == 56 || sd == 64)) e1_discard=e1_discard+1;
            if (e2.core.ev[1] && e2.core.control_lane0 && e2.core.ctaken &&
                (e2.core.ep[1] == 56 || e2.core.ep[1] == 64)) e2_discard=e2_discard+1;
            if (s1 === 1'b1) begin check_store(1,stores1,a1,d1); stores1=stores1+1; end
            else if (s1 !== 1'b0) $fatal(1,"E1 unknown store");
            if (s2 === 1'b1) begin check_store(2,stores2,a2,d2); stores2=stores2+1; end
            else if (s2 !== 1'b0) $fatal(1,"E2 unknown store");

            if (vd && e1.rvpipe.dp.InstrD !== image[sd >> 2])
                $fatal(1,"E1 shadow decode mismatch pc=%h",sd);
            if (vw) retire1(sw);
            if (e2.core.wv[0] === 1'b1 && wpc[0] <= 96) retire2(wpc[0],e2.core.wi[0]);
            else if (e2.core.wv[0] !== 1'b0 && e2.core.wv[0] !== 1'b1) $fatal(1,"E2 unknown WB0");
            if (e2.core.wv[1] === 1'b1 && wpc[1] <= 96) retire2(wpc[1],e2.core.wi[1]);
            else if (e2.core.wv[1] !== 1'b0 && e2.core.wv[1] !== 1'b1) $fatal(1,"E2 unknown WB1");

            vw <= vm; sw <= sm; vm <= ve; sm <= se;
            ve <= vd && !e1.rvpipe.FlushE; se <= sd;
            if (e1.rvpipe.FlushD) vd <= 0;
            else if (!e1.rvpipe.StallD) begin
                vd <= (e1.PC <= 96); sd <= e1.PC;
            end
            mpc[0] <= e2.core.ep[0]; mpc[1] <= e2.core.ep[1];
            wpc[0] <= mpc[0]; wpc[1] <= mpc[1];

            if (c1 != 0 && c2 != 0) drain = drain+1;
            if (drain == 9) begin
                if (stores1 != 5 || stores2 != 5 || n1 != 23 || n2 != 23)
                    $fatal(1,"Wrong final counts");
                if (!e1_discard || !e2_discard || !e1_stalls || !e2_load_stalls)
                    $fatal(1,"Missing coverage: discard=%0d/%0d stall signal observations=%0d/%0d",
                        e1_discard,e2_discard,e1_stalls,e2_load_stalls);
                // Sample after the last edge's nonblocking register and memory writes.
                #1;
                for (i=1; i<32; i=i+1) begin
                    if (e1.rvpipe.dp.rf.rf[i] !== expected_reg[i] ||
                        e2.core.rf.rf[i] !== expected_reg[i])
                        $fatal(1,"x%0d E1=%h E2=%h expected=%h",i,
                            e1.rvpipe.dp.rf.rf[i],e2.core.rf.rf[i],expected_reg[i]);
                end
                for (i=0; i<64; i=i+1) begin
                    if (e1.dmem.RAM[i] !== e2.dmem.RAM[i]) $fatal(1,"Memory mismatch %0d",i);
                    if (i >= 5 && e1.dmem.RAM[i] !== 0) $fatal(1,"Unexpected memory %0d",i);
                end
                if (e1.dmem.RAM[0] !== 12 || e1.dmem.RAM[1] !== 19 ||
                    e1.dmem.RAM[2] !== 5 || e1.dmem.RAM[3] !== 6 || e1.dmem.RAM[4] !== 1)
                    $fatal(1,"Wrong final memory");
                $display("PASS E1 cycles=%0d retired=%0d IPC=%0.6f CPI=%0.6f",c1,n1,1.0*n1/c1,1.0*c1/n1);
                $display("PASS E2 cycles=%0d retired=%0d IPC=%0.6f CPI=%0.6f",c2,n2,1.0*n2/c2,1.0*c2/n2);
                $display("speedup E1/E2=%0.6f, stores=%0d/%0d, drain=8 cycles",1.0*c1/c2,stores1,stores2);
                $display("coverage wrong-path discarded E1=%0d E2=%0d, stall signal observations E1=%0d E2=%0d",
                    e1_discard,e2_discard,e1_stalls,e2_load_stalls);
                $finish;
            end
        end
    end
endmodule

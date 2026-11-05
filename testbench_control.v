`timescale 1ns/1ps
// Nueva prueba dirigida. No modifica el RTL del procesador.
module testbench_control;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer writes = 0, controls = 0, redirects = 0, stores = 0;
    integer drain = 0, i;
    reg finished_store = 0;
    reg [31:0] expected_value [1:17];
    reg [31:0] expected_pc [0:9];
    reg [31:0] expected_target [0:9];
    reg expected_taken [0:9];
    reg [6:0] expected_op [0:9];
    reg [2:0] expected_funct3 [0:9];
    reg check_redirect;
    reg [31:0] saved_target;

    top #(.PROGRAM("test_control.mem")) dut(
        .clk(clk), .reset(reset), .WriteData(WriteData),
        .DataAdr(DataAdr), .MemWrite(MemWrite)
    );
    always #5 clk = ~clk;

    initial begin
`ifdef __ICARUS__
        $dumpfile("test_control.vcd");
        $dumpvars(0, testbench_control);
`endif
        expected_value[1] = 32'hfffffffe;
        expected_value[2] = 3;
        expected_value[3] = 32'hfffffffe;
        expected_value[4] = 11; expected_value[5] = 12;
        expected_value[6] = 21; expected_value[7] = 22;
        expected_value[8] = 23; expected_value[9] = 24;
        expected_value[10] = 31; expected_value[11] = 32;
        expected_value[12] = 32'h70; // jal en 0x6c: retorno 0x70
        expected_value[13] = 32'h70; // copia del retorno de jal
        expected_value[14] = 32'h88; // base jalr: 0x88 + 5 = 0x8d
        expected_value[15] = 32'h84; // jalr en 0x80: retorno 0x84
        expected_value[16] = 32'h84; // copia del retorno de jalr
        expected_value[17] = 1;

        // Resultados fijados de antemano para cada instruccion de control.
        expected_pc[0]=32'h0c; expected_target[0]=32'h18; expected_taken[0]=1;
        expected_pc[1]=32'h18; expected_target[1]=32'h24; expected_taken[1]=0;
        expected_pc[2]=32'h24; expected_target[2]=32'h30; expected_taken[2]=1;
        expected_pc[3]=32'h30; expected_target[3]=32'h3c; expected_taken[3]=0;
        expected_pc[4]=32'h3c; expected_target[4]=32'h48; expected_taken[4]=0;
        expected_pc[5]=32'h48; expected_target[5]=32'h54; expected_taken[5]=1;
        expected_pc[6]=32'h54; expected_target[6]=32'h60; expected_taken[6]=1;
        expected_pc[7]=32'h60; expected_target[7]=32'h6c; expected_taken[7]=0;
        expected_pc[8]=32'h6c; expected_target[8]=32'h78; expected_taken[8]=1;
        expected_pc[9]=32'h80; expected_target[9]=32'h8c; expected_taken[9]=1;
        for (i=0; i<8; i=i+1) expected_op[i]=7'h63;
        expected_op[8]=7'h6f; expected_op[9]=7'h67;
        expected_funct3[0]=1; expected_funct3[1]=1;
        expected_funct3[2]=4; expected_funct3[3]=4; expected_funct3[4]=4;
        expected_funct3[5]=5; expected_funct3[6]=5; expected_funct3[7]=5;
        expected_funct3[8]=0; expected_funct3[9]=0;
        repeat (2) @(negedge clk);
        reset = 0;
    end

    initial begin
        #1000;
        $fatal(1, "CONTROL FAIL timeout: writes=%0d controls=%0d stores=%0d", writes, controls, stores);
    end

    always @(posedge clk) begin
        check_redirect = 0;
        if (!reset) begin
            if (dut.rvpipe.StallF !== 1'b0)
                $fatal(1, "CONTROL FAIL: unexpected stall");
            if (dut.rvpipe.dp.RegWriteW === 1'b1 && dut.rvpipe.dp.RdW != 0) begin
                writes = writes + 1;
                if (writes > 17)
                    $fatal(1, "CONTROL FAIL: extra register write x%0d", dut.rvpipe.dp.RdW);
                if (dut.rvpipe.dp.RdW !== writes || dut.rvpipe.dp.ResultW !== expected_value[writes])
                    $fatal(1, "CONTROL FAIL write %0d: x%0d=%h expected x%0d=%h", writes,
                        dut.rvpipe.dp.RdW, dut.rvpipe.dp.ResultW, writes, expected_value[writes]);
                $display("WRITE x%0d=%08h", dut.rvpipe.dp.RdW, dut.rvpipe.dp.ResultW);
            end
            if (dut.rvpipe.dp.BranchE === 1'b1 || dut.rvpipe.dp.JumpE === 1'b1) begin
                if (controls >= 10) $fatal(1, "CONTROL FAIL: extra control instruction");
                if (dut.rvpipe.dp.PCD_E !== expected_pc[controls] ||
                    dut.rvpipe.dp.OpcodeE !== expected_op[controls])
                    $fatal(1, "CONTROL FAIL sequence %0d: PC=%h op=%h", controls,
                        dut.rvpipe.dp.PCD_E, dut.rvpipe.dp.OpcodeE);
                if (controls < 8 && dut.rvpipe.dp.Funct3E !== expected_funct3[controls])
                    $fatal(1, "CONTROL FAIL: incorrect branch funct3");
                if (dut.rvpipe.PCSrcE !== expected_taken[controls] ||
                    dut.rvpipe.FlushD !== expected_taken[controls] ||
                    dut.rvpipe.FlushE !== expected_taken[controls])
                    $fatal(1, "CONTROL FAIL decision at PC=%h", expected_pc[controls]);
                if (dut.rvpipe.dp.PCTargetE !== expected_target[controls])
                    $fatal(1, "CONTROL FAIL target PC=%h got=%h expected=%h", expected_pc[controls],
                        dut.rvpipe.dp.PCTargetE, expected_target[controls]);
                $display("CONTROL pc=%08h opcode=%02h taken=%0d target=%08h", expected_pc[controls],
                    expected_op[controls], expected_taken[controls], expected_target[controls]);
                if (expected_taken[controls]) begin
                    redirects = redirects + 1;
                    check_redirect = 1;
                    saved_target = expected_target[controls];
                end
                controls = controls + 1;
            end
            if (MemWrite === 1'b1) begin
                stores = stores + 1;
                if (stores != 1 || DataAdr !== 32'd4 || WriteData !== 32'd1)
                    $fatal(1, "CONTROL FAIL unexpected store: address=%h data=%h", DataAdr, WriteData);
                finished_store = 1;
            end
            if (finished_store) drain = drain + 1;
            // Observe PC and cleared Decode after nonblocking updates.
            #1;
            if (check_redirect && (dut.rvpipe.dp.PCF !== saved_target ||
                                  dut.rvpipe.dp.InstrD !== 32'd0))
                $fatal(1, "CONTROL FAIL PC redirect/flush: PC=%h expected=%h InstrD=%h",
                    dut.rvpipe.dp.PCF, saved_target, dut.rvpipe.dp.InstrD);
            if (drain == 5) begin
                if (writes != 17 || controls != 10 || redirects != 6 || stores != 1)
                    $fatal(1, "CONTROL FAIL totals: writes=%0d controls=%0d redirects=%0d stores=%0d",
                        writes, controls, redirects, stores);
                for (i=1; i<=17; i=i+1)
                    if (dut.rvpipe.dp.rf.rf[i] !== expected_value[i])
                        $fatal(1, "CONTROL FAIL final x%0d=%h", i, dut.rvpipe.dp.rf.rf[i]);
                if (dut.dmem.RAM[1] !== 32'd1)
                    $fatal(1, "CONTROL FAIL final memory[4]");
                $display("PASS CONTROL: bne=2 blt=3 bge=3 jal=1 jalr=1 writes=17 redirects=6 stores=1");
                $display("PASS LINKS: jal x12=x13=00000070; jalr x15=x16=00000084; target=0000008c");
                $finish;
            end
        end
    end
endmodule

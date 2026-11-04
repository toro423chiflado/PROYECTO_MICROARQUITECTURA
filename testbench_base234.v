`timescale 1ns/1ps
module testbench_base234 #(
    parameter TEST = 2,
    parameter PROGRAM = "test2_forwarding.mem"
);
    reg clk = 0, reset = 1;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer writes = 0, stores = 0, forwards = 0, stalls = 0, flushes = 0;
    reg [4:0] expected_rd [0:3];
    reg [31:0] expected_value [0:3];
    integer expected_writes;

    top #(.PROGRAM(PROGRAM)) dut (.clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
    always #5 clk = ~clk;

    initial begin
        case (TEST)
            2: begin
                expected_writes = 3;
                expected_rd[0]=1; expected_value[0]=5;
                expected_rd[1]=2; expected_value[1]=10;
                expected_rd[2]=3; expected_value[2]=15;
            end
            3: begin
                expected_writes = 3;
                expected_rd[0]=1; expected_value[0]=20;
                expected_rd[1]=2; expected_value[1]=20;
                expected_rd[2]=3; expected_value[2]=40;
            end
            4: begin
                expected_writes = 3;
                expected_rd[0]=1; expected_value[0]=5;
                expected_rd[1]=2; expected_value[1]=5;
                expected_rd[2]=5; expected_value[2]=9;
            end
            default: $fatal(1, "Unsupported TEST=%0d", TEST);
        endcase
        #12 reset = 0;
        #300;
        if (writes != expected_writes || stores != (TEST == 3 ? 1 : 0))
            $fatal(1, "test%0d: writes=%0d stores=%0d", TEST, writes, stores);
        if ((TEST == 2 && forwards == 0) || (TEST == 3 && stalls == 0) ||
            (TEST == 4 && flushes == 0))
            $fatal(1, "test%0d: expected hazard control not observed", TEST);
        if (TEST == 3 && dut.dmem.RAM[0] !== 32'd20)
            $fatal(1, "test3: memory[0]=%h", dut.dmem.RAM[0]);
        $display("PASS test%0d: writes=%0d stores=%0d forwarding=%0d stalls=%0d flushes=%0d",
                 TEST, writes, stores, forwards, stalls, flushes);
        $finish;
    end

    always @(posedge clk) if (!reset) begin
        if (dut.rvpipe.hu.ForwardAE != 0 || dut.rvpipe.hu.ForwardBE != 0) forwards = forwards + 1;
        if (dut.rvpipe.hu.StallF) stalls = stalls + 1;
        if (dut.rvpipe.hu.FlushD && dut.rvpipe.hu.FlushE) flushes = flushes + 1;
        if (MemWrite) begin
            stores = stores + 1;
            if (TEST != 3 || DataAdr !== 0 || WriteData !== 20 || stores != 1)
                $fatal(1, "test%0d: unexpected store address=%h data=%h", TEST, DataAdr, WriteData);
        end
        if (dut.rvpipe.dp.RegWriteW && dut.rvpipe.dp.RdW != 0) begin
            if (writes >= expected_writes)
                $fatal(1, "test%0d: unexpected write x%0d", TEST, dut.rvpipe.dp.RdW);
            if (dut.rvpipe.dp.RdW !== expected_rd[writes] ||
                dut.rvpipe.dp.ResultW !== expected_value[writes])
                $fatal(1, "test%0d write %0d: got x%0d=%h expected x%0d=%h",
                    TEST, writes, dut.rvpipe.dp.RdW, dut.rvpipe.dp.ResultW,
                    expected_rd[writes], expected_value[writes]);
            writes = writes + 1;
        end
    end
endmodule

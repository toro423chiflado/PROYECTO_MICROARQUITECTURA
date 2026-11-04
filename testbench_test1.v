`timescale 1ns/1ps
module testbench_test1;
    reg clk = 0;
    reg reset = 1;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    reg [31:0] expected [1:17];
    integer writes = 0;
    integer errors = 0;

    top #(.PROGRAM("test1_nodep.mem")) dut (
        .clk(clk), .reset(reset), .WriteData(WriteData),
        .DataAdr(DataAdr), .MemWrite(MemWrite)
    );

    always #5 clk = ~clk;

    initial begin
        expected[1] = 32'hfffffff0; expected[2] = 32'h00000003;
        expected[3] = 32'hfffffff3; expected[4] = 32'hffffffed;
        expected[5] = 32'hffffff80; expected[6] = 32'h1ffffffe;
        expected[7] = 32'hfffffffe; expected[8] = 32'hfffffff3;
        expected[9] = 32'hfffffff3; expected[10] = 32'h00000000;
        expected[11] = 32'hfffffffc; expected[12] = 32'hffffff80;
        expected[13] = 32'h1ffffffe; expected[14] = 32'hfffffffe;
        expected[15] = 32'h0000000f; expected[16] = 32'hfffffff5;
        expected[17] = 32'h00000000;
        #12 reset = 0;
        #300;
        if (writes != 17) begin
            $display("ERROR: expected 17 register writes, got %0d", writes);
            errors = errors + 1;
        end
        if (errors != 0)
            $fatal(1, "test1_nodep failed with %0d errors", errors);
        $display("PASS: test1_nodep verified 17 register writes");
        $finish;
    end

    always @(posedge clk) begin
        if (!reset && MemWrite) begin
            $display("ERROR: unexpected memory write at %h", DataAdr);
            errors = errors + 1;
        end
        if (!reset && dut.rvpipe.dp.RegWriteW && dut.rvpipe.dp.RdW != 0) begin
            writes = writes + 1;
            if (writes > 17) begin
                $display("ERROR: unexpected register write x%0d", dut.rvpipe.dp.RdW);
                errors = errors + 1;
            end else if (dut.rvpipe.dp.RdW !== writes ||
                         dut.rvpipe.dp.ResultW !== expected[writes]) begin
                $display("ERROR: write %0d: got x%0d=%h, expected x%0d=%h",
                         writes, dut.rvpipe.dp.RdW, dut.rvpipe.dp.ResultW,
                         writes, expected[writes]);
                errors = errors + 1;
            end
        end
    end
endmodule

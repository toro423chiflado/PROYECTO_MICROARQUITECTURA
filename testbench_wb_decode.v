`timescale 1ns/1ps
module testbench_wb_decode;
    reg clk = 0, reset = 1;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer overlap = 0, writes = 0;

    top #(.PROGRAM("test2_forwarding.mem")) dut (.clk(clk), .reset(reset),
        .WriteData(WriteData), .DataAdr(DataAdr), .MemWrite(MemWrite));
    always #5 clk = ~clk;

    initial begin
        // The two NOPs put the consumer in Decode when the producer is in WB.
        #1;
        dut.imem.RAM[0] = 32'h00700093; // addi x1, x0, 7
        dut.imem.RAM[1] = 32'h00000013; // nop
        dut.imem.RAM[2] = 32'h00000013; // nop
        dut.imem.RAM[3] = 32'h00008133; // add x2, x1, x0
        #11 reset = 0;
        #200;
        if (overlap != 1 || writes != 2 || dut.rvpipe.dp.rf.rf[2] !== 32'd7)
            $fatal(1, "WB/Decode: overlap=%0d writes=%0d x2=%h", overlap, writes, dut.rvpipe.dp.rf.rf[2]);
        $display("PASS WB/Decode: simultaneous WB and Decode, x2=7");
        $finish;
    end

    always @(posedge clk) if (!reset) begin
        if (MemWrite) $fatal(1, "WB/Decode: unexpected store");
        if (dut.rvpipe.dp.InstrD == 32'h00008133 && dut.rvpipe.dp.RegWriteW && dut.rvpipe.dp.RdW == 1) begin
            overlap = overlap + 1;
            if (dut.rvpipe.dp.ResultW !== 32'd7 || dut.rvpipe.dp.RD1D !== 32'd7 || dut.rvpipe.dp.RD2D !== 32'd0)
                $fatal(1, "WB/Decode: ResultW=%h RD1D=%h", dut.rvpipe.dp.ResultW, dut.rvpipe.dp.RD1D);
        end
        if (dut.rvpipe.dp.RegWriteW && dut.rvpipe.dp.RdW != 0) begin
            writes = writes + 1;
            if ((writes == 1 && (dut.rvpipe.dp.RdW !== 1 || dut.rvpipe.dp.ResultW !== 7)) ||
                (writes == 2 && (dut.rvpipe.dp.RdW !== 2 || dut.rvpipe.dp.ResultW !== 7)) || writes > 2)
                $fatal(1, "WB/Decode: unexpected write x%0d=%h", dut.rvpipe.dp.RdW, dut.rvpipe.dp.ResultW);
        end
    end
endmodule

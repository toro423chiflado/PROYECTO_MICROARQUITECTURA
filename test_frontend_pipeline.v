`timescale 1ns/1ps
module frontend_pipeline_check #(parameter PROGRAM = "test3_stalling.mem")(
    input clk, reset,
    output reg [31:0] stalls = 0, flushes = 0
);
    top #(.PROGRAM(PROGRAM)) dut(.clk(clk), .reset(reset));
    reg [31:0] expected0, expected1;
    reg [3:0] expected_flags;

    always @(posedge clk) begin
        if (!reset) begin
            if (dut.FrontendFlushD) begin
                expected0 = 0;
                expected1 = 0;
                expected_flags = 0;
                flushes = flushes + 1;
            end else if (dut.FrontendStallD) begin
                expected0 = dut.DualInstrD0;
                expected1 = dut.DualInstrD1;
                expected_flags = {dut.DualValidD0, dut.DualValidD1,
                                  dut.DualIssueD1, dut.DualIssue};
                stalls = stalls + 1;
            end else begin
                expected0 = dut.Instr;
                expected1 = dut.Instr1;
                expected_flags = {4{1'bx}};
            end
            #1;
            if (dut.DualInstrD0 !== expected0 || dut.DualInstrD1 !== expected1)
                $fatal(1, "%s: decode instructions not synchronized", PROGRAM);
            if (expected_flags !== 4'bxxxx &&
                {dut.DualValidD0, dut.DualValidD1, dut.DualIssueD1, dut.DualIssue} !== expected_flags)
                $fatal(1, "%s: decode flags not synchronized", PROGRAM);
        end
    end
endmodule

module test_frontend_pipeline;
    reg clk = 0, reset = 0;
    wire [31:0] stalls3, flushes3, stalls4, flushes4;
    frontend_pipeline_check #("test3_stalling.mem") stall_test(clk, reset, stalls3, flushes3);
    frontend_pipeline_check #("test4_flushing.mem") flush_test(clk, reset, stalls4, flushes4);
    always #5 clk = ~clk;
    initial begin
        #1 reset = 1;
        #11 reset = 0;
        #400;
        if (stalls3 == 0 || flushes4 == 0)
            $fatal(1, "missing events: stalls=%0d flushes=%0d", stalls3, flushes4);
        $display("PASS integrated synchronization: stalls=%0d flushes=%0d", stalls3, flushes4);
        $finish;
    end
endmodule

`timescale 1ns/1ps
module test_frontend_sync;
    reg clk = 0, reset = 0, stall = 0, flush = 0;
    reg [31:0] f0 = 32'h00100093, f1 = 32'h00200113;
    reg [31:0] pc = 32'h10;
    wire [31:0] pc1, d0, d1;
    wire v0, v1, issue, dual;

    dual_issue_frontend dut(
        .clk(clk), .reset(reset), .StallD(stall), .FlushD(flush),
        .PCF(pc), .InstrF0(f0), .InstrF1(f1), .PCF1(pc1),
        .InstrD0(d0), .InstrD1(d1), .ValidD0(v0), .ValidD1(v1),
        .IssueD1(issue), .DualIssueD(dual)
    );
    always #5 clk = ~clk;

    initial begin
        #1 reset = 1; #1;
        if ({d0, d1, v0, v1, issue, dual} !== 68'b0) $fatal(1, "reset");
        @(negedge clk); reset = 0;
        @(posedge clk); #1;
        if (pc1 !== 32'h14 || d0 !== f0 || d1 !== f1 ||
            {v0, v1, issue, dual} !== 4'b1111) $fatal(1, "capture");
        @(negedge clk); stall = 1; f0 = 32'h00300193; f1 = 0;
        repeat (2) begin
            @(posedge clk); #1;
            if (d0 !== 32'h00100093 || d1 !== 32'h00200113 ||
                {v0, v1, issue, dual} !== 4'b1111) $fatal(1, "stall hold");
        end
        @(negedge clk); flush = 1;
        @(posedge clk); #1;
        if ({d0, d1, v0, v1, issue, dual} !== 68'b0) $fatal(1, "flush priority");
        @(negedge clk); flush = 0; stall = 0;
        @(posedge clk); #1;
        if (d0 !== f0 || d1 !== f1 || {v0, v1, issue, dual} !== 4'b1000)
            $fatal(1, "resume");
        @(negedge clk); flush = 1;
        @(posedge clk); #1;
        if ({d0, d1, v0, v1, issue, dual} !== 68'b0) $fatal(1, "flush");
        @(negedge clk); flush = 0; f0 = 32'h00010001; f1 = 32'h00200113;
        @(posedge clk); #1;
        if ({v0, v1, issue, dual} !== 4'b0000) $fatal(1, "compressed lane 0");
        @(negedge clk); f0 = 32'h00100093; f1 = 32'h00010001;
        @(posedge clk); #1;
        if ({v0, v1, issue, dual} !== 4'b1000) $fatal(1, "compressed lane 1");
        @(negedge clk); pc = 32'h12; f1 = 32'h00200113;
        @(posedge clk); #1;
        if ({v0, v1, issue, dual} !== 4'b0000) $fatal(1, "halfword aligned PC");
        $display("PASS frontend synchronization");
        $finish;
    end
endmodule

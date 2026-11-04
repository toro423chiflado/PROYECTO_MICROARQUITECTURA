`timescale 1ns/1ps
module test_hazard;
    reg [4:0] Rs1E, Rs2E, RdE, RdM, RdW;
    reg [31:0] InstrD;
    reg RegWriteM, RegWriteW, MemReadE, PCSrcE;
    wire [1:0] ForwardAE, ForwardBE;
    wire StallF, StallD, FlushE, FlushD;
    integer op, source, errors;
    reg expected_rs1, expected_rs2, expected_stall;

    hazard dut(
        .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE), .RdM(RdM), .RdW(RdW),
        .InstrD(InstrD), .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
        .MemReadE(MemReadE), .PCSrcE(PCSrcE), .ForwardAE(ForwardAE),
        .ForwardBE(ForwardBE), .StallF(StallF), .StallD(StallD),
        .FlushE(FlushE), .FlushD(FlushD)
    );

    initial begin
        errors = 0;
        Rs1E = 0; Rs2E = 0; RdM = 0; RdW = 0;
        RegWriteM = 0; RegWriteW = 0; MemReadE = 1; PCSrcE = 0;
        RdE = 5;
        // Check all opcodes with matches in neither, either, or both fields.
        for (op = 0; op < 128; op = op + 1) begin
            expected_rs1 = (op == 7'h03 || op == 7'h23 || op == 7'h33 ||
                            op == 7'h13 || op == 7'h63 || op == 7'h67);
            expected_rs2 = (op == 7'h23 || op == 7'h33 || op == 7'h63);
            for (source = 0; source < 4; source = source + 1) begin
                InstrD = 0;
                InstrD[6:0] = op;
                InstrD[19:15] = (source & 1) ? 5 : 6;
                InstrD[24:20] = (source & 2) ? 5 : 6;
                expected_stall = (expected_rs1 && (source & 1)) ||
                                 (expected_rs2 && (source & 2));
                #1;
                if ({StallF, StallD, FlushE, FlushD} !==
                    {expected_stall, expected_stall, expected_stall, 1'b0}) begin
                    $display("FAIL op=%h source=%0d controls=%b%b%b%b", op,
                             source, StallF, StallD, FlushE, FlushD);
                    errors = errors + 1;
                end
            end
        end
        InstrD = 32'h005282b3; // add x5, x5, x5
        RdE = 0; InstrD[19:15] = 0; InstrD[24:20] = 0; #1;
        if ({StallF, StallD, FlushE, FlushD} !== 4'b0000) errors = errors + 1;
        RdE = 5; InstrD[19:15] = 5; InstrD[24:20] = 5; MemReadE = 0; #1;
        if ({StallF, StallD, FlushE, FlushD} !== 4'b0000) errors = errors + 1;
        MemReadE = 1; PCSrcE = 1; #1;
        if ({StallF, StallD, FlushE, FlushD} !== 4'b1111) errors = errors + 1;
        MemReadE = 0; #1;
        if ({StallF, StallD, FlushE, FlushD} !== 4'b0011) errors = errors + 1;
        if (errors != 0) $fatal(1, "hazard: %0d errors", errors);
        $display("PASS: load-use opcode and control checks");
        $finish;
    end
endmodule

module e2_top #(parameter PROGRAM = "test_e2p2.mem") (
    input clk, reset,
    output [31:0] WriteData, DataAdr,
    output MemWrite,
    output [31:0] PCF,
    output Issue0, Issue1, RedirectE,
    output [31:0] RedirectTargetE
);
    wire [31:0] instr0, instr1, read_data;
    e2_pipeline core(.clk(clk), .reset(reset), .PCF(PCF),
        .InstrF0(instr0), .InstrF1(instr1), .MemWriteM(MemWrite),
        .ALUResultM(DataAdr), .WriteDataM(WriteData), .ReadDataM(read_data),
        .Issue0(Issue0), .Issue1(Issue1), .RedirectE(RedirectE),
        .RedirectTargetE(RedirectTargetE));
    imem #(.PROGRAM(PROGRAM)) imem(.a(PCF), .rd(instr0), .a1(PCF+32'd4), .rd1(instr1));
    dmem dmem(.clk(clk), .we(MemWrite), .a(DataAdr), .wd(WriteData), .rd(read_data));
endmodule

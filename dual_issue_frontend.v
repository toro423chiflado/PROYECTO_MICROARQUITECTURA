// Frontend sencillo para la primera etapa Dual-Issue.
// Fetch trae dos palabras consecutivas y Decode las registra en dos lanes.
module dual_issue_frontend(
    input         clk,
    input         reset,
    input         StallD,
    input         FlushD,
    input  [31:0] PCF,
    input  [31:0] InstrF0,
    input  [31:0] InstrF1,
    output [31:0] PCF1,
    output reg [31:0] InstrD0,
    output reg [31:0] InstrD1,
    output reg        ValidD0,
    output reg        ValidD1,
    output reg        IssueD1,
    output reg        DualIssueD
);

    wire [6:0] op0 = InstrF0[6:0];
    wire [6:0] op1 = InstrF1[6:0];
    wire uses_rs1_1 = (op1 == 7'b0110011) || (op1 == 7'b0010011) ||
                      (op1 == 7'b0000011) || (op1 == 7'b0100011) ||
                      (op1 == 7'b1100011) || (op1 == 7'b1100111);
    wire uses_rs2_1 = (op1 == 7'b0110011) || (op1 == 7'b0100011) ||
                      (op1 == 7'b1100011);
    wire writes_rd_0 = (op0 == 7'b0110011) || (op0 == 7'b0010011) ||
                       (op0 == 7'b0000011) || (op0 == 7'b1101111) ||
                       (op0 == 7'b1100111);
    wire lane0_control = (op0 == 7'b1100011) || (op0 == 7'b1101111) ||
                         (op0 == 7'b1100111);
    wire lane0_memory = (op0 == 7'b0000011) || (op0 == 7'b0100011);
    // This frontend only decodes aligned 32-bit instructions, not RVC packets.
    wire valid0 = !PCF[1] && (InstrF0[1:0] == 2'b11);
    wire valid1 = valid0 && (InstrF1[1:0] == 2'b11);
    wire raw_dependency = writes_rd_0 && (InstrF0[11:7] != 5'd0) &&
                          ((uses_rs1_1 && (InstrF0[11:7] == InstrF1[19:15])) ||
                           (uses_rs2_1 && (InstrF0[11:7] == InstrF1[24:20])));

    assign PCF1 = PCF + 32'd4;

    always @(posedge clk or posedge reset) begin
        if (reset || FlushD) begin
            InstrD0   <= 32'd0;
            InstrD1   <= 32'd0;
            ValidD0   <= 1'b0;
            ValidD1   <= 1'b0;
            IssueD1   <= 1'b0;
            DualIssueD <= 1'b0;
        end else if (!StallD) begin
            InstrD0 <= InstrF0;
            InstrD1 <= InstrF1;
            ValidD0 <= valid0;
            ValidD1 <= valid1;

            // Se emiten dos instrucciones solo cuando no hay dependencia RAW
            // ni conflicto de control o memoria en la primera lane.
            IssueD1 <= valid0 && valid1 &&
                        !lane0_control && !lane0_memory && !raw_dependency;
            DualIssueD <= valid0 && valid1 &&
                          !lane0_control && !lane0_memory && !raw_dependency;
        end
    end
endmodule

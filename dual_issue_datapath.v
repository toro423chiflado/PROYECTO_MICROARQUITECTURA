// Segunda via preliminar: ejecuta operaciones ALU sencillas de la lane 1.
// No escribe aun al banco de registros; sirve para validar el datapath Dual-Issue.
module dual_issue_datapath(
    input  [31:0] InstrD0,
    input  [31:0] InstrD1,
    input         ValidD0,
    input         IssueD1,
    input  [31:0] RD1D,
    input  [31:0] RD2D,
    input  [31:0] RD1D_lane1,
    input  [31:0] RD2D_lane1,
    output [31:0] ALUResult0,
    output [31:0] ALUResult1,
    output        ValidE0,
    output        ValidE1
);
    wire [31:0] imm0 = {{20{InstrD0[31]}}, InstrD0[31:20]};
    wire [31:0] imm1 = {{20{InstrD1[31]}}, InstrD1[31:20]};
    wire [31:0] a0 = RD1D;
    wire [31:0] b0 = RD2D;
    wire [31:0] a1 = RD1D_lane1;
    wire [31:0] b1 = RD2D_lane1;
    wire [31:0] operandB0 = (InstrD0[6:0] == 7'b0010011) ? imm0 : b0;
    wire [31:0] operandB1 = (InstrD1[6:0] == 7'b0010011) ? imm1 : b1;
    reg  [31:0] result0;
    reg  [31:0] result1;

    // La segunda via usa lecturas adicionales del mismo banco de registros.
    always @(*) begin
        case (InstrD0[14:12])
            3'b000: result0 = (InstrD0[6:0] == 7'b0110011 && InstrD0[30]) ?
                               a0 - operandB0 : a0 + operandB0;
            3'b001: result0 = a0 << operandB0[4:0];
            3'b100: result0 = a0 ^ operandB0;
            3'b101: result0 = InstrD0[30] ? $signed(a0) >>> operandB0[4:0] :
                                      a0 >> operandB0[4:0];
            3'b110: result0 = a0 | operandB0;
            3'b111: result0 = a0 & operandB0;
            default: result0 = a0 + operandB0;
        endcase
    end

    always @(*) begin
        case (InstrD1[14:12])
            3'b000: result1 = (InstrD1[6:0] == 7'b0110011 && InstrD1[30]) ?
                               a1 - operandB1 : a1 + operandB1;
            3'b001: result1 = a1 << operandB1[4:0];
            3'b100: result1 = a1 ^ operandB1;
            3'b101: result1 = InstrD1[30] ? $signed(a1) >>> operandB1[4:0] :
                                      a1 >> operandB1[4:0];
            3'b110: result1 = a1 | operandB1;
            3'b111: result1 = a1 & operandB1;
            default: result1 = a1 + operandB1;
        endcase
    end

    assign ALUResult0 = result0;
    assign ALUResult1 = result1;
    assign ValidE0 = ValidD0;
    assign ValidE1 = IssueD1;
endmodule

`timescale 1ns/1ps
// Senales con nombre para las capturas del programa del profesor (configuracion C).
module tbw;
  initial begin $dumpfile("profe.vcd"); $dumpvars(0, tbw); end
  wire clk = testbench_profe.clk;
  integer ciclo = 0;
  always @(posedge clk) if (!testbench_profe.reset) ciclo = ciclo + 1;
  // Decode (posiciones 0 y 1): instruccion si es valida, si no 0
  // Se muestra el PC de cada instruccion (traducido a texto en GTKWave); FFFFFFFF = vacia
  wire [31:0] D0 = testbench_profe.c.core.dv[0] ? testbench_profe.c.core.dp[0] : 32'hFFFFFFFF;
  wire [31:0] D1 = testbench_profe.c.core.dv[1] ? testbench_profe.c.core.dp[1] : 32'hFFFFFFFF;
  wire Issue0 = testbench_profe.c.core.Issue0, Issue1 = testbench_profe.c.core.Issue1;
  wire pair_ok = testbench_profe.c.core.pair_ok;
  wire load_stall0 = testbench_profe.c.core.load_stall0, load_stall1 = testbench_profe.c.core.load_stall1;
  // Execute
  wire [31:0] E0 = testbench_profe.c.core.ev[0] ? testbench_profe.c.core.ep[0] : 32'hFFFFFFFF;
  wire [31:0] E1 = testbench_profe.c.core.ev[1] ? testbench_profe.c.core.ep[1] : 32'hFFFFFFFF;
  wire [31:0] SrcA0 = testbench_profe.c.core.xa[0], SrcB0 = testbench_profe.c.core.xb[0];
  wire [31:0] SrcA1 = testbench_profe.c.core.xa[1], SrcB1 = testbench_profe.c.core.xb[1];
  wire [31:0] ResE0 = testbench_profe.c.core.xr[0], ResE1 = testbench_profe.c.core.xr[1];
  // Memory y WB
  wire [31:0] M0 = testbench_profe.c.core.mv[0] ? testbench_profe.c.core.mi[0] : 32'd0;
  wire [31:0] M1 = testbench_profe.c.core.mv[1] ? testbench_profe.c.core.mi[1] : 32'd0;
  wire [31:0] ResM0 = testbench_profe.c.core.mr[0], ResM1 = testbench_profe.c.core.mr[1];
  wire MemWrite = testbench_profe.c_mw;
  wire [31:0] DataAdr = testbench_profe.c_adr, WriteData = testbench_profe.c.WriteData;
  wire [31:0] ReadData = testbench_profe.c.core.ReadDataM;
  wire memlane = testbench_profe.c.core.memlane;
  wire [1:0] RetireCnt = testbench_profe.c_ret;
  // Prediccion
  wire [31:0] PCF = testbench_profe.c.core.PCF;
  wire predF0 = testbench_profe.c.core.predF0, predF1 = testbench_profe.c.core.predF1;
  wire [31:0] PCD0 = testbench_profe.c.core.dp[0];
  wire PredD0 = testbench_profe.c.core.dpr[0], PredD1 = testbench_profe.c.core.dpr[1];
  wire BranchE = testbench_profe.c.core.BranchE, ctaken = testbench_profe.c.core.ctaken;
  wire PredE = testbench_profe.c.core.cpred, MispredictE = testbench_profe.c.core.MispredictE;
  wire control_lane0 = testbench_profe.c.core.control_lane0;
  wire [31:0] RedirectTarget = testbench_profe.c.core.RedirectTargetE;
  wire [1:0] cont_C2a = testbench_profe.c.core.bht[37];   // contador de beq x23, x2, C2a (PC 0x94)
  wire [1:0] cont_C2  = testbench_profe.c.core.bht[43];   // contador de beq x25, x2, C2 (PC 0xac)
  wire [1:0] cont_C1  = testbench_profe.c.core.bht[31];   // contador de beq x25, x2, C1 (PC 0x7c)
  // Comprobacion por etapas (testbench_profe)
  wire [3:0] chk_A = testbench_profe.chk_a, chk_B = testbench_profe.chk_b, chk_C = testbench_profe.chk_c;
  integer etapas_ok_C = 0;
  always @* etapas_ok_C = testbench_profe.etapas_ok_c;
  // registros del banco de C (estado arquitectonico tras cada escritura)
  wire [31:0] x10 = testbench_profe.c.core.rf.rf[10], x18 = testbench_profe.c.core.rf.rf[18];
  wire [31:0] x24 = testbench_profe.c.core.rf.rf[24], x22 = testbench_profe.c.core.rf.rf[22], x21 = testbench_profe.c.core.rf.rf[21];
  wire [31:0] x28 = testbench_profe.c.core.rf.rf[28], x29 = testbench_profe.c.core.rf.rf[29], x31 = testbench_profe.c.core.rf.rf[31];
  wire [31:0] M_x1_8  = testbench_profe.c.dmem.RAM[130], M_x1_20 = testbench_profe.c.dmem.RAM[133];
  wire [31:0] M_x1_32 = testbench_profe.c.dmem.RAM[136], M_x1_52 = testbench_profe.c.dmem.RAM[141];
  // una fila por configuracion y etapa
  wire A_etapaA = testbench_profe.chk_a[0], A_etapaB = testbench_profe.chk_a[1], A_etapaC = testbench_profe.chk_a[2], A_etapaD = testbench_profe.chk_a[3];
  wire B_etapaA = testbench_profe.chk_b[0], B_etapaB = testbench_profe.chk_b[1], B_etapaC = testbench_profe.chk_b[2], B_etapaD = testbench_profe.chk_b[3];
  wire C_etapaA = testbench_profe.chk_c[0], C_etapaB = testbench_profe.chk_c[1], C_etapaC = testbench_profe.chk_c[2], C_etapaD = testbench_profe.chk_c[3];
endmodule

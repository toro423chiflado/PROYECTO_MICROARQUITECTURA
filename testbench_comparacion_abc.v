`timescale 1ns/1ps
// =============================================================================
// testbench_comparacion_abc: medicion de A (single-issue), B (dual-issue) y
// C (dual-issue con prediccion de saltos de 2 bits) con el mismo programa.
//
// Mismo criterio que testbench_comparacion (E2):
//   - fin de programa: halt = jal x0, 0 (0x0000006f);
//   - ciclo 1 = primer flanco de subida despues de soltar el reset;
//   - ultimo ciclo = el ciclo en que halt llega a WB (incluido);
//   - retiradas = instrucciones validas que llegan a WB (sin burbujas,
//     instrucciones anuladas ni el halt).
//
// Comprobaciones:
//   1. A, B y C retiran el mismo numero de instrucciones.
//   2. B y C terminan con los mismos 31 registros y 256 palabras que A.
//   3. A coincide con el modelo de referencia (EXP_REGS, EXP_MEM), si se dan.
// =============================================================================
module testbench_comparacion_abc;
    parameter PROGRAM    = "benchmark_propio.mem";
    parameter DATA       = "benchmark_propio.data.mem";
    parameter EXP_REGS   = "benchmark_propio.exp_regs";
    parameter EXP_MEM    = "benchmark_propio.exp_mem";
    parameter MAX_CYCLES = 200000;
    parameter BHT_BITS   = 6;        // tamano de la tabla del predictor de C (2^BHT_BITS)
    localparam DEPTH     = 256;

    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    // --------------------------------------------------------------- nucleos
    wire       a_retire, a_halt;
    wire [1:0] b_retire, c_retire;
    wire       b_halt, b_issue0, b_issue1, b_redirect;
    wire       c_halt, c_issue0, c_issue1, c_redirect, c_branch, c_mispredict;

    top #(.PROGRAM(PROGRAM)) a (
        .clk(clk), .reset(reset), .RetireW(a_retire), .HaltW(a_halt));

    e2_top #(.PROGRAM(PROGRAM)) b (
        .clk(clk), .reset(reset), .Issue0(b_issue0), .Issue1(b_issue1),
        .RedirectE(b_redirect), .RetireCnt(b_retire), .HaltW(b_halt));

    e3_top #(.PROGRAM(PROGRAM), .BHT_BITS(BHT_BITS)) c (
        .clk(clk), .reset(reset), .Issue0(c_issue0), .Issue1(c_issue1),
        .RedirectE(c_redirect), .RetireCnt(c_retire), .HaltW(c_halt),
        .BranchE(c_branch), .MispredictE(c_mispredict));

    // --------------------------------------------------------------- estado
    reg [31:0] data_init [0:DEPTH-1];
    reg [31:0] exp_regs  [0:31];
    reg [31:0] exp_mem   [0:DEPTH-1];

    integer i, errors = 0, total = 0;
    integer a_cycles = 0, a_retired = 0;
    integer b_cycles = 0, b_retired = 0, b_issue2 = 0, b_issue1only = 0, b_redirects = 0;
    integer c_cycles = 0, c_retired = 0, c_issue2 = 0, c_issue1only = 0, c_redirects = 0;
    integer c_branches = 0, c_branch_miss = 0, c_jal = 0, c_jalr = 0;
    reg a_done = 0, b_done = 0, c_done = 0;
    real ipc_a, ipc_b, ipc_c;

    initial begin
        #1;
        if (DATA != "") begin
            for (i = 0; i < DEPTH; i = i + 1) data_init[i] = 32'd0;
            $readmemh(DATA, data_init);
            for (i = 0; i < DEPTH; i = i + 1) begin
                a.dmem.RAM[i] = data_init[i];
                b.dmem.RAM[i] = data_init[i];
                c.dmem.RAM[i] = data_init[i];
            end
        end
        for (i = 0; i < 32; i = i + 1) begin
            a.rvpipe.dp.rf.rf[i] = 32'd0;
            b.core.rf.rf[i]      = 32'd0;
            c.core.rf.rf[i]      = 32'd0;
        end
        if (EXP_REGS != "") $readmemh(EXP_REGS, exp_regs);
        if (EXP_MEM  != "") $readmemh(EXP_MEM,  exp_mem);
        #19 reset = 0;   // se suelta el reset en un flanco de bajada (t = 20 ns)
    end

    // --------------------------------------------------------------- contadores
    always @(posedge clk) if (!reset) begin
        if (!a_done) begin
            a_cycles  = a_cycles + 1;
            a_retired = a_retired + a_retire;
            if (a_halt) a_done = 1;
        end
        if (!b_done) begin
            b_cycles     = b_cycles + 1;
            b_retired    = b_retired + b_retire;
            b_issue2     = b_issue2 + b_issue1;
            b_issue1only = b_issue1only + (b_issue0 && !b_issue1);
            b_redirects  = b_redirects + b_redirect;
            if (b_halt) b_done = 1;
        end
        if (!c_done) begin
            c_cycles      = c_cycles + 1;
            c_retired     = c_retired + c_retire;
            c_issue2      = c_issue2 + c_issue1;
            c_issue1only  = c_issue1only + (c_issue0 && !c_issue1);
            c_redirects   = c_redirects + c_redirect;
            c_branches    = c_branches + c_branch;
            c_branch_miss = c_branch_miss + (c_branch && c_mispredict);
            c_jal         = c_jal  + (c.core.control_valid && c.core.ci[6:0] == 7'h6f);
            c_jalr        = c_jalr + (c.core.control_valid && c.core.ci[6:0] == 7'h67);
            if (c_halt) c_done = 1;
        end
        if (a_done && b_done && c_done) begin
            #1 report();
            $finish;
        end
        if (a_cycles >= MAX_CYCLES || b_cycles >= MAX_CYCLES || c_cycles >= MAX_CYCLES) begin
            $display("RESULT FAIL timeout: A=%0d B=%0d C=%0d (falta halt = jal x0, 0?)",
                     a_done, b_done, c_done);
            $finish;
        end
    end

    // --------------------------------------------------------------- reporte
    task check;
        input [255:0] what;
        input [31:0]  got, expected;
        begin
            total = total + 1;
            if (got !== expected) begin
                errors = errors + 1;
                if (errors <= 10) $display("  ERROR %0s = %h, esperado %h", what, got, expected);
            end
        end
    endtask

    task report;
        begin
            ipc_a = 1.0 * a_retired / a_cycles;
            ipc_b = 1.0 * b_retired / b_cycles;
            ipc_c = 1.0 * c_retired / c_cycles;
            $display("");
            $display("==== Comparacion A vs B vs C: %0s ====", PROGRAM);
            $display("  Config               Retiradas  Ciclos      IPC     CPI  Speedup/A  Speedup/B");
            $display("  A single-issue       %9d %7d   %6.3f  %6.3f   %6.3f", a_retired, a_cycles, ipc_a, 1.0/ipc_a, 1.0);
            $display("  B dual-issue         %9d %7d   %6.3f  %6.3f   %6.3f     %6.3f", b_retired, b_cycles, ipc_b, 1.0/ipc_b,
                     1.0*a_cycles/b_cycles, 1.0);
            $display("  C dual + predictor   %9d %7d   %6.3f  %6.3f   %6.3f     %6.3f", c_retired, c_cycles, ipc_c, 1.0/ipc_c,
                     1.0*a_cycles/c_cycles, 1.0*b_cycles/c_cycles);
            $display("  B: ciclos con 2 emitidas=%0d con 1=%0d redirecciones=%0d", b_issue2, b_issue1only, b_redirects);
            $display("  C: ciclos con 2 emitidas=%0d con 1=%0d redirecciones=%0d", c_issue2, c_issue1only, c_redirects);
            $display("  C predictor: branches=%0d fallos=%0d precision=%0.1f%%  jal=%0d (siempre aciertan)  jalr=%0d (siempre fallan)",
                     c_branches, c_branch_miss,
                     100.0 * (c_branches - c_branch_miss) / (c_branches > 0 ? c_branches : 1), c_jal, c_jalr);

            // 1. Mismo numero de instrucciones retiradas
            if (a_retired != b_retired || a_retired != c_retired) begin
                errors = errors + 1;
                $display("  ERROR retiradas distintas: A=%0d B=%0d C=%0d", a_retired, b_retired, c_retired);
            end
            // 2. Mismo estado final
            for (i = 1; i < 32; i = i + 1) begin
                check("x(B vs A)", b.core.rf.rf[i], a.rvpipe.dp.rf.rf[i]);
                check("x(C vs A)", c.core.rf.rf[i], a.rvpipe.dp.rf.rf[i]);
            end
            for (i = 0; i < DEPTH; i = i + 1) begin
                check("mem(B vs A)", b.dmem.RAM[i], a.dmem.RAM[i]);
                check("mem(C vs A)", c.dmem.RAM[i], a.dmem.RAM[i]);
            end
            // 3. Modelo de referencia
            if (EXP_REGS != "")
                for (i = 1; i < 32; i = i + 1) check("x(A vs esperado)", a.rvpipe.dp.rf.rf[i], exp_regs[i]);
            if (EXP_MEM != "")
                for (i = 0; i < DEPTH; i = i + 1) check("mem(A vs esperado)", a.dmem.RAM[i], exp_mem[i]);

            if (errors == 0)
                $display("RESULT PASS A, B y C equivalentes (%0d comprobaciones) speedup C/A=%0.3f C/B=%0.3f",
                         total, 1.0*a_cycles/c_cycles, 1.0*b_cycles/c_cycles);
            else
                $display("RESULT FAIL %0d diferencias", errors);
        end
    endtask
endmodule

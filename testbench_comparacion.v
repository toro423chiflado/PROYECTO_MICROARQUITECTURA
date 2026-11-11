`timescale 1ns/1ps
// =============================================================================
// testbench_comparacion: medicion generica A (single-issue) vs B (dual-issue)
//
// Sirve para CUALQUIER programa RV32I (el propio o el del profesor), sin
// listas de PCs esperados. Ambos nucleos reciben el mismo programa, los mismos
// datos iniciales y el mismo reset.
//
// Convencion de fin de programa: la ultima instruccion es  halt = jal x0, 0
// (0x0000006f, un salto a si misma).
//
// Criterio de medicion (identico para A y B):
//   - Ciclo 1 = primer flanco de subida despues de soltar el reset.
//   - Ultimo ciclo = el ciclo en que halt llega a WB (incluido).
//   - Instrucciones retiradas = instrucciones validas que llegan a WB
//     (no cuentan burbujas, instrucciones anuladas por saltos ni el halt).
//
// Parametros:
//   PROGRAM   instrucciones en hex (obligatorio)
//   DATA      contenido inicial de DMem en hex ("" = todo en cero)
//   EXP_REGS  valores esperados de x0..x31 ("" = no se comprueba)
//   EXP_MEM   contenido esperado de DMem   ("" = no se comprueba)
//
// Siempre se comprueba que A y B terminen con registros y memoria IDENTICOS.
// =============================================================================
module testbench_comparacion;
    parameter PROGRAM    = "benchmark_propio.mem";
    parameter DATA       = "benchmark_propio.data.mem";
    parameter EXP_REGS   = "benchmark_propio.exp_regs";
    parameter EXP_MEM    = "benchmark_propio.exp_mem";
    parameter MAX_CYCLES = 200000;
    localparam DEPTH     = 256;

    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    // --------------------------------------------------------------- nucleos
    wire        a_retire, a_halt;
    wire [1:0]  b_retire;
    wire        b_halt, b_issue0, b_issue1, b_redirect;

    top #(.PROGRAM(PROGRAM)) a (
        .clk(clk), .reset(reset), .RetireW(a_retire), .HaltW(a_halt));

    e2_top #(.PROGRAM(PROGRAM)) b (
        .clk(clk), .reset(reset), .Issue0(b_issue0), .Issue1(b_issue1),
        .RedirectE(b_redirect), .RetireCnt(b_retire), .HaltW(b_halt));

    // --------------------------------------------------------------- estado
    reg [31:0] data_init [0:DEPTH-1];
    reg [31:0] exp_regs  [0:31];
    reg [31:0] exp_mem   [0:DEPTH-1];

    integer i, errors = 0, total = 0;
    integer a_cycles = 0, a_retired = 0, a_stalls = 0, a_taken = 0;
    integer b_cycles = 0, b_retired = 0, b_stalls = 0, b_taken = 0;
    integer b_issue2 = 0, b_issue1only = 0;
    reg a_done = 0, b_done = 0;
    real ipc_a, ipc_b;

    initial begin
        // Las memorias ya se inicializaron en sus propios initial; se espera
        // un instante y luego se cargan los datos y se limpian los registros.
        #1;
        if (DATA != "") begin
            for (i = 0; i < DEPTH; i = i + 1) data_init[i] = 32'd0;
            $readmemh(DATA, data_init);
            for (i = 0; i < DEPTH; i = i + 1) begin
                a.dmem.RAM[i] = data_init[i];
                b.dmem.RAM[i] = data_init[i];
            end
        end
        for (i = 0; i < 32; i = i + 1) begin
            a.rvpipe.dp.rf.rf[i] = 32'd0;
            b.core.rf.rf[i]      = 32'd0;
        end
        if (EXP_REGS != "") $readmemh(EXP_REGS, exp_regs);
        if (EXP_MEM  != "") $readmemh(EXP_MEM,  exp_mem);
        #19 reset = 0;   // se suelta el reset en un flanco de bajada (t = 20 ns)
    end

    // --------------------------------------------------------------- contadores
    // En cada flanco se leen las senales del ciclo que termina.
    always @(posedge clk) if (!reset) begin
        if (!a_done) begin
            a_cycles  = a_cycles + 1;
            a_retired = a_retired + a_retire;
            a_stalls  = a_stalls + a.rvpipe.StallD;     // stall load-use
            a_taken   = a_taken  + a.rvpipe.PCSrcE;     // saltos tomados (flush)
            if (a_halt) a_done = 1;
        end
        if (!b_done) begin
            b_cycles     = b_cycles + 1;
            b_retired    = b_retired + b_retire;
            b_issue2     = b_issue2 + b_issue1;                    // salen 2
            b_issue1only = b_issue1only + (b_issue0 && !b_issue1);  // sale 1
            b_stalls     = b_stalls + (b.core.dv[0] && !b_issue0 && !b_redirect);
            b_taken      = b_taken  + b_redirect;
            if (b_halt) b_done = 1;
        end
        if (a_done && b_done) begin
            #1 report();
            $finish;
        end
        if (a_cycles >= MAX_CYCLES || b_cycles >= MAX_CYCLES) begin
            $display("RESULT FAIL timeout: A termino=%0d B termino=%0d (falta halt = jal x0, 0?)",
                     a_done, b_done);
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
        reg [8*16-1:0] name;
        begin
            $display("");
            $display("==== Comparacion A vs B: %0s ====", PROGRAM);
            $display("  Config               Retiradas  Ciclos      IPC     CPI");
            ipc_a = 1.0 * a_retired / a_cycles;
            ipc_b = 1.0 * b_retired / b_cycles;
            $display("  A single-issue       %9d %7d   %6.3f  %6.3f", a_retired, a_cycles, ipc_a, 1.0 / ipc_a);
            $display("  B dual-issue         %9d %7d   %6.3f  %6.3f", b_retired, b_cycles, ipc_b, 1.0 / ipc_b);
            $display("  Speedup A->B = %0.3f", 1.0 * a_cycles / b_cycles);
            $display("  A: stalls load-use=%0d  saltos tomados=%0d", a_stalls, a_taken);
            $display("  B: ciclos con 2 emitidas=%0d  con 1=%0d  stalls=%0d  saltos tomados=%0d  uso doble emision=%0.1f%%",
                     b_issue2, b_issue1only, b_stalls, b_taken,
                     100.0 * b_issue2 / ((b_issue2 + b_issue1only) > 0 ? (b_issue2 + b_issue1only) : 1));

            // 1. Equivalencia funcional A == B
            if (a_retired != b_retired) begin
                errors = errors + 1;
                $display("  ERROR instrucciones retiradas distintas: A=%0d B=%0d", a_retired, b_retired);
            end
            for (i = 1; i < 32; i = i + 1)
                check("x(A vs B)", b.core.rf.rf[i], a.rvpipe.dp.rf.rf[i]);
            for (i = 0; i < DEPTH; i = i + 1)
                check("mem(A vs B)", b.dmem.RAM[i], a.dmem.RAM[i]);

            // 2. Comparacion con el resultado esperado (si se dio)
            if (EXP_REGS != "")
                for (i = 1; i < 32; i = i + 1) check("x(A vs esperado)", a.rvpipe.dp.rf.rf[i], exp_regs[i]);
            if (EXP_MEM != "")
                for (i = 0; i < DEPTH; i = i + 1) check("mem(A vs esperado)", a.dmem.RAM[i], exp_mem[i]);

            if (errors == 0)
                $display("RESULT PASS A y B equivalentes (%0d comprobaciones) speedup=%0.3f", total, 1.0 * a_cycles / b_cycles);
            else
                $display("RESULT FAIL %0d diferencias", errors);
        end
    endtask
endmodule

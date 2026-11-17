`timescale 1ns/1ps
// =============================================================================
// testbench_profe: programa de prueba del profesor (programa_profesor.s) en las tres
// configuraciones: A (single-issue), B (dual-issue) y C (dual-issue con predictor).
//
// Comprobacion al cierre de cada etapa. Cada etapa termina con un store unico:
//   A: sw x10, 8(x1)   B: sw x18, 20(x1)   C: sw x24, 32(x1)   D: sw x31, 52(x1)
// Se compara el estado arquitectonico con el que da el enunciado para esa etapa
// (registros no indicados = 0; memoria no indicada = 0):
//   - memoria: en el flanco en que el store de cierre escribe (etapa MEM);
//   - registros: en A, en ese mismo flanco (la instruccion anterior escribe en WB a la
//     vez y las posteriores aun no llegan a WB). En B y C, con una copia del banco que
//     aplica las escrituras de WB en orden de programa (via 0 y luego via 1) y se
//     compara cuando el store llega a WB; asi no cuenta la instruccion mas joven que
//     puede ir en el mismo par.
// Las senales chk_a, chk_b y chk_c (4 bits, uno por etapa A..D) marcan en las ondas
// el instante de cada comprobacion; etapas_ok_* cuenta las etapas que pasaron.
//
// x1 = 1536 es la base de datos. DMem tiene 256 palabras y usa los bits [9:2] de la
// direccion, igual que el modelo de referencia: M[x1+4k] es la palabra 128+k.
//
// Rendimiento: mismo criterio que testbench_comparacion; el ultimo ciclo es aquel en
// que la primera instruccion de "fin" (jal x0, fin) llega a WB, de modo que el bucle
// final no se cuenta y la propia instruccion de fin no se cuenta como retirada.
// =============================================================================
module testbench_profe;
    parameter PROGRAM = "programa_profesor.mem";
    localparam BASE = 128;      // palabra de DMem que corresponde a x1 = 1536

    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    wire a_mw, a_ret, a_halt, b_mw, b_halt, c_mw, c_halt, c_branch, c_miss;
    wire b_i0, b_i1, c_i0, c_i1;
    wire [31:0] a_adr, b_adr, c_adr;
    wire [1:0]  b_ret, c_ret;

    top    #(.PROGRAM(PROGRAM)) a(.clk(clk), .reset(reset), .MemWrite(a_mw), .DataAdr(a_adr),
                                  .RetireW(a_ret), .HaltW(a_halt));
    e2_top #(.PROGRAM(PROGRAM)) b(.clk(clk), .reset(reset), .MemWrite(b_mw), .DataAdr(b_adr),
                                  .Issue0(b_i0), .Issue1(b_i1), .RetireCnt(b_ret), .HaltW(b_halt));
    e3_top #(.PROGRAM(PROGRAM)) c(.clk(clk), .reset(reset), .MemWrite(c_mw), .DataAdr(c_adr),
                                  .Issue0(c_i0), .Issue1(c_i1), .RetireCnt(c_ret), .HaltW(c_halt),
                                  .BranchE(c_branch), .MispredictE(c_miss));

    // ------------------------------------------------------- estados esperados
    reg [31:0] er [0:3][0:31];          // registros al cierre de A, B, C y D
    reg [31:0] em [0:3][0:13];          // M[x1+0] .. M[x1+52]
    reg [31:0] store_end [0:3];         // store que cierra cada etapa
    reg [31:0] addr_end  [0:3];
    integer i, k, errors = 0;
    initial begin
        for (k = 0; k < 4; k = k + 1) begin
            for (i = 0; i < 32; i = i + 1) er[k][i] = 0;
            for (i = 0; i < 14; i = i + 1) em[k][i] = 0;
        end
        er[0][1] = 1536;
        er[0][2] = 1;
        er[0][3] = 8;
        er[0][4] = 3;
        er[0][5] = 11;
        er[0][6] = 5;
        er[0][7] = 16;
        er[0][8] = 2;
        er[0][9] = 7;
        er[0][10] = 12;
        em[0][0] = 11;
        em[0][1] = 5;
        em[0][2] = 12;
        er[1][1] = 1536;
        er[1][2] = 1;
        er[1][3] = 8;
        er[1][4] = 3;
        er[1][5] = 11;
        er[1][6] = 5;
        er[1][7] = 16;
        er[1][8] = 2;
        er[1][9] = 7;
        er[1][10] = 12;
        er[1][11] = 11;
        er[1][12] = 16;
        er[1][13] = 5;
        er[1][14] = 12;
        er[1][15] = 7;
        er[1][16] = 7;
        er[1][17] = 16;
        er[1][18] = 23;
        em[1][0] = 11;
        em[1][1] = 5;
        em[1][2] = 12;
        em[1][3] = 7;
        em[1][4] = 16;
        em[1][5] = 23;
        er[2][1] = 1536;
        er[2][2] = 1;
        er[2][3] = 8;
        er[2][4] = 3;
        er[2][5] = 11;
        er[2][6] = 5;
        er[2][7] = 16;
        er[2][8] = 2;
        er[2][9] = 7;
        er[2][10] = 12;
        er[2][11] = 11;
        er[2][12] = 16;
        er[2][13] = 5;
        er[2][14] = 12;
        er[2][15] = 7;
        er[2][16] = 7;
        er[2][17] = 16;
        er[2][18] = 23;
        er[2][19] = 12;
        er[2][20] = 12;
        er[2][21] = 24;
        er[2][22] = 18;
        er[2][24] = 24;
        er[2][26] = 6;
        em[2][0] = 11;
        em[2][1] = 5;
        em[2][2] = 12;
        em[2][3] = 7;
        em[2][4] = 16;
        em[2][5] = 23;
        em[2][6] = 24;
        em[2][7] = 18;
        em[2][8] = 24;
        er[3][1] = 1536;
        er[3][2] = 1;
        er[3][3] = 8;
        er[3][4] = 3;
        er[3][5] = 11;
        er[3][6] = 5;
        er[3][7] = 16;
        er[3][8] = 2;
        er[3][9] = 7;
        er[3][10] = 12;
        er[3][11] = 11;
        er[3][12] = 16;
        er[3][13] = 5;
        er[3][14] = 12;
        er[3][15] = 7;
        er[3][16] = 7;
        er[3][17] = 16;
        er[3][18] = 23;
        er[3][19] = 6;
        er[3][20] = 6;
        er[3][21] = 24;
        er[3][22] = 18;
        er[3][24] = 24;
        er[3][26] = 4;
        er[3][25] = 4;
        er[3][27] = 1560;
        er[3][28] = 74;
        er[3][29] = 4;
        er[3][30] = 23;
        er[3][31] = 1;
        em[3][0] = 11;
        em[3][1] = 5;
        em[3][2] = 12;
        em[3][3] = 7;
        em[3][4] = 16;
        em[3][5] = 23;
        em[3][6] = 24;
        em[3][7] = 18;
        em[3][8] = 24;
        em[3][9] = 74;
        em[3][10] = 4;
        em[3][11] = 0;
        em[3][12] = 1;
        em[3][13] = 1;
        store_end[0] = 32'h00a0a423; addr_end[0] = 1536 + 8;
        store_end[1] = 32'h0120aa23; addr_end[1] = 1536 + 20;
        store_end[2] = 32'h0380a023; addr_end[2] = 1536 + 32;
        store_end[3] = 32'h03f0aa23; addr_end[3] = 1536 + 52;
    end

    initial begin
        #1;
        for (i = 0; i < 32; i = i + 1) begin
            a.rvpipe.dp.rf.rf[i] = 0; b.core.rf.rf[i] = 0; c.core.rf.rf[i] = 0;
        end
        #19 reset = 0;
    end

    // ------------------------------------------------------- comprobaciones
    reg [3:0] chk_a = 0, chk_b = 0, chk_c = 0;           // pulso: comprobacion de la etapa
    integer etapas_ok_a = 0, etapas_ok_b = 0, etapas_ok_c = 0;
    reg [31:0] sb [0:31], sc [0:31];                     // copia en orden de B y C
    initial for (i = 0; i < 32; i = i + 1) begin sb[i] = 0; sc[i] = 0; end
    integer cyc = 0;
    always @(posedge clk) if (!reset) cyc = cyc + 1;

    function [7:0] nombre(input integer s);
        nombre = "A" + s;
    endfunction

    task check_mem(input [7:0] core, input integer s, input integer which);
        integer w, bad;
        reg [31:0] got;
        begin
            bad = 0;
            for (w = 0; w < 256; w = w + 1) begin
                got = (which == 0) ? a.dmem.RAM[w] : (which == 1) ? b.dmem.RAM[w] : c.dmem.RAM[w];
                if (got !== ((w >= BASE && w < BASE + 14) ? em[s][w - BASE] : 32'd0)) begin
                    bad = bad + 1;
                    $display("  ERROR %c etapa %c: M[x1+%0d] = %0d", core, nombre(s), 4*(w-BASE), got);
                end
            end
            errors = errors + bad;
        end
    endtask

    task check_regs(input [7:0] core, input integer s, input integer which);
        integer r, bad;
        reg [31:0] got;
        begin
            bad = 0;
            for (r = 1; r < 32; r = r + 1) begin
                got = (which == 0) ? a.rvpipe.dp.rf.rf[r] : (which == 1) ? sb[r] : sc[r];
                if (got !== er[s][r]) begin
                    bad = bad + 1;
                    $display("  ERROR %c etapa %c: x%0d = %0d, esperado %0d", core, nombre(s), r, got, er[s][r]);
                end
            end
            errors = errors + bad;
            if (bad == 0) begin
                $display("  %c etapa %c: PASS (ciclo %0d, t = %0t)", core, nombre(s), cyc, $time);
                if (which == 0) etapas_ok_a = etapas_ok_a + 1;
                if (which == 1) etapas_ok_b = etapas_ok_b + 1;
                if (which == 2) etapas_ok_c = etapas_ok_c + 1;
            end
        end
    endtask

    // A: estado completo en el flanco en que escribe el store de cierre
    integer ka, sa;
    always @(posedge clk) if (!reset) begin
        chk_a <= 0;
        sa = -1;
        for (ka = 0; ka < 4; ka = ka + 1)
            if (a_mw && a_adr == addr_end[ka]) sa = ka;
        if (sa >= 0) begin
            chk_a[sa] <= 1;
            #1 check_mem("A", sa, 0); check_regs("A", sa, 0);
        end
    end

    // B y C: memoria al escribir el store; registros cuando el store llega a WB
    task retire_lane(input integer which, input integer lane);
        reg v; reg [31:0] ins, res; integer s;
        begin
            v   = (which == 1) ? b.core.wv[lane] : c.core.wv[lane];
            ins = (which == 1) ? b.core.wi[lane] : c.core.wi[lane];
            res = (which == 1) ? b.core.wr[lane] : c.core.wr[lane];
            if (v) begin
                if ((which == 1 ? b.core.writes(ins) : c.core.writes(ins)) && ins[11:7] != 0) begin
                    if (which == 1) sb[ins[11:7]] = res; else sc[ins[11:7]] = res;
                end
                for (s = 0; s < 4; s = s + 1)
                    if (ins == store_end[s]) begin
                        if (which == 1) chk_b[s] <= 1; else chk_c[s] <= 1;
                        check_regs(which == 1 ? "B" : "C", s, which);
                    end
            end
        end
    endtask

    integer kb, sbm, scm;
    always @(posedge clk) if (!reset) begin
        chk_b <= 0; chk_c <= 0;
        retire_lane(1, 0); retire_lane(1, 1);
        retire_lane(2, 0); retire_lane(2, 1);
        sbm = -1; scm = -1;
        for (kb = 0; kb < 4; kb = kb + 1) begin
            if (b_mw && b_adr == addr_end[kb]) sbm = kb;
            if (c_mw && c_adr == addr_end[kb]) scm = kb;
        end
        #1;
        if (sbm >= 0) check_mem("B", sbm, 1);
        if (scm >= 0) check_mem("C", scm, 2);
    end

    // ------------------------------------------------------- rendimiento
    integer a_cyc = 0, a_n = 0, b_cyc = 0, b_n = 0, c_cyc = 0, c_n = 0;
    integer b_two = 0, c_two = 0, b_red = 0, c_red = 0, c_br = 0, c_brm = 0;
    reg a_done = 0, b_done = 0, c_done = 0;
    always @(posedge clk) if (!reset) begin
        if (!a_done) begin a_cyc = a_cyc + 1; a_n = a_n + a_ret; if (a_halt) a_done = 1; end
        if (!b_done) begin b_cyc = b_cyc + 1; b_n = b_n + b_ret; b_two = b_two + b_i1;
                           b_red = b_red + b.RedirectE; if (b_halt) b_done = 1; end
        if (!c_done) begin c_cyc = c_cyc + 1; c_n = c_n + c_ret; c_two = c_two + c_i1;
                           c_red = c_red + c.RedirectE; c_br = c_br + c_branch;
                           c_brm = c_brm + (c_branch && c_miss); if (c_halt) c_done = 1; end
        if (a_done && b_done && c_done) begin
            #2;
            $display("");
            $display("  Indicador                 Pipeline (A)  Dual-Issue (B)  Optimizado (C)");
            $display("  Ciclos totales            %12d  %14d  %14d", a_cyc, b_cyc, c_cyc);
            $display("  Instrucciones retiradas   %12d  %14d  %14d", a_n, b_n, c_n);
            $display("  CPI                       %12.3f  %14.3f  %14.3f", 1.0*a_cyc/a_n, 1.0*b_cyc/b_n, 1.0*c_cyc/c_n);
            $display("  IPC                       %12.3f  %14.3f  %14.3f", 1.0*a_n/a_cyc, 1.0*b_n/b_cyc, 1.0*c_n/c_cyc);
            $display("  Speedup vs. pipeline      %12.3f  %14.3f  %14.3f", 1.0, 1.0*a_cyc/b_cyc, 1.0*a_cyc/c_cyc);
            $display("  B: ciclos con 2 emitidas=%0d redirecciones=%0d", b_two, b_red);
            $display("  C: ciclos con 2 emitidas=%0d redirecciones=%0d branches=%0d fallos=%0d precision=%0.1f%%",
                     c_two, c_red, c_br, c_brm, 100.0*(c_br - c_brm)/c_br);
            if (a_n != b_n || a_n != c_n) begin
                errors = errors + 1; $display("  ERROR retiradas distintas");
            end
            if (errors == 0 && etapas_ok_a == 4 && etapas_ok_b == 4 && etapas_ok_c == 4)
                $display("RESULT PASS programa del profesor: etapas A-D correctas en A, B y C");
            else
                $display("RESULT FAIL errores=%0d etapas A=%0d B=%0d C=%0d", errors, etapas_ok_a, etapas_ok_b, etapas_ok_c);
            $finish;
        end
        if (cyc > 5000) begin $display("RESULT FAIL timeout"); $finish; end
    end
endmodule

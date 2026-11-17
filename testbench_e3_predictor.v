`timescale 1ns/1ps
// =============================================================================
// testbench_e3_predictor: prueba dirigida del predictor de 2 bits (configuracion C)
// con e3_demo_pred.s. Comprueba el estado final contra el modelo de referencia y
// que el numero de fallos de prediccion sea exactamente el calculado a mano:
//   - bne del loop (T T T T N): 2 fallos (la primera vez y la salida);
//   - jal: 0 fallos (se predice tomado en Fetch con su destino exacto);
//   - beq x0, x0 (una sola vez, contador en 01): 1 fallo;
//   - jalr: 1 fallo (no se predice).
// Tambien exige que el contador del bne termine en 10 (tomado debil).
// =============================================================================
module testbench_e3_predictor;
    reg clk = 0, reset = 1;
    always #5 clk = ~clk;

    wire [1:0] retire;
    wire halt, redirect, branch, mispredict;
    e3_top #(.PROGRAM("e3_demo_pred.mem")) dut (
        .clk(clk), .reset(reset), .RedirectE(redirect), .RetireCnt(retire),
        .HaltW(halt), .BranchE(branch), .MispredictE(mispredict));

    reg [31:0] exp_regs [0:31];
    reg [31:0] exp_mem  [0:255];
    integer i, cycles = 0, retired = 0, branches = 0, branch_miss = 0;
    integer jal_seen = 0, jal_miss = 0, jalr_seen = 0, jalr_miss = 0;
    reg done = 0;

    initial begin
        #1;
        for (i = 0; i < 32; i = i + 1) dut.core.rf.rf[i] = 32'd0;
        for (i = 0; i < 256; i = i + 1) dut.dmem.RAM[i] = 32'd0;
        $readmemh("e3_demo_pred.exp_regs", exp_regs);
        $readmemh("e3_demo_pred.exp_mem", exp_mem);
        #19 reset = 0;
    end

    always @(posedge clk) if (!reset && !done) begin
        cycles  = cycles + 1;
        retired = retired + retire;
        branches    = branches + branch;
        branch_miss = branch_miss + (branch && mispredict);
        // jal distintos del halt (jal x0, 0)
        if (dut.core.control_valid && dut.core.ci[6:0] == 7'h6f && dut.core.ci != 32'h0000006f) begin
            jal_seen = jal_seen + 1; jal_miss = jal_miss + mispredict;
        end
        if (dut.core.control_valid && dut.core.ci[6:0] == 7'h67) begin
            jalr_seen = jalr_seen + 1; jalr_miss = jalr_miss + mispredict;
        end
        if (halt) begin
            done = 1;
            #1 finish_checks();
        end
        if (cycles > 1000) $fatal(1, "timeout");
    end

    task finish_checks;
        begin
            for (i = 1; i < 32; i = i + 1)
                if (dut.core.rf.rf[i] !== exp_regs[i])
                    $fatal(1, "x%0d = %h, esperado %h", i, dut.core.rf.rf[i], exp_regs[i]);
            for (i = 0; i < 256; i = i + 1)
                if (dut.dmem.RAM[i] !== exp_mem[i])
                    $fatal(1, "mem[%0d] = %h, esperado %h", i, dut.dmem.RAM[i], exp_mem[i]);
            if (retired != 24) $fatal(1, "retiradas = %0d, esperado 24", retired);
            if (branches != 6 || branch_miss != 3)
                $fatal(1, "branches = %0d (esperado 6), fallos = %0d (esperado 3)", branches, branch_miss);
            if (jal_seen != 1 || jal_miss != 0)
                $fatal(1, "jal = %0d (esperado 1), fallos = %0d (esperado 0)", jal_seen, jal_miss);
            if (jalr_seen != 1 || jalr_miss != 1)
                $fatal(1, "jalr = %0d (esperado 1), fallos = %0d (esperado 1)", jalr_seen, jalr_miss);
            // bne en PC 0x14 (indice 5): T T T T N desde 01 -> 10 11 11 11 10
            if (dut.core.bht[5] !== 2'b10)
                $fatal(1, "contador del bne = %b, esperado 10", dut.core.bht[5]);
            $display("PASS E3 predictor: %0d retiradas en %0d ciclos; branches=%0d fallos=%0d, jal sin fallo, jalr corregido en EX, contador del bne = 10",
                     retired, cycles, branches, branch_miss);
            $finish;
        end
    endtask
endmodule

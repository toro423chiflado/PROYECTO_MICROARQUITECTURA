`timescale 1ns/1ps
module testbench #(
    parameter PROGRAM = "test_e2p2.mem"
);
    reg clk;
    reg reset;
    wire [31:0] WriteData, DataAdr;
    wire MemWrite;
    integer dual_count, forward_count, stall_count, flush_count;

    // Instancia del módulo TOP
    top #(.PROGRAM(PROGRAM)) dut(
        .clk(clk), 
        .reset(reset), 
        .WriteData(WriteData), 
        .DataAdr(DataAdr), 
        .MemWrite(MemWrite)
    );

    // Generador de reloj (Periodo de 10ns)
    always #5 clk = ~clk;

    initial begin
        // Inicializar reloj y reset
        clk = 0;
        reset = 1;
        dual_count = 0;
        forward_count = 0;
        stall_count = 0;
        flush_count = 0;
        repeat (2) @(negedge clk); // Liberar reset fuera del flanco activo
        reset = 0; // Soltamos el reset, el procesador arranca
        
        // Corremos por 400ns y detenemos
        #400;
        if (dual_count == 0)
            $display("WARNING: no se observo una emision Dual-Issue");
        else
            $display("Dual-Issue observado %0d veces", dual_count);
        $display("Forwarding observado %0d veces", forward_count);
        $display("Stalling observado %0d veces", stall_count);
        $display("Flushing observado %0d veces", flush_count);
        $finish;
    end

    // Señales útiles para documentar Dual Fetch, Dual Decode y emisión.
    always @(posedge clk) begin
        if (!reset && dut.DualValidD0)
            $display("t=%0t PC=%h I0=%h I1=%h dual_issue=%b FwdA=%b FwdB=%b Stall=%b FlushD=%b FlushE=%b",
                     $time, dut.DualPCF1 - 32'd4, dut.DualInstrD0,
                     dut.DualInstrD1, dut.DualIssue,
                     dut.rvpipe.hu.ForwardAE, dut.rvpipe.hu.ForwardBE,
                     dut.rvpipe.hu.StallF, dut.rvpipe.hu.FlushD,
                     dut.rvpipe.hu.FlushE);
        if (!reset && dut.DualIssue)
            dual_count = dual_count + 1;
        if (!reset && ((dut.rvpipe.hu.ForwardAE != 2'b00) ||
                       (dut.rvpipe.hu.ForwardBE != 2'b00)))
            forward_count = forward_count + 1;
        if (!reset && dut.rvpipe.hu.StallF)
            stall_count = stall_count + 1;
        if (!reset && (dut.rvpipe.hu.FlushD || dut.rvpipe.hu.FlushE))
            flush_count = flush_count + 1;
    end
endmodule

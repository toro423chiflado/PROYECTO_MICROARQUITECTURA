# RV32I de 32 bits. Las instrucciones poison deben descartarse.
.option norvc
.text
.globl _start
_start:
    addi x1, x0, -2
    addi x2, x0, 3
    addi x3, x0, -2
    bne x1, x2, bne_taken
    addi x30, x0, 101
    sw x1, 0(x0)
bne_taken:
    bne x1, x3, bne_not_taken_done
    addi x4, x0, 11
    addi x5, x0, 12
bne_not_taken_done:
    blt x1, x2, blt_taken
    addi x30, x0, 102
    sw x1, 0(x0)
blt_taken:
    blt x2, x1, blt_not_taken_done
    addi x6, x0, 21
    addi x7, x0, 22
blt_not_taken_done:
    blt x1, x3, blt_equal_done
    addi x8, x0, 23
    addi x9, x0, 24
blt_equal_done:
    bge x1, x3, bge_equal_taken
    addi x30, x0, 103
    sw x1, 0(x0)
bge_equal_taken:
    bge x2, x1, bge_greater_taken
    addi x30, x0, 104
    sw x1, 0(x0)
bge_greater_taken:
    bge x1, x2, bge_not_taken_done
    addi x10, x0, 31
    addi x11, x0, 32
bge_not_taken_done:
    jal x12, jal_target
    addi x30, x0, 105
    sw x1, 0(x0)
jal_target:
    addi x13, x12, 0
    addi x14, x0, 136
    jalr x15, 5(x14)
    addi x30, x0, 106
    sw x1, 0(x0)
jalr_target:
    addi x16, x15, 0
    addi x17, x0, 1
    sw x17, 4(x0)

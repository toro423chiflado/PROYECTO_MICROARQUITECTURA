    .text
    .globl _start
_start:
    addi x1, x0, 5
    addi x2, x0, 7
    add  x3, x1, x2
    add  x4, x3, x1
    sw   x3, 0(x0)
    lw   x5, 0(x0)
    add  x6, x5, x2
    addi x7, x0, 9
    sw   x6, 4(x0)
    addi x8, x0, 11
    addi x9, x0, 13
    lw   x10, 4(x0)
    addi x11, x0, 1
    jal  x12, salto1
    sw   x0, 0(x0)
salto1:
    jal  x14, salto2
    sw   x0, 4(x0)
salto2:
    addi x13, x0, 3
    addi x15, x0, 4
    addi x16, x15, 1
    addi x17, x0, 6
    sw   x16, 8(x0)
    sw   x17, 12(x0)
    addi x18, x0, 1
    sw   x18, 16(x0)

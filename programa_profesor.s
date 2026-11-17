# programa_profesor.s - programa de prueba entregado por el profesor (sin cambios)
.text
.globl _start
_start:
etapa_A:
addi x1, x0, 1536
addi x2, x0, 1
addi x3, x0, 8
addi x4, x0, 3
add x5, x3, x4
sub x6, x3, x4
add x7, x5, x6
addi x8, x0, 2
add x9, x7, x8
addi x9, x0, 7
add x10, x9, x6
sw x5, 0(x1)
sw x6, 4(x1)
sw x10, 8(x1)
# ESTADO AL FINAL DE ETAPA A
# Registros no indicados = 0.
# x1=1536, x2=1, x3=8, x4=3, x5=11, x6=5, x7=16
# x8=2, x9=7, x10=12
# M[x1+0]=11, M[x1+4]=5, M[x1+8]=12
etapa_B:
lw x11, 0(x1)
add x12, x11, x6
lw x13, 4(x1)
lw x14, 8(x1)
sub x15, x14, x13
sw x15, 12(x1)
lw x16, 12(x1)
sw x12, 16(x1)
lw x17, 16(x1)
add x18, x16, x17
sw x18, 20(x1)
# ESTADO AL FINAL DE ETAPA B
# Registros no indicados = 0.
# x1=1536, x2=1, x3=8, x4=3, x5=11, x6=5, x7=16
# x8=2, x9=7, x10=12, x11=11, x12=16, x13=5, x14=12
# x15=7, x16=7, x17=16, x18=23
# M[x1+0]=11, M[x1+4]=5, M[x1+8]=12, M[x1+12]=7, M[x1+16]=16
# M[x1+20]=23
etapa_C:
addi x19, x0, 0
addi x20, x0, 12
addi x21, x0, 0
C1:
addi x19, x19, 1
addi x21, x21, 2
slt x25, x19, x20
beq x25, x2, C1
sw x21, 24(x1)
addi x19, x0, 0
addi x22, x0, 0
addi x23, x0, 0
C2:
sub x23, x2, x23
beq x23, x2, C2a
addi x22, x22, 2
jal x0, C2b
C2a:
addi x22, x22, 1
C2b:
addi x19, x19, 1
slt x25, x19, x20
beq x25, x2, C2
sw x22, 28(x1)
addi x19, x0, 0
addi x24, x0, 0
addi x26, x0, 6
C3:
slt x25, x19, x26
beq x25, x2, C3a
addi x24, x24, 1
jal x0, C3b
C3a:
addi x24, x24, 3
C3b:
addi x19, x19, 1
slt x25, x19, x20
beq x25, x2, C3
sw x24, 32(x1)
# ESTADO AL FINAL DE ETAPA C
# Registros no indicados = 0.
# x1=1536, x2=1, x3=8, x4=3, x5=11, x6=5, x7=16
# x8=2, x9=7, x10=12, x11=11, x12=16, x13=5, x14=12
# x15=7, x16=7, x17=16, x18=23, x19=12, x20=12, x21=24
# x22=18, x24=24, x26=6
# M[x1+0]=11, M[x1+4]=5, M[x1+8]=12, M[x1+12]=7, M[x1+16]=16
# M[x1+20]=23, M[x1+24]=24, M[x1+28]=18, M[x1+32]=24
etapa_D:
addi x19, x0, 0
addi x20, x0, 6
add x27, x1, x0
addi x28, x0, 0
addi x29, x0, 0
sw x0, 44(x1)
D1:
lw x30, 0(x27)
add x28, x28, x30
slt x25, x30, x5
beq x25, x2, D2
addi x29, x29, 1
D2:
addi x27, x27, 4
addi x19, x19, 1
slt x25, x19, x20
beq x25, x2, D1
sw x28, 36(x1)
sw x29, 40(x1)
addi x31, x0, 0
beq x28, x0, D3
beq x29, x0, D3
beq x2, x2, D4
D3:
addi x31, x0, 99
sw x31, 44(x1)
D4:
addi x31, x0, 1
sw x31, 48(x1)
beq x2, x2, D5
sw x31, 44(x1)
D5:
lw x25, 40(x1)
addi x26, x0, 4
beq x25, x26, D6
addi x31, x0, 0
D6:
sw x31, 52(x1)
# ESTADO AL FINAL DE ETAPA D
# Registros no indicados = 0.
# x1=1536, x2=1, x3=8, x4=3, x5=11, x6=5, x7=16
# x8=2, x9=7, x10=12, x11=11, x12=16, x13=5, x14=12
# x15=7, x16=7, x17=16, x18=23, x19=6, x20=6, x21=24
# x22=18, x24=24, x25=4, x26=4, x27=1560, x28=74, x29=4
# x30=23, x31=1
# M[x1+0]=11, M[x1+4]=5, M[x1+8]=12, M[x1+12]=7, M[x1+16]=16
# M[x1+20]=23, M[x1+24]=24, M[x1+28]=18, M[x1+32]=24, M[x1+36]=74
# M[x1+40]=4, M[x1+44]=0, M[x1+48]=1, M[x1+52]=1
fin:
jal x0, fin

# =============================================================================
# benchmark_propio.s - Programa de evaluacion del grupo (Proyecto 2)
#
# Corre sin cambios en las configuraciones A, B y C. Tiene tres partes con
# comportamientos distintos, para analizar el paralelismo y los saltos:
#
#   1. Estadisticas de un arreglo (suma, maximo, negativos): loop con un load
#      por iteracion y saltos que dependen de los datos (dificiles de predecir).
#   2. Suma de vectores C = A + B desenrollada x2: mucho paralelismo (ILP) e
#      instrucciones de memoria mezcladas con ALU.
#   3. Bubble sort de C: loops anidados, pares load/store, dependencias
#      load-use y un salto de intercambio que depende de los datos.
#
# Termina con halt (jal x0, 0). Resultados en "res":
#   res[0] suma de A        res[1] maximo de A      res[2] negativos de A
#   res[3] checksum xor C   res[4] checksum suma C  res[5] minimo de C ordenado
#   res[6] maximo de C ordenado                     res[7] pasadas del sort
# =============================================================================
        .data
arr:    .word 23, -7, 41, 0, -15, 8, 36, -2, 19, -30, 5, 12, -11, 27, 3, -9
n:      .word 16
vecb:   .word 3, 1, -2, 5, 4, -1, 2, 6, -3, 7, 1, 0, 2, -4, 5, 1
vecc:   .space 64
res:    .space 32

        .text
        la   s0, arr            # s0 = &A[0]
        la   t0, n
        lw   s1, 0(t0)          # s1 = n
        la   s2, vecb           # s2 = &B[0]
        la   s3, vecc           # s3 = &C[0]
        la   s4, res            # s4 = &res[0]

# ---------------------------------------------------------------- Parte 1
        li   a0, 0              # suma
        lw   a1, 0(s0)          # maximo = A[0]
        li   a2, 0              # cantidad de negativos
        li   t1, 0              # i
        mv   t2, s0             # puntero a A
stats:  lw   t3, 0(t2)          # A[i]
        addi t1, t1, 1
        addi t2, t2, 4
        add  a0, a0, t3
        bge  t3, zero, no_neg   # salto dependiente del dato
        addi a2, a2, 1
no_neg: bge  a1, t3, no_max
        mv   a1, t3
no_max: blt  t1, s1, stats
        sw   a0, 0(s4)
        sw   a1, 4(s4)
        sw   a2, 8(s4)

# ---------------------------------------------------------------- Parte 2
        li   a3, 0              # checksum xor
        li   a4, 0              # checksum suma
        li   t1, 0              # i
        mv   t2, s0             # puntero a A
        mv   t4, s2             # puntero a B
        mv   s6, s3             # puntero a C
vadd:   lw   t3, 0(t2)          # A[i]
        lw   t5, 0(t4)          # B[i]
        lw   t6, 4(t2)          # A[i+1]
        lw   s5, 4(t4)          # B[i+1]
        add  t3, t3, t5         # C[i]
        add  t6, t6, s5         # C[i+1]
        sw   t3, 0(s6)
        sw   t6, 4(s6)
        xor  a3, a3, t3
        add  a4, a4, t6
        addi t2, t2, 8
        addi t4, t4, 8
        addi s6, s6, 8
        addi t1, t1, 2
        blt  t1, s1, vadd
        sw   a3, 12(s4)
        sw   a4, 16(s4)

# ---------------------------------------------------------------- Parte 3
        addi s7, s1, -1         # limite de la pasada
        li   s9, 0              # pasadas realizadas
outer:  li   t1, 0              # j
        mv   t2, s3             # p = &C[0]
        li   s8, 0              # hubo intercambio
        addi s9, s9, 1
inner:  lw   t3, 0(t2)          # C[j]
        lw   t5, 4(t2)          # C[j+1]
        bge  t5, t3, noswap     # load-use: depende de los dos loads
        sw   t5, 0(t2)
        sw   t3, 4(t2)
        li   s8, 1
noswap: addi t2, t2, 4
        addi t1, t1, 1
        blt  t1, s7, inner
        addi s7, s7, -1
        beqz s8, sorted         # sin intercambios: ya esta ordenado
        blt  zero, s7, outer
sorted: lw   t3, 0(s3)          # minimo
        slli t0, s1, 2
        add  t0, t0, s3
        lw   t5, -4(t0)         # maximo
        sw   t3, 20(s4)
        sw   t5, 24(s4)
        sw   s9, 28(s4)
        halt

# e3_demo_pred.s - demostracion del predictor de 2 bits (configuracion C)
# Contadores iniciales en 01 (debilmente no tomado).
        addi x1, x0, 0
        addi x2, x0, 5
        addi x5, x0, 0
loop:   addi x1, x1, 1          # i = i + 1
        add  x5, x5, x1         # suma = suma + i
        bne  x1, x2, loop       # cierre de loop: T T T T N
                                #   1ra vez: contador 01 -> predice no tomado: FALLO
                                #   2da a 4ta: predice tomado: acierto
                                #   salida: predice tomado y no se toma: FALLO
        jal  x6, sub            # jal: se predice tomado en Fetch, sin penalidad
        addi x8, x0, 8
        beq  x0, x0, fin        # siempre tomado, pero se ejecuta una vez: FALLO
        addi x9, x0, 99         # camino incorrecto: x9 debe quedar en 0
sub:    addi x7, x0, 7
        jalr x0, 0(x6)          # jalr: no se predice, se corrige en EX: FALLO
fin:    sw   x5, 0(x0)          # mem[0] = 15
        halt

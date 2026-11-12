# Demostracion de branches en ambas posiciones del par
        addi x1, x0, 1
        addi x2, x0, 1
        beq  x1, x2, t1     # slot 0, tomado: se anula la instruccion del slot 1
        addi x3, x0, 9      # camino incorrecto (via 1): x3 debe quedar en 0
t1:     addi x4, x0, 4
        bne  x1, x2, bad    # slot 1, no tomado
        addi x5, x0, 5
        beq  x1, x2, t2     # slot 1, tomado: la via 0 (x5) se conserva
        addi x6, x0, 6      # camino incorrecto
bad:    addi x7, x0, 7      # camino incorrecto
t2:     addi x8, x0, 8
        halt

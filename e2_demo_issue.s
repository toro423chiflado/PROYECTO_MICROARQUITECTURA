# Demostracion de la Issue Unit, el forwarding entre vias y la memoria compartida
        addi x1, x0, 5      # (1) par independiente: salen las dos
        addi x2, x0, 7
        add  x3, x1, x2     # (2) RAW dentro del par: sale solo add x3
        add  x4, x3, x1     # (3) sale con la siguiente; x3 llega por forwarding
        addi x11, x0, 11
        sw   x3, 0(x0)      # (4) MEM + MEM: un solo puerto, sale solo el sw
        lw   x5, 0(x0)      # (5) MEM + ALU independientes: salen juntas
        addi x7, x0, 1
        add  x6, x5, x4     # (6) load-use con lw x5: stall de un ciclo
        addi x9, x0, 2
        addi x10, x0, 3     # (7) ALU + MEM: salen juntas (x9 por forwarding)
        sw   x9, 4(x0)
        halt

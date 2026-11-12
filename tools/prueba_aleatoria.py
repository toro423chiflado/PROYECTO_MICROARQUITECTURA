#!/usr/bin/env python3
"""
prueba_aleatoria.py - Verificacion con programas aleatorios (A vs B vs modelo de referencia)

    python3 tools/prueba_aleatoria.py            # 100 programas, semillas 0..99
    python3 tools/prueba_aleatoria.py 200 1000   # 200 programas desde la semilla 1000

Cada programa mezcla operaciones ALU, lui/auipc, loads y stores, branches hacia
adelante, jal, jalr y loops cortos, con pocos registros para forzar muchas
dependencias. Se ensambla con tools/rvasm.py (que calcula el resultado esperado)
y se simula con testbench_comparacion.v, que hace dos comprobaciones:
  1. A y B coinciden entre si en el numero de instrucciones retiradas, los 31
     registros y las 256 palabras de memoria;
  2. el estado final (31 registros y 256 palabras) coincide con el del modelo
     de referencia.
Requiere Icarus Verilog.
"""
import glob, os, random, re, subprocess, sys, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
R = ["x1", "x2", "x3", "x4", "x5", "x6", "x7", "x8", "x10", "x11", "x12"]
S = R + ["x0"]
ROP = ["add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra", "or", "and"]
IOP = ["addi", "slti", "sltiu", "xori", "ori", "andi"]
SH = ["slli", "srli", "srai"]
BR = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]

def alu(r):
    k = r.random()
    if k < 0.45: return f"{r.choice(ROP)} {r.choice(R)}, {r.choice(S)}, {r.choice(S)}"
    if k < 0.75: return f"{r.choice(IOP)} {r.choice(R)}, {r.choice(S)}, {r.randint(-2048, 2047)}"
    if k < 0.88: return f"{r.choice(SH)} {r.choice(R)}, {r.choice(S)}, {r.randint(0, 31)}"
    if k < 0.95: return f"lui {r.choice(R)}, {r.randint(0, 0xfffff)}"
    return f"auipc {r.choice(R)}, {r.randint(0, 0xfffff)}"

def mem(r):
    if r.random() < 0.5: return f"lw {r.choice(R)}, {4 * r.randint(-16, 47)}(x9)"
    return f"sw {r.choice(S)}, {4 * r.randint(-16, 47)}(x9)"

def programa(seed, n=48):
    r = random.Random(seed); lab = 0; body = []
    data = [r.randint(-50, 50) for _ in range(64)]
    while len(body) < n:
        k = r.random()
        if k < 0.50: body.append(alu(r))
        elif k < 0.72: body.append(mem(r))
        elif k < 0.84:                                   # branch hacia adelante
            L = f"L{lab}"; lab += 1
            body.append(f"{r.choice(BR)} {r.choice(S)}, {r.choice(S)}, {L}")
            for _ in range(r.randint(0, 3)): body.append(alu(r) if r.random() < 0.7 else mem(r))
            body.append(f"{L}:")
        elif k < 0.89:                                   # jal
            L = f"L{lab}"; lab += 1
            body += [f"jal {r.choice(S)}, {L}", alu(r), f"{L}:"]
        elif k < 0.93:                                   # jalr
            body += ["auipc x14, 0", f"jalr {r.choice(S)}, 12(x14)", alu(r)]
        else:                                            # loop corto
            L = f"L{lab}"; lab += 1
            body += [f"li x13, {r.randint(1, 4)}", f"{L}:"]
            for _ in range(r.randint(1, 4)): body.append(alu(r) if r.random() < 0.6 else mem(r))
            body += ["addi x13, x13, -1", f"bnez x13, {L}"]
    return (".data\n.word " + ", ".join(map(str, data)) + "\n.text\nli x9, 64\n"
            + "\n".join(body) + "\nhalt\n")

def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100
    s0 = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    rtl = [f for f in glob.glob(os.path.join(ROOT, "*.v")) if not os.path.basename(f).startswith(("testbench", "test_"))]
    tb = os.path.join(ROOT, "testbench_comparacion.v")
    fallas = 0
    with tempfile.TemporaryDirectory() as d:
        for seed in range(s0, s0 + n):
            src = os.path.join(d, f"r{seed}.s")
            open(src, "w").write(programa(seed))
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "rvasm.py"), src, "-o", d],
                           check=True, capture_output=True)
            b = os.path.join(d, f"r{seed}")
            exe = b + ".vvp"
            p = lambda k, v: ["-P", f'testbench_comparacion.{k}="{v}"']
            subprocess.run(["iverilog", "-g2012", "-o", exe, "-s", "testbench_comparacion",
                            *p("PROGRAM", b + ".mem"), *p("DATA", b + ".data.mem"),
                            *p("EXP_REGS", b + ".exp_regs"), *p("EXP_MEM", b + ".exp_mem"),
                            *rtl, tb], check=True, capture_output=True)
            out = subprocess.run(["vvp", "-n", exe], capture_output=True, text=True).stdout
            if "RESULT PASS" not in out:
                fallas += 1
                print(f"FALLA semilla {seed}:\n{out}")
    print(f"{n - fallas}/{n} programas aleatorios PASS (A == B == modelo de referencia)")
    sys.exit(1 if fallas else 0)

if __name__ == "__main__":
    main()

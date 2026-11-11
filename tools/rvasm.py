#!/usr/bin/env python3
"""
rvasm.py - Ensamblador mínimo RV32I + modelo de referencia (ISS) para el Proyecto 2.

Uso (desde la raiz del proyecto):
    python3 tools/rvasm.py benchmark_propio.s -o .      # genera benchmark_propio.*

Genera en el directorio de salida:
    <nombre>.mem       instrucciones (hex, una por línea, con comentario)  -> IMem
    <nombre>.data.mem  memoria de datos inicial (256 palabras)            -> DMem
    <nombre>.exp_regs  valores esperados de x0..x31 al terminar           -> testbench
    <nombre>.exp_mem   contenido esperado de DMem al terminar             -> testbench
    <nombre>.json      estadísticas del ISS (instrucciones ejecutadas)

Convenciones:
    - Instrucciones en IMem desde la dirección 0. Datos en DMem desde la dirección 0.
    - El programa TERMINA con la instrucción de parada `halt` (= jal x0, 0, 0x0000006f).
      El ISS se detiene ahí y el testbench también; la instrucción halt NO se cuenta
      como instrucción retirada.

Instrucciones soportadas (mismo subconjunto que el procesador):
    R: add sub sll slt sltu xor srl sra or and
    I: addi slti sltiu xori ori andi slli srli srai  lw  jalr
    S: sw     B: beq bne blt bge bltu bgeu     U: lui auipc     J: jal
    Pseudo: nop li mv j jr ret call la beqz bnez bgt ble halt
Directivas: .text .data .word .space
"""
import argparse
import json
import os
import re
import sys

MEM_WORDS = 256          # tamaño de IMem y DMem en palabras (debe coincidir con el RTL)
HALT = 0x0000006F        # jal x0, 0

ABI = {
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9, "a0": 10, "a1": 11, "a2": 12, "a3": 13, "a4": 14,
    "a5": 15, "a6": 16, "a7": 17, "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22,
    "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27, "t3": 28, "t4": 29,
    "t5": 30, "t6": 31,
}

R_OPS = {  # nombre: (funct7, funct3)
    "add": (0x00, 0), "sub": (0x20, 0), "sll": (0x00, 1), "slt": (0x00, 2),
    "sltu": (0x00, 3), "xor": (0x00, 4), "srl": (0x00, 5), "sra": (0x20, 5),
    "or": (0x00, 6), "and": (0x00, 7),
}
I_ALU = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SHIFT_I = {"slli": (0x00, 1), "srli": (0x00, 5), "srai": (0x20, 5)}
BRANCH = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


class AsmError(Exception):
    pass


def reg(tok):
    tok = tok.strip().lower()
    if tok in ABI:
        return ABI[tok]
    m = re.fullmatch(r"x(\d+)", tok)
    if m and 0 <= int(m.group(1)) < 32:
        return int(m.group(1))
    raise AsmError(f"registro inválido: {tok}")


def num(tok):
    return int(tok.strip(), 0)


def fits(v, bits):
    return -(1 << (bits - 1)) <= v < (1 << (bits - 1))


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    if not fits(imm, 12):
        raise AsmError(f"inmediato fuera de rango (12 bits): {imm}")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    if not fits(imm, 12):
        raise AsmError(f"offset fuera de rango (12 bits): {imm}")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(off, rs2, rs1, f3):
    if off % 2 or not fits(off, 13):
        raise AsmError(f"offset de branch inválido: {off}")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | 0x63


def enc_u(imm20, rd, op):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | op


def enc_j(off, rd):
    if off % 2 or not fits(off, 21):
        raise AsmError(f"offset de jal inválido: {off}")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
           (((o >> 12) & 0xFF) << 12) | (rd << 7) | 0x6F


def hi_lo(v):
    """Separa una constante de 32 bits en (hi20, lo12) para lui+addi."""
    v &= 0xFFFFFFFF
    lo = v & 0xFFF
    if lo >= 0x800:
        lo -= 0x1000
    hi = ((v - lo) >> 12) & 0xFFFFF
    return hi, lo


def split_args(s):
    return [a.strip() for a in s.split(",")] if s.strip() else []


def mem_operand(tok):
    m = re.fullmatch(r"\s*(-?(?:0x[0-9a-fA-F]+|\d+))?\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"operando de memoria inválido: {tok}")
    return (num(m.group(1)) if m.group(1) else 0), reg(m.group(2))


def size_of(mn, args):
    """Número de instrucciones reales que ocupa cada línea (para la 1ra pasada)."""
    if mn == "la":
        return 2
    if mn == "li":
        v = num(args[1])
        return 1 if fits(v, 12) else 2
    return 1


def parse(path):
    text_items, data_words, labels = [], [], {}
    section = "text"
    pc = 0
    with open(path) as f:
        for lineno, raw in enumerate(f, 1):
            line = raw.split("#")[0].strip()
            while True:
                m = re.match(r"^([A-Za-z_.][\w.]*)\s*:(.*)$", line)
                if not m:
                    break
                name = m.group(1)
                if name in labels:
                    raise AsmError(f"{path}:{lineno}: etiqueta repetida {name}")
                labels[name] = pc if section == "text" else 4 * len(data_words)
                line = m.group(2).strip()
            if not line:
                continue
            parts = line.split(None, 1)
            mn = parts[0].lower()
            args = split_args(parts[1]) if len(parts) > 1 else []
            if mn == ".text":
                section = "text"
                continue
            if mn == ".data":
                section = "data"
                continue
            if section == "data":
                if mn == ".word":
                    data_words += [num(a) & 0xFFFFFFFF for a in args]
                elif mn == ".space":
                    data_words += [0] * ((num(args[0]) + 3) // 4)
                else:
                    raise AsmError(f"{path}:{lineno}: directiva de datos no soportada {mn}")
                continue
            try:
                n = size_of(mn, args)
            except (ValueError, IndexError) as e:
                raise AsmError(f"{path}:{lineno}: {line} ({e})")
            text_items.append((pc, mn, args, lineno, line))
            pc += 4 * n
    return text_items, data_words, labels


def assemble(path):
    items, data_words, labels = parse(path)

    def target(tok):
        tok = tok.strip()
        if tok in labels:
            return labels[tok]
        return num(tok)

    out = []  # (addr, word, texto)
    for pc, mn, a, lineno, src in items:
        try:
            words = []
            if mn in R_OPS:
                f7, f3 = R_OPS[mn]
                words = [enc_r(f7, reg(a[2]), reg(a[1]), f3, reg(a[0]), 0x33)]
            elif mn in I_ALU:
                words = [enc_i(num(a[2]), reg(a[1]), I_ALU[mn], reg(a[0]), 0x13)]
            elif mn in SHIFT_I:
                f7, f3 = SHIFT_I[mn]
                sh = num(a[2])
                if not 0 <= sh < 32:
                    raise AsmError("shamt fuera de rango")
                words = [enc_r(f7, sh, reg(a[1]), f3, reg(a[0]), 0x13)]
            elif mn == "lw":
                off, rs1 = mem_operand(a[1])
                words = [enc_i(off, rs1, 2, reg(a[0]), 0x03)]
            elif mn == "sw":
                off, rs1 = mem_operand(a[1])
                words = [enc_s(off, reg(a[0]), rs1, 2, 0x23)]
            elif mn in BRANCH:
                words = [enc_b(target(a[2]) - pc, reg(a[1]), reg(a[0]), BRANCH[mn])]
            elif mn in ("bgt", "ble"):           # bgt a,b = blt b,a ; ble a,b = bge b,a
                f3 = 4 if mn == "bgt" else 5
                words = [enc_b(target(a[2]) - pc, reg(a[0]), reg(a[1]), f3)]
            elif mn in ("beqz", "bnez"):
                words = [enc_b(target(a[1]) - pc, 0, reg(a[0]), 0 if mn == "beqz" else 1)]
            elif mn == "lui":
                words = [enc_u(num(a[1]), reg(a[0]), 0x37)]
            elif mn == "auipc":
                words = [enc_u(num(a[1]), reg(a[0]), 0x17)]
            elif mn == "jal":
                if len(a) == 1:
                    words = [enc_j(target(a[0]) - pc, 1)]
                else:
                    words = [enc_j(target(a[1]) - pc, reg(a[0]))]
            elif mn == "jalr":
                if len(a) == 1:
                    words = [enc_i(0, reg(a[0]), 0, 1, 0x67)]
                elif "(" in a[1]:
                    off, rs1 = mem_operand(a[1])
                    words = [enc_i(off, rs1, 0, reg(a[0]), 0x67)]
                else:
                    words = [enc_i(num(a[2]) if len(a) > 2 else 0, reg(a[1]), 0, reg(a[0]), 0x67)]
            elif mn == "nop":
                words = [0x00000013]
            elif mn == "halt":
                words = [HALT]
            elif mn == "mv":
                words = [enc_i(0, reg(a[1]), 0, reg(a[0]), 0x13)]
            elif mn == "li":
                v = num(a[1])
                if fits(v, 12):
                    words = [enc_i(v, 0, 0, reg(a[0]), 0x13)]
                else:
                    hi, lo = hi_lo(v)
                    rd = reg(a[0])
                    words = [enc_u(hi, rd, 0x37), enc_i(lo, rd, 0, rd, 0x13)]
            elif mn == "la":
                hi, lo = hi_lo(target(a[1]))
                rd = reg(a[0])
                words = [enc_u(hi, rd, 0x37), enc_i(lo, rd, 0, rd, 0x13)]
            elif mn == "j":
                words = [enc_j(target(a[0]) - pc, 0)]
            elif mn == "call":
                words = [enc_j(target(a[0]) - pc, 1)]
            elif mn == "jr":
                words = [enc_i(0, reg(a[0]), 0, 0, 0x67)]
            elif mn == "ret":
                words = [enc_i(0, 1, 0, 0, 0x67)]
            else:
                raise AsmError(f"instrucción no soportada: {mn}")
        except (AsmError, ValueError, IndexError) as e:
            raise AsmError(f"{path}:{lineno}: '{src}': {e}")
        for k, w in enumerate(words):
            out.append((pc + 4 * k, w & 0xFFFFFFFF, src if k == 0 else f"  (cont. {src})"))
    if len(out) > MEM_WORDS:
        raise AsmError("el programa no entra en IMem")
    if len(data_words) > MEM_WORDS:
        raise AsmError("los datos no entran en DMem")
    return out, data_words


# ---------------------------------------------------------------- ISS (modelo de referencia)
def sx(v, bits):
    v &= (1 << bits) - 1
    return v - (1 << bits) if v >> (bits - 1) else v


def s32(v):
    return sx(v, 32)


def run_iss(code, data_words, max_steps=2_000_000):
    imem = {a: w for a, w, _ in code}
    dmem = data_words + [0] * (MEM_WORDS - len(data_words))
    x = [0] * 32
    pc, steps, taken, loads, stores, branches = 0, 0, 0, 0, 0, 0
    while True:
        if pc % 4 or pc // 4 >= MEM_WORDS:
            raise RuntimeError(f"PC fuera de IMem: {pc:#x}")
        ins = imem.get(pc, 0)
        if ins == HALT:
            break
        if steps >= max_steps:
            raise RuntimeError("demasiadas instrucciones (¿loop infinito?)")
        op, rd, f3 = ins & 0x7F, (ins >> 7) & 31, (ins >> 12) & 7
        rs1, rs2, f7 = (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = x[rs1], x[rs2]
        imm_i = sx(ins >> 20, 12)
        nxt, res = pc + 4, None
        if op == 0x33:
            res = {0: (a - b) if f7 == 0x20 else (a + b), 1: a << (b & 31),
                   2: int(s32(a) < s32(b)), 3: int(a < b), 4: a ^ b,
                   5: (s32(a) >> (b & 31)) if f7 == 0x20 else (a >> (b & 31)),
                   6: a | b, 7: a & b}[f3]
        elif op == 0x13:
            sh = imm_i & 31
            res = {0: a + imm_i, 1: a << sh, 2: int(s32(a) < imm_i), 3: int(a < (imm_i & 0xFFFFFFFF)),
                   4: a ^ (imm_i & 0xFFFFFFFF), 5: (s32(a) >> sh) if f7 == 0x20 else (a >> sh),
                   6: a | (imm_i & 0xFFFFFFFF), 7: a & (imm_i & 0xFFFFFFFF)}[f3]
        elif op == 0x03:
            addr = (a + imm_i) & 0xFFFFFFFF
            res = dmem[(addr >> 2) % MEM_WORDS]
            loads += 1
        elif op == 0x23:
            imm_s = sx(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
            addr = (a + imm_s) & 0xFFFFFFFF
            dmem[(addr >> 2) % MEM_WORDS] = b
            stores += 1
        elif op == 0x63:
            imm_b = sx((((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) |
                       (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1), 13)
            cond = {0: a == b, 1: a != b, 4: s32(a) < s32(b), 5: s32(a) >= s32(b),
                    6: a < b, 7: a >= b}[f3]
            branches += 1
            if cond:
                nxt = pc + imm_b
                taken += 1
        elif op == 0x37:
            res = ins & 0xFFFFF000
        elif op == 0x17:
            res = pc + (ins & 0xFFFFF000)
        elif op == 0x6F:
            imm_j = sx((((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12) |
                       (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1), 21)
            res, nxt = pc + 4, pc + imm_j
            taken += 1
        elif op == 0x67:
            res, nxt = pc + 4, (a + imm_i) & 0xFFFFFFFE
            taken += 1
        else:
            raise RuntimeError(f"instrucción no soportada en {pc:#x}: {ins:08x}")
        if res is not None and rd != 0:
            x[rd] = res & 0xFFFFFFFF
        pc = nxt & 0xFFFFFFFF
        steps += 1
    stats = {"instructions": steps, "taken_control": taken, "loads": loads,
             "stores": stores, "branches": branches, "halt_pc": pc}
    return x, dmem, stats


def write_hex(path, words, comments=None):
    with open(path, "w") as f:
        for i, w in enumerate(words):
            c = f" // {comments[i]}" if comments and comments[i] else ""
            f.write(f"{w & 0xFFFFFFFF:08x}{c}\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source")
    ap.add_argument("-o", "--outdir", default="build")
    args = ap.parse_args()
    name = os.path.splitext(os.path.basename(args.source))[0]
    os.makedirs(args.outdir, exist_ok=True)
    try:
        code, data_words = assemble(args.source)
        regs, dmem, stats = run_iss(code, data_words)
    except (AsmError, RuntimeError) as e:
        sys.exit(f"ERROR: {e}")

    base = os.path.join(args.outdir, name)
    write_hex(base + ".mem", [w for _, w, _ in code], [f"0x{a:03x}: {s}" for a, _, s in code])
    write_hex(base + ".data.mem", data_words + [0] * (MEM_WORDS - len(data_words)))
    write_hex(base + ".exp_regs", regs)
    write_hex(base + ".exp_mem", dmem)
    stats.update({"program": name, "static_instructions": len(code)})
    with open(base + ".json", "w") as f:
        json.dump(stats, f, indent=2)
    print(f"{name}: {len(code)} instrucciones estáticas, {stats['instructions']} ejecutadas (ISS)")


if __name__ == "__main__":
    main()

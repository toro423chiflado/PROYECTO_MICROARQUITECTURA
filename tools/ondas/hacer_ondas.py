#!/usr/bin/env python3
"""
hacer_ondas.py - Regenera las capturas de GTKWave de las Partes II y III del informe.

    python3 tools/ondas/hacer_ondas.py            # desde la raiz del repositorio

Requiere Icarus Verilog, GTKWave, Xvfb, ImageMagick (import) y Pillow. Las imagenes quedan
en tools/ondas/salida/ (sin anotar: <nombre>.png; anotadas: <nombre>_a.png).

Las senales de instruccion se muestran como texto con un filtro de traduccion de GTKWave:
en Decode y EX el valor de la senal es el PC de la instruccion (o FFFFFFFF si la posicion
esta vacia) y se traduce a "PC: instruccion"; en MEM es la codificacion de la instruccion.
Los recuadros numerados se dibujan sobre la captura a partir del tiempo y de la fila.
"""
import os, re, sys, time, shutil, subprocess, collections, tempfile
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
AQUI = os.path.join(ROOT, "tools", "ondas")
OUT = os.path.join(AQUI, "salida")
TMP = tempfile.mkdtemp(prefix="ondas_")
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
COL = ["#FFD400", "#FF4FD8", "#3FD0FF", "#FF8A00", "#B6FF3B", "#FF5050"]

# ------------------------------------------------------------------ filtros de texto
def escribir_filtro(nombre, mapa):
    path = os.path.join(TMP, nombre + ".filter")
    with open(path, "w") as f:
        for v, t in mapa.items():
            for h in {f"{v:08X}", f"{v:08x}", f"{v:X}", f"{v:x}"}:
                f.write(f"{h} {t}\n")
    return path

def filtros(prog):
    """Devuelve (filtro por PC, filtro por codificacion) para un programa ensamblado."""
    pcs = {0xFFFFFFFF: "-"}; enc = collections.OrderedDict(); enc[0] = ["-"]; halt = 0
    for l in open(os.path.join(ROOT, prog + ".mem")):
        r = re.match(r"([0-9a-f]{8}) // 0x([0-9a-f]+): (.*)", l)
        if not r: continue
        txt = re.sub(r"\s+", " ", r.group(3).strip()); pc = int(r.group(2), 16); halt = max(halt, pc)
        pcs[pc] = f"{pc:x}: {txt}"; enc.setdefault(int(r.group(1), 16), []).append(txt)
    for pc in range(halt + 4, halt + 4 + 256, 4):
        pcs.setdefault(pc, "(tras halt)")
    def unir(ts):   # instrucciones con la misma codificacion (mismo desplazamiento)
        if len(set(ts)) == 1: return ts[0]
        return ts[0].rsplit(",", 1)[0] + ", " + "/".join(t.rsplit(",", 1)[1].strip() for t in ts)
    return (escribir_filtro("pcs_" + prog, pcs),
            escribir_filtro("enc_" + prog, {k: unir(v) for k, v in enc.items()}))

# ------------------------------------------------------------------ simulacion
RTL = ["e2_top.v", "e2_pipeline.v", "e3_top.v", "e3_pipeline.v", "imem.v", "dmem.v", "regfile.v",
       "top.v", "riscv_pipeline.v", "datapath.v", "controller.v", "hazard.v", "alu.v", "extend.v",
       "adder.v", "mux2.v", "mux3.v", "flopr.v", "decompressor.v", "dual_issue_frontend.v",
       "dual_issue_datapath.v"]

W2 = """  wire [31:0] PCF=dut.PCF, PCD0=dut.core.dp[0];
  wire [31:0] InstrD0 = dut.core.dv[0] ? dut.core.dp[0] : 32'hFFFFFFFF;
  wire [31:0] InstrD1 = dut.core.dv[1] ? dut.core.dp[1] : 32'hFFFFFFFF;
  wire ValidD0=dut.core.dv[0], ValidD1=dut.core.dv[1], pair_ok=dut.core.pair_ok;
  wire load_stall0=dut.core.load_stall0, load_stall1=dut.core.load_stall1;
  wire Issue0=dut.Issue0, Issue1=dut.Issue1;
  wire [31:0] InstrE0 = dut.core.ev[0] ? dut.core.ep[0] : 32'hFFFFFFFF;
  wire [31:0] InstrE1 = dut.core.ev[1] ? dut.core.ep[1] : 32'hFFFFFFFF;
  wire [31:0] SrcAE0=dut.core.xa[0], SrcBE0=dut.core.xb[0], SrcAE1=dut.core.xa[1], SrcBE1=dut.core.xb[1];
  wire [31:0] ALUResultE0=dut.core.xr[0], ALUResultE1=dut.core.xr[1];
  wire control_lane0=dut.core.control_lane0, ctaken=dut.core.ctaken, RedirectE=dut.RedirectE;
  wire [31:0] RedirectTargetE=dut.RedirectTargetE;
  wire [31:0] InstrM0 = dut.core.mv[0] ? dut.core.mi[0] : 32'd0;
  wire [31:0] InstrM1 = dut.core.mv[1] ? dut.core.mi[1] : 32'd0;
  wire [31:0] ResultM0=dut.core.mr[0], ResultM1=dut.core.mr[1];
  wire memlane=dut.core.memlane, MemWriteM=dut.MemWrite;
  wire [31:0] DataAdrM=dut.DataAdr, WriteDataM=dut.WriteData, ReadDataM=dut.core.ReadDataM;
  wire WriteW0=dut.core.rf.we3, WriteW1=dut.core.rf.we6;
  wire [4:0] RdW0=dut.core.wi[0][11:7], RdW1=dut.core.wi[1][11:7];
  wire [31:0] ResultW0=dut.core.wr[0], ResultW1=dut.core.wr[1];
  wire [1:0] RetireCnt=dut.RetireCnt;
  integer ciclo = 0;
  always @(posedge clk) if (!reset) ciclo = ciclo + 1;"""

def sim_e2(nombre, prog, tend, data=False):
    init = f'$readmemh("{prog}.data.mem", dut.dmem.RAM);' if data else ""
    tb = f"""`timescale 1ns/1ps
module tbw;
  reg clk=0, reset=1; always #5 clk=~clk;
  e2_top #(.PROGRAM("{prog}.mem")) dut(.clk(clk),.reset(reset));
{W2}
  integer i;
  initial begin
    $dumpfile("{os.path.join(TMP, nombre)}.vcd"); $dumpvars(0, tbw);
    #1; for(i=0;i<32;i=i+1) dut.core.rf.rf[i]=0; {init}
    #21 reset=0;
    #{tend} $finish;
  end
endmodule
"""
    f = os.path.join(TMP, f"tb_{nombre}.v"); open(f, "w").write(tb)
    exe = os.path.join(TMP, nombre + ".vvp")
    subprocess.run(["iverilog", "-g2012", "-s", "tbw", "-o", exe, f] + RTL, cwd=ROOT, check=True)
    subprocess.run(["vvp", "-n", exe], cwd=ROOT, check=True, capture_output=True)

# ------------------------------------------------------------------ captura
def captura(nombre, vcd, signals, t0, t1, fmt=None, filt=None, width=1700):
    fmt = fmt or {}; filt = filt or {}
    widths = {}
    for line in open(vcd):
        m = re.match(r"\$var \w+ (\d+) \S+ (\w+)", line)
        if m: widths[m.group(2)] = int(m.group(1))
        if line.startswith("$enddefinitions"): break
    full = lambda s: s + (f"[{widths[s]-1}:0]" if widths.get(s, 1) > 1 else "")
    height = 150 + 30 * len(signals)
    rc = os.path.join(TMP, nombre + ".rc")
    open(rc, "w").write(f"initial_window_x {width}\ninitial_window_y {height}\ninitial_window_xpos 0\n"
                        "initial_window_ypos 0\nsignal_fontname Monospace 13\nwave_fontname Monospace 12\n"
                        "enable_vert_grid yes\nuse_big_fonts no\nhide_sst yes\nsst_expanded no\n"
                        "splash_disable yes\nleft_justify_sigs yes\n")
    tcl = [f"gtkwave::addSignalsFromList [list {' '.join('tbw.' + s for s in signals)}]"]
    cmd = {"sdec": "Signed_Decimal", "dec": "Decimal", "bin": "Binary", "hex": "Hex"}
    for s, f in fmt.items():
        tcl += ["gtkwave::/Edit/UnHighlight_All", "gtkwave::highlightSignalsFromList [list {tbw." + full(s) + "}]",
                "gtkwave::/Edit/Data_Format/" + cmd[f]]
    for s, path in filt.items():
        tcl += ["gtkwave::/Edit/UnHighlight_All", "gtkwave::highlightSignalsFromList [list {tbw." + full(s) + "}]",
                f"set fx [gtkwave::setCurrentTranslateFile {path}]", "gtkwave::installFileFilter $fx"]
    tcl += ["gtkwave::/Edit/UnHighlight_All", f"gtkwave::setZoomRangeTimes {int(t0*1000)} {int(t1*1000)}",
            f"gtkwave::setWindowStartTime {int(t0*1000)}"]
    tclf = os.path.join(TMP, nombre + ".tcl"); open(tclf, "w").write("\n".join(tcl) + "\n")
    gtkw = os.path.join(TMP, nombre + ".gtkw")
    open(gtkw, "w").write("[signals_width] 300\n[sst_expanded] 0\n[sst_width] 1\n")
    env = dict(os.environ, DISPLAY=":97")
    xv = subprocess.Popen(["Xvfb", ":97", "-screen", "0", f"{width+20}x{height+40}x24"],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.5)
    g = subprocess.Popen(["gtkwave", "-r", rc, "-S", tclf, vcd, gtkw], env=env,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(6)
    raw = os.path.join(TMP, nombre + "_raw.png")
    subprocess.run(["import", "-window", "root", raw], env=env)
    g.kill(); xv.kill(); time.sleep(0.5)
    im = Image.open(raw)
    bottom = min(im.height, 128 + 21 * (len(signals) + 1) + 12)
    out = os.path.join(OUT, nombre + ".png")
    im.crop((0, 100, width - 14, bottom)).save(out)
    return out

def anotar(nombre, t0, t1, signals, notas):
    """notas: (numero, t_ini, t_fin, [senales]). Un recuadro por grupo de filas contiguas."""
    F = ImageFont.truetype(FONT, 15)
    im = Image.open(os.path.join(OUT, nombre + ".png")).convert("RGB"); d = ImageDraw.Draw(im)
    W = im.width
    x = lambda t: 310 + (t - t0) * (W - 310) / (t1 - t0)
    for n, ta, tb, rows in notas:
        c = COL[(n - 1) % len(COL)]
        x0, x1 = x(ta) - 3, x(tb) - 1
        idx = sorted(signals.index(s) for s in rows); grupos = [[idx[0]]]
        for i in idx[1:]:
            if i == grupos[-1][-1] + 1: grupos[-1].append(i)
            else: grupos.append([i])
        for gr in grupos:
            d.rectangle([x0, 28 + 21 * (gr[0] + 1) - 10, x1, 28 + 21 * (gr[-1] + 1) + 10], outline=c, width=2)
        y0 = 28 + 21 * (idx[0] + 1) - 10
        r = 11; cx, cy = x0 + r + 2, y0 - 2
        if cy - r < 22: cy = y0 + r + 2
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=c, outline="black")
        d.text((cx, cy), str(n), fill="black", font=F, anchor="mm")
    im.save(os.path.join(OUT, nombre + "_a.png"))

# ------------------------------------------------------------------ figuras
def parte2():
    pi, ei = filtros("e2_demo_issue"); pb, eb = filtros("e2_demo_branch"); pp, _ = filtros("benchmark_propio")
    sim_e2("e2_issue", "e2_demo_issue", 150); sim_e2("e2_branch", "e2_demo_branch", 150)
    sim_e2("e2_bench", "benchmark_propio", 15000, data=True)
    v = lambda n: os.path.join(TMP, n + ".vcd")
    D = lambda *n: {k: "dec" for k in n}
    s = ["clk","ciclo","PCF","PCD0","InstrD0","InstrD1","pair_ok","load_stall0","load_stall1","Issue0","Issue1","InstrE0","InstrE1","RetireCnt"]
    captura("e2_fetch", v("e2_issue"), s, 20, 140, fmt=D("ciclo","RetireCnt"), filt={k: pi for k in ["InstrD0","InstrD1","InstrE0","InstrE1"]})
    anotar("e2_fetch", 20, 140, s, [(1,25,35,["InstrD0","InstrD1","pair_ok"]),
        (2,35,45,["InstrD0","InstrD1","pair_ok","load_stall0","load_stall1","Issue0","Issue1"]),
        (3,45,55,["PCD0","InstrD0","InstrD1"]), (4,55,65,["InstrD0","InstrD1","pair_ok"]),
        (5,75,85,["load_stall0","load_stall1","Issue0","Issue1"]), (6,95,105,["InstrD0","InstrD1","Issue0","Issue1"])])
    s = ["clk","ciclo","InstrE0","InstrE1","SrcAE0","SrcBE0","ALUResultE0","SrcAE1","SrcBE1","ALUResultE1","InstrM0","InstrM1","ResultM0","ResultM1","WriteW0","RdW0","ResultW0","WriteW1","RdW1","ResultW1"]
    sd = ["SrcAE0","SrcBE0","ALUResultE0","SrcAE1","SrcBE1","ALUResultE1","ResultM0","ResultM1","ResultW0","ResultW1"]
    captura("e2_exec", v("e2_issue"), s, 30, 150, fmt={**{k: "sdec" for k in sd}, **D("ciclo","RdW0","RdW1")},
            filt={"InstrE0": pi, "InstrE1": pi, "InstrM0": ei, "InstrM1": ei})
    anotar("e2_exec", 30, 150, s, [(1,55,65,["InstrE0","SrcAE0","InstrM0","ResultM0"]), (2,55,65,["SrcBE0","RdW0","ResultW0"]),
        (3,55,65,["WriteW0","RdW0","ResultW0","WriteW1","RdW1","ResultW1"]), (4,95,105,["InstrE0","SrcAE0","RdW0","ResultW0"])])
    s = ["clk","ciclo","InstrM0","InstrM1","memlane","MemWriteM","DataAdrM","WriteDataM","ReadDataM","WriteW0","RdW0","ResultW0","WriteW1","RdW1","ResultW1"]
    captura("e2_mem", v("e2_issue"), s, 50, 150, fmt={**{k: "sdec" for k in ["DataAdrM","WriteDataM","ReadDataM","ResultW0","ResultW1"]}, **D("ciclo","RdW0","RdW1")},
            filt={"InstrM0": ei, "InstrM1": ei})
    anotar("e2_mem", 50, 150, s, [(1,75,85,["InstrM0","memlane","MemWriteM","DataAdrM","WriteDataM"]), (2,85,95,["InstrM0","ReadDataM"]),
        (3,95,105,["WriteW0","RdW0","ResultW0"]), (4,115,125,["InstrM1","memlane","MemWriteM","DataAdrM","WriteDataM"])])
    s = ["clk","ciclo","PCF","InstrD0","InstrD1","Issue0","Issue1","InstrE0","InstrE1","control_lane0","ctaken","RedirectE","RedirectTargetE","InstrM0","InstrM1","WriteW0","RdW0","WriteW1","RdW1"]
    captura("e2_branch", v("e2_branch"), s, 20, 130, fmt=D("ciclo","RdW0","RdW1"),
            filt={**{k: pb for k in ["InstrD0","InstrD1","InstrE0","InstrE1"]}, "InstrM0": eb, "InstrM1": eb})
    anotar("e2_branch", 20, 130, s, [(1,45,55,["InstrE0","InstrE1","control_lane0","ctaken","RedirectE","RedirectTargetE"]),
        (2,55,65,["InstrD0","InstrD1","InstrM0","InstrM1"]), (3,75,85,["InstrE1","control_lane0","ctaken","RedirectE"]),
        (4,85,95,["InstrE0","InstrE1","control_lane0","ctaken","RedirectE","RedirectTargetE"]),
        (5,95,105,["InstrM0","InstrM1"]), (5,105,115,["WriteW0","RdW0"])])
    s = ["clk","ciclo","InstrD0","InstrD1","pair_ok","load_stall0","Issue0","Issue1","InstrE0","InstrE1","RedirectE","memlane","MemWriteM","RetireCnt"]
    captura("e2_bench", v("e2_bench"), s, 2120, 2250, fmt=D("ciclo","RetireCnt"), filt={k: pp for k in ["InstrD0","InstrD1","InstrE0","InstrE1"]})
    anotar("e2_bench", 2120, 2250, s, [(1,2125,2135,["InstrE0","RedirectE"]), (2,2125,2145,["Issue0","Issue1"]),
        (3,2145,2175,["InstrD0","InstrD1","pair_ok"]), (4,2185,2195,["load_stall0","Issue0","Issue1"]),
        (5,2195,2235,["Issue0","Issue1","InstrE0","InstrE1"])])

def parte3():
    P, I = filtros("programa_profesor")
    # el banco escribe profe.vcd en su directorio de trabajo; se simula desde ROOT
    exe = os.path.join(TMP, "profe.vvp")
    subprocess.run(["iverilog", "-g2012", "-s", "testbench_profe", "-s", "tbw", "-o", exe] + RTL +
                   ["testbench_profe.v", os.path.join(AQUI, "ondas_profe.v")], cwd=ROOT, check=True)
    subprocess.run(["vvp", "-n", exe], cwd=ROOT, check=True, capture_output=True)
    vcd = os.path.join(TMP, "profe.vcd"); shutil.move(os.path.join(ROOT, "profe.vcd"), vcd)
    s = ["clk","ciclo","D0","D1","Issue0","Issue1","pair_ok","E0","E1","SrcA0","SrcB0","SrcA1","SrcB1","M0","M1","ResM0","ResM1"]
    captura("caso1", vcd, s, 20, 95, fmt={k: "dec" for k in ["ciclo","SrcA0","SrcB0","SrcA1","SrcB1","ResM0","ResM1"]},
            filt={"D0": P, "D1": P, "E0": P, "E1": P, "M0": I, "M1": I})
    anotar("caso1", 20, 95, s, [(1,25,65,["Issue0","Issue1","pair_ok"]), (2,65,75,["SrcA0","SrcB0","ResM0","ResM1"]),
        (3,65,75,["D0","D1"]), (4,85,95,["SrcA0","ResM0","ResM1"])])
    s = ["clk","ciclo","D0","D1","Issue0","Issue1","pair_ok","load_stall0","E0","E1","M0","M1","MemWrite","memlane","DataAdr","WriteData","ReadData","SrcA0","SrcB0"]
    captura("caso2", vcd, s, 85, 165, fmt={k: "dec" for k in ["ciclo","DataAdr","WriteData","ReadData","SrcA0","SrcB0"]},
            filt={"D0": P, "D1": P, "E0": P, "E1": P, "M0": I, "M1": I})
    anotar("caso2", 85, 165, s, [(1,85,105,["D0","D1","Issue1","pair_ok"]), (2,95,105,["M1","MemWrite","memlane","DataAdr","WriteData"]),
        (3,105,115,["D0","D1","Issue1"]), (4,115,125,["Issue0","Issue1","load_stall0","E0"]),
        (5,125,135,["E0","E1","ReadData"]), (6,135,145,["E0","SrcA0"])])
    s = ["clk","ciclo","PCF","D0","PredD0","D1","PredD1","Issue0","Issue1","E0","E1","BranchE","PredE","ctaken","MispredictE","RedirectTarget","cont_C2a","cont_C2"]
    captura("caso3", vcd, s, 840, 950, fmt={"ciclo": "dec", "cont_C2a": "bin", "cont_C2": "bin"},
            filt={"D0": P, "D1": P, "E0": P, "E1": P})
    anotar("caso3", 840, 950, s, [(1,845,855,["E0","E1","PredE","ctaken","MispredictE"]),
        (2,855,865,["E0","PredE","ctaken","MispredictE","RedirectTarget"]), (3,865,875,["D0","PredD0","D1","PredD1","cont_C2a"]),
        (4,875,885,["D1","PredD1"]), (4,885,895,["E1","MispredictE"]), (5,925,935,["E0","PredE","ctaken","MispredictE","RedirectTarget"])])
    s = ["ciclo"] + [f"{c}_etapa{e}" for c in "ABC" for e in "ABCD"]
    captura("cierre_todas", vcd, s, 20, 4620, fmt={"ciclo": "dec"})
    F = ImageFont.truetype(FONT, 13)
    im = Image.open(os.path.join(OUT, "cierre_todas.png")).convert("RGB"); d = ImageDraw.Draw(im)
    x = lambda t: 310 + (t - 20) * (im.width - 310) / 4600
    pulsos = {"A": [(186,17),(326,31),(3626,361),(4596,458)], "B": [(135,12),(265,25),(3135,312),(3885,387)],
              "C": [(135,12),(265,25),(2175,216),(2835,282)]}
    colores = {"A": "#FFD400", "B": "#3FD0FF", "C": "#B6FF3B"}
    for k, core in enumerate("ABC"):
        for e, (t, cyc) in enumerate(pulsos[core]):
            xx = x(t) + 6
            if xx + 70 > im.width: xx = x(t) - 75
            d.text((xx, 28 + 21 * (1 + 4 * k + e + 1)), f"ciclo {cyc}", fill=colores[core], font=F, anchor="lm")
    im.save(os.path.join(OUT, "cierre_todas_a.png"))
    s = ["clk","ciclo","M0","M1","MemWrite","DataAdr","WriteData","C_etapaA","C_etapaB","C_etapaC","C_etapaD","etapas_ok_C",
         "x10","x18","x21","x22","x24","x28","x29","x31","M_x1_8","M_x1_20","M_x1_32","M_x1_52"]
    fmtz = {k: "dec" for k in ["ciclo","DataAdr","WriteData","etapas_ok_C","x10","x18","x21","x22","x24","x28","x29","x31",
                               "M_x1_8","M_x1_20","M_x1_32","M_x1_52"]}
    cfg = {"A": (95,150,115,125,135,145,["x10"],["M_x1_8"],"C_etapaA"), "B": (225,280,245,255,265,275,["x18"],["M_x1_20"],"C_etapaB"),
           "C": (2135,2190,2155,2165,2175,2185,["x21","x22","x24"],["M_x1_32"],"C_etapaC"),
           "D": (2795,2850,2815,2825,2835,2845,["x28","x29","x31"],["M_x1_52"],"C_etapaD")}
    for e, (a, b, s0, s1, c0, c1, regs, mem, chk) in cfg.items():
        captura(f"cierre_{e}", vcd, s, a, b, fmt=fmtz, filt={"M0": I, "M1": I}, width=1500)
        anotar(f"cierre_{e}", a, b, s, [(1,s0,s1,["M0","M1","MemWrite","DataAdr","WriteData"]), (2,s1,b,mem),
                                        (3,c0,c1,[chk,"etapas_ok_C"]), (4,c0,b,regs)])

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    parte2(); parte3()
    shutil.rmtree(TMP, ignore_errors=True)
    print("Capturas en", OUT)

#!/bin/sh
# correr_pruebas.sh - Ejecuta todas las pruebas de E1 y E2 con Icarus Verilog y
# guarda la salida completa en resultados/salidas.txt, con el commit y las versiones.
#
#     sh tools/correr_pruebas.sh            # incluye 1000 programas aleatorios
#     sh tools/correr_pruebas.sh 100        # solo 100 programas aleatorios
#
# Se ejecuta desde la raiz del repositorio. Requiere iverilog/vvp y python3.
set -u
N=${1:-1000}
OUT=resultados/salidas.txt
TMP=$(mktemp -d)
mkdir -p resultados

corre() {   # corre <titulo> <top> [args de iverilog...]
    titulo=$1; top=$2; shift 2
    echo "=== $titulo ($top)"
    if iverilog -g2012 -s "$top" -o "$TMP/sim" "$@" 2>&1; then
        vvp -n "$TMP/sim" 2>&1 | grep -v "^VCD info" | grep -v "Not enough words"
    else
        echo "ERROR de compilacion"
    fi
    echo
}

{
echo "Commit: $(git rev-parse --short HEAD 2>/dev/null || echo desconocido)"
echo "Fecha:  $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "Icarus: $(iverilog -V 2>&1 | head -1)"
echo "Python: $(python3 --version 2>&1)"
echo

echo "########## E1 (configuracion A)"
corre "Programa 1: ALU" testbench_test1 *.v
corre "Programa 2: forwarding" testbench_base234 -P testbench_base234.TEST=2 -P 'testbench_base234.PROGRAM="test2_forwarding.mem"' *.v
corre "Programa 3: load-use" testbench_base234 -P testbench_base234.TEST=3 -P 'testbench_base234.PROGRAM="test3_stalling.mem"' *.v
corre "Programa 4: flush" testbench_base234 -P testbench_base234.TEST=4 -P 'testbench_base234.PROGRAM="test4_flushing.mem"' *.v
corre "Bypass WB a Decode" testbench_wb_decode *.v
corre "Banco de registros" testbench_regfile *.v
corre "Hazard Unit" test_hazard *.v
corre "Frontend aislado" test_frontend_sync *.v
corre "Frontend integrado" test_frontend_pipeline *.v
corre "Control (bne, blt, bge, jal, jalr)" testbench_control *.v

echo "########## E2 (configuracion B)"
corre "Emision y retiro" testbench_e2 testbench_e2.v e2_top.v e2_pipeline.v regfile.v imem.v dmem.v
corre "Control en ambas vias" testbench_e2_control testbench_e2_control.v e2_top.v e2_pipeline.v imem.v dmem.v regfile.v
corre "Desplazamientos" testbench_e2_shift testbench_e2_shift.v e2_pipeline.v regfile.v
corre "Escenarios dirigidos" testbench_e2_directed testbench_e2_directed.v e2_pipeline.v regfile.v
corre "Banco de registros 4R/2W" testbench_regfile_dual testbench_regfile_dual.v regfile.v
corre "Medicion benchmark_e1_e2" testbench_medicion_e2 *.v

echo "########## Comparacion A vs B contra el modelo de referencia"
for p in benchmark_propio e2_demo_issue e2_demo_branch; do
    corre "Comparacion $p" testbench_comparacion \
        -P "testbench_comparacion.PROGRAM=\"$p.mem\"" -P "testbench_comparacion.DATA=\"$p.data.mem\"" \
        -P "testbench_comparacion.EXP_REGS=\"$p.exp_regs\"" -P "testbench_comparacion.EXP_MEM=\"$p.exp_mem\"" *.v
done

echo "########## Verificacion aleatoria ($N programas, semillas 0..$((N-1)))"
python3 tools/prueba_aleatoria.py "$N" 0 2>&1
} > "$OUT"

rm -rf "$TMP"
grep -cE "PASS" "$OUT" | sed 's/^/Lineas con PASS: /'
grep -nE "FAIL|ERROR" "$OUT" && echo "Hay fallas: revisar $OUT" || echo "Sin fallas. Salida en $OUT"

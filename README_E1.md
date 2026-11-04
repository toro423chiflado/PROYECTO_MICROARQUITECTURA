# Proyecto 2 - E1

## Implementacion

- `riscv_pipeline.v` mantiene el pipeline RV32I de cinco etapas.
- `hazard.v` implementa forwarding, stalling Load-Use y flushing.
- `dual_issue_frontend.v` trae dos palabras consecutivas y registra dos instrucciones de Decode.
- `dual_issue_datapath.v` es la segunda via ALU preliminar y recibe operandos del mismo banco de registros. La politica de emision bloquea la segunda instruccion cuando la primera es branch, jump, load, store o existe una dependencia RAW.
- `imem.v` tiene dos puertos de lectura y permite cambiar el programa mediante el parametro `PROGRAM`.

## Programas de prueba

El testbench es parametrizable. En Vivado se puede ejecutar cada programa cambiando el parametro del testbench:

```text
PROGRAM = test1_nodep.mem
PROGRAM = test2_forwarding.mem
PROGRAM = test3_stalling.mem
PROGRAM = test4_flushing.mem
```

Durante la simulacion se imprimen `PC`, las dos instrucciones decodificadas y `dual_issue`. Los contadores del testbench son indicadores de actividad, no de instrucciones retiradas: pueden incluir NOP o ciclos de stall.

## Correcciones y resultados

- El banco de registros aplica bypass desde WB a las cuatro lecturas de Decode cuando coinciden las direcciones y la escritura esta activa; `x0` siempre lee cero.
- El reset del testbench se desactiva en un flanco descendente para evitar carreras con el flanco activo del reloj.
- Load-Use compara solamente los operandos utilizados por el opcode. El frontend auxiliar conserva sus registros durante `StallD` y los limpia con `FlushD`.
- La prueba 1 incluye operaciones aritmeticas, logicas y desplazamientos implementados, con comprobacion de 17 escrituras esperadas.

Simulaciones ejecutadas con Icarus Verilog mediante Docker (`hdlc/iverilog`):

| Prueba | Resultado | Comprobacion |
| --- | --- | --- |
| 1: operaciones independientes | PASS | 17 escrituras esperadas, sin escrituras inesperadas en memoria |
| 2: forwarding | PASS | `x1=5`, `x2=10`, `x3=15` y actividad de forwarding |
| 3: load-use | PASS | `x1=20`, `x2=20`, `x3=40`, store y stall |
| 4: flushing | PASS | `x1=5`, `x2=5`, `x5=9`; instrucciones descartadas sin escritura |
| WB/Decode | PASS | `addi x1,x0,7; nop; nop; add x2,x1,x0`: coincidencia observada y `x2=7` |
| Banco de registros y hazard | PASS | Cuatro puertos, `x0`, y operandos usados por los 128 opcodes |
| Frontend dual | PASS | Stall, flush, prioridad de flush y sincronizacion integrada |

Los archivos de memoria son mas cortos que la memoria simulada y esta se inicializa con NOP; Icarus emite advertencias de `$readmemh` sobre longitud y orden del arreglo. Estas pruebas no demuestran cobertura exhaustiva de todas las instrucciones ni de todos los riesgos.

## Alcance

La segunda via es preliminar, como solicita la E1: aun no hace commit independiente al banco de registros, no resuelve todos los riesgos entre ciclos ni dos operaciones de memoria en el mismo ciclo. El frontend auxiliar tampoco comparte la alineacion y descompresion RVC del pipeline principal; invalida conservadoramente los casos que no puede procesar. Los indicadores mantenidos durante stall no son eventos de retiro. Vease `FRONTEND_DUAL_LIMITACIONES.md`. Estos elementos deben resolverse antes de considerar completa la ampliacion E2/EF.

# Proyecto 2 - Entrega 1

Procesador RISC-V segmentado de cinco etapas con Hazard Unit y adaptación
Dual-Issue preliminar. En E1 no se exige ejecución simultánea completa de dos
instrucciones.

## Implementación

- `riscv_pipeline.v`: integración de control, datapath y Hazard Unit.
- `datapath.v`: IF, ID, EX, MEM y WB con registros interetapa.
- `regfile.v`: cuatro lecturas, una escritura y bypass de WB a Decode; x0 lee cero.
- `hazard.v`: forwarding, Load-Use según fuentes utilizadas, stalling y flushing.
- `imem.v`: dos lecturas para Dual Fetch y selección de programa con PROGRAM.
- `dual_issue_frontend.v`: dos registros Decode sincronizados con StallD y FlushD.
- `dual_issue_datapath.v`: cálculos ALU preliminares de observación.

## Ejecución en Vivado

1. Abrir `PROYECTO2/PROYECTO2.xpr`.
2. En Simulation Sources, hacer clic derecho sobre el banco elegido y seleccionar
   **Set as Top**.
3. Para los programas 2, 3 y 4, configurar ambos parámetros en Settings >
   Simulation > Compilation > Generics/Parameters. Para los demás bancos,
   eliminar las entradas externas TEST y PROGRAM de ese cuadro.
4. Ejecutar Run Simulation > Run Behavioral Simulation. Una ejecución solicitada
   de 1000 ns termina antes cuando el banco ejecuta `$finish`.

| Prueba | Simulation Top | Parámetros externos | Resultado esperado |
| --- | --- | --- | --- |
| Programa 1 | `testbench_test1` | Ninguno | 17 escrituras verificadas |
| Programa 2 | `testbench_base234` | `TEST=2`, `PROGRAM="test2_forwarding.mem"` | 3 escrituras, 2 ciclos con forwarding |
| Programa 3 | `testbench_base234` | `TEST=3`, `PROGRAM="test3_stalling.mem"` | 1 store, 1 stall, x3=40 |
| Programa 4 | `testbench_base234` | `TEST=4`, `PROGRAM="test4_flushing.mem"` | 1 flush y solo escrituras válidas |
| WB/Decode | `testbench_wb_decode` | Ninguno | Coincidencia observada y x2=7 |
| Banco de registros | `testbench_regfile` | Ninguno | Bypass de cuatro lecturas y x0 |
| Hazard Unit | `test_hazard` | Ninguno | Comprobaciones de Load-Use y control |
| Frontend aislado | `test_frontend_sync` | Ninguno | Retención, limpieza y prioridad |
| Frontend integrado | `test_frontend_pipeline` | Ninguno | Un stall y un flush integrados |
| Control adicional | `testbench_control` | Ninguno | BNE, BLT, BGE, JAL y JALR |

Las diez ejecuciones dieron PASS en Vivado 2025.2. Los bancos dirigidos verifican
resultados automáticamente y utilizan `$fatal` ante discrepancias. Los cuatro
programas principales y la batería adicional también se comprobaron con Icarus.
Son pruebas dirigidas; no constituyen verificación exhaustiva de todos los
operandos, desplazamientos y combinaciones de hazards.

## Alcance de la entrega :) 

La segunda vía es preliminar: permite obtener y registrar dos instrucciones
y observar resultados ALU, pero todavía no escribe resultados de forma
independiente en el banco de registros. Las señales DualIssue e IssueD1
indican elegibilidad preliminar, no instrucciones retiradas.

La emisión simultánea completa se desarrollará en E2.

## Prueba adicional de control

- `test_control.s`: programa Assembly de referencia.
- `test_control.mem`: hexadecimal con 38 instrucciones y relleno hasta 64 palabras.
- `testbench_control.v`: diez decisiones de control, 17 escrituras a registros,
  seis redirecciones y un store final permitido.

Se prueban BNE tomado y no tomado; BLT y BGE con valores negativos, comparación
inversa e igualdad; JAL con retorno 0x70 y JALR con retorno 0x84. Para JALR se
comprueba que 0x88 + 5 = 0x8D produce destino 0x8C al borrar el bit 0. Las
instrucciones del camino descartado no pueden escribir registros ni memoria.

La configuración `PROYECTO2/test_control.wcfg` corresponde a `testbench_control`.
Para otros bancos se debe crear o abrir una configuración de ondas compatible.
Una advertencia de rutas pertenecientes a otro top es un problema de la vista
de ondas; el PASS o fallo funcional se consulta en la consola.

El proyecto se conserva con `test_frontend_pipeline` como último top de simulación.
El banco general `testbench` mantiene por defecto el ejemplo RVC `test_e2p2.mem`;
para las pruebas E1 anteriores deben seleccionarse los bancos indicados.


## Archivos generados

Las cachés, productos de simulación y logs locales de Vivado no forman parte de
las fuentes. El `.gitignore` los excluye, al igual que las ayudas y evidencias
locales. Las figuras y resultados para evaluación se conservan en el informe y
en su paquete de evidencia por separado.

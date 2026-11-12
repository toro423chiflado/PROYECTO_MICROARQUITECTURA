# Documentación de E2

## Alcance

E2 tiene un núcleo independiente: `e2_top.v` instancia `e2_pipeline.v`, `imem.v` y `dmem.v`. No es la vía de `top.v`/`riscv_pipeline.v` de E1. E1 conserva su frontend dual y sus resultados preliminares de observación, pero su vía principal usa una sola escritura arquitectónica. Ambos diseños comparten `regfile.v` y las memorias; las pruebas de E1 no demuestran por sí solas el comportamiento de E2.

El diseño E2 implementa emisión en orden de hasta dos instrucciones de 32 bits y dos vías de ejecución y escritura. Es una implementación con restricciones y pruebas dirigidas, no una demostración de conformidad completa con RV32I. Hay una medición comparativa limitada a un programa concreto, descrita en `MEDICION_E2.md`.

## Implementación E2

`e2_top` selecciona el archivo de instrucciones con `PROGRAM`, cuyo valor por defecto es `test_e2p2.mem`. Lee en paralelo `PCF` y `PCF+4`, conecta el único puerto de datos y expone `PCF`, `Issue0`, `Issue1`, `RedirectE`, `RedirectTargetE`, `MemWrite`, `DataAdr` y `WriteData`. `Issue0`/`Issue1` indican emisión desde Decode, no retiro; `RedirectE` indica una redirección tomada en EX.

`e2_pipeline` mantiene dos posiciones, con instrucción y validez, en Decode, EX, MEM y WB; conserva además el PC cuando se necesita en Decode/EX. Fetch proporciona dos palabras. La posición 0 es la más antigua y la 1 la más joven. El reset sincrónico pone `PCF` en cero e invalida las etapas; no inicializa el banco de registros ni la memoria de datos.

- Decode emite la primera instrucción si está válida y no hay bloqueo load-use ni redirección. Emite también la segunda si es válida, no depende por RAW de la primera y no hay dos operaciones de memoria, dos de control o un load-use que la bloquee. Las restricciones del par se aplican cuando ambas codificaciones son legales.
- Si solo se emite la primera, la segunda se conserva como primera y se incorpora la siguiente palabra de Fetch; el PC avanza 4. Al admitir dos, se carga un nuevo par y el PC avanza 8. Si la primera está bloqueada, Decode y PC se retienen. Esto permite reagrupar instrucciones sin exigir parejas fijas.
- EX calcula ambas vías. Hay forwarding a sus operandos desde MEM para resultados que no son loads y desde WB, dando prioridad a la vía más joven dentro de cada etapa y a MEM sobre WB. Una dependencia de un load en EX bloquea al consumidor correspondiente en Decode; no hay forwarding directo de load desde MEM.
- Un recurso de control compartido resuelve en EX las ramas y saltos de cualquiera de las dos posiciones. Una redirección invalida Decode y suprime la emisión de ese ciclo. Si el control tomado está en la posición 0, se invalida también la instrucción más joven de EX antes de MEM; si está en la posición 1, se conserva la más antigua.
- MEM selecciona como máximo una operación de memoria del par. WB conecta ambas vías al banco de registros. No hay interfaz explícita de retiro ni PC almacenado en WB.

## ISA y memorias

El decodificador acepta las operaciones enteras de registro `ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND` y sus variantes inmediatas `ADDI`, `SLLI`, `SLTI`, `SLTIU`, `XORI`, `SRLI`, `SRAI`, `ORI`, `ANDI`; también `LUI`, `AUIPC`, `JAL`, `JALR`, `BEQ`, `BNE`, `BLT`, `BGE`, `BLTU`, `BGEU`, y únicamente `LW` y `SW` para memoria. Las codificaciones rechazadas por `legal()` se emiten sin efectos y sin excepción; la emisión por sí sola no implica que la instrucción sea legal. No se implementan traps, CSR, `FENCE`, instrucciones de la extensión M ni acceso de byte o media palabra. No se admite RVC en este núcleo.

`imem` y `dmem` contienen 256 palabras de 32 bits (1 KB, parámetro `DEPTH`) y se indexan con los bits `[9:2]` de la dirección. `imem` rellena con NOP y carga `PROGRAM` mediante `$readmemh`; `dmem` arranca en cero, tiene lectura combinacional y escritura en flanco ascendente. Se requieren instrucciones y accesos `LW`/`SW` alineados a palabra y dentro de las memorias: no se detectan ni generan excepciones por desalineación o acceso fuera de rango. `JALR` solo borra el bit 0 del destino, por lo que el software debe garantizar la alineación de palabra necesaria. No se reconstruyen instrucciones entre palabras.

## Banco de registros

`regfile.v` ofrece cuatro lecturas combinacionales y dos escrituras en flanco ascendente. Las lecturas incorporan bypass de ambos puertos; ante el mismo destino no nulo, el puerto 6, correspondiente a la instrucción más joven en E2, tiene prioridad tanto en bypass como en escritura. `x0` siempre lee cero y no se escribe. El puerto 6 solo se activa cuando `we6` es exactamente 1, lo que permite a E1 dejarlo desconectado. Los demás registros no tienen reset ni valor inicial garantizado.

`testbench_regfile_dual.v` comprueba escrituras simultáneas a destinos distintos, bypass en las cuatro lecturas, persistencia, prioridad en conflictos, habilitación individual, `we6` desconocido, `x0` y una instancia estilo E1 con el segundo puerto desconectado. No sustituye a las pruebas integradas del pipeline.

## Pruebas disponibles

`testbench_e2.v` ejecuta `e2_top` con `testbench_e2.mem`. Inicializa explícitamente las 64 palabras de memoria de datos y rellena la imagen de instrucciones con NOP. Verifica 23 instrucciones esperadas en orden en WB, sus escrituras a registros, cinco stores con dirección y datos, y el estado final de toda la memoria de datos. Detecta timeout y efectos inesperados mediante `$fatal`.

El banco exige observar emisión conjunta ALU+ALU, memoria+ALU, ALU+memoria y un salto en segunda posición, emisión de un salto en primera posición, reagrupamiento y dos escrituras simultáneas. También rechaza la emisión conjunta del par concreto de dos operaciones de memoria. El programa ejercita RAW, load-use y dos `JAL` que saltan stores del camino incorrecto. La comprobación de WB identifica instrucciones comparando su codificación con la imagen en los PC esperados, pues WB no conserva PC; codificaciones repetidas no permiten identificar inequívocamente el PC real. Los indicadores de cobertura corresponden a los pares y posiciones concretos del programa, no a todas las combinaciones.

`testbench_e2_control.v` instancia `e2_top` y genera siete escenarios dirigidos en memoria: BEQ tomado y no tomado en cada posición, JAL en posición 0, JALR en posición 1 y dos escrituras al mismo registro seguidas de una rama dependiente. Verifica emisión conjunta, posición y decisión del control, destino de redirección tomado, enlaces y limpieza selectiva, stores permitidos y descartados, y en el caso WAW la prioridad y forwarding del valor joven. Inicializa registros y memorias entre escenarios; no comprueba todas las ramas ni todas las combinaciones de control.

`testbench_e2_shift.v` verifica SRA, SRAI y SRL con distintos signos y cantidades de desplazamiento, además de dependencias con forwarding. Comprueba 14 resultados de registros.

`testbench_e2_directed.v` prueba directamente `e2_pipeline` en 21 escenarios: BNE, BLT, BGE, BLTU y BGEU tomados y no tomados en ambas posiciones, más un escenario de dependencias RAW, load-use, conflicto de memoria, WAW y forwarding. Comprueba cobertura, registros y memoria; no sustituye las pruebas con `e2_top`.

`testbench_medicion_e2.v` ejecuta E1 y E2 con `benchmark_e1_e2.mem`, verifica la secuencia y el estado final y compara ciclos e instrucciones retiradas mediante instrumentación del banco. `MEDICION_E2.md` detalla el procedimiento, resultados y limitaciones: el IPC y el speedup en ciclos corresponden únicamente a ese programa, no al rendimiento general.

La prueba de control `testbench_control.v`, con `test_control.mem`, es de **E1**, ya que instancia `top`. Comprueba BNE, BLT y BGE tomados y no tomados en casos dirigidos, JAL y JALR, sus destinos y enlaces, flush, escrituras y ausencia de stores indebidos. Sus resultados no verifican E2. La guía `GUIA_EJECUCION_PROFE.md` describe los demás bancos de E1 y su ejecución en Vivado.

## Ejecución en Docker

Desde PowerShell, situado en la raíz del proyecto y con Docker en ejecución, usar la imagen `hdlc/iverilog`. Los comandos montan el proyecto en solo lectura y dejan los ejecutables y el VCD de control en `/tmp` dentro del contenedor, que se elimina al terminar. Si la imagen no está disponible localmente, Docker intentará descargarla.

```powershell
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2 -o /tmp/e2 testbench_e2.v e2_top.v e2_pipeline.v regfile.v imem.v dmem.v && vvp /tmp/e2'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2_control -o /tmp/e2_control testbench_e2_control.v e2_top.v e2_pipeline.v imem.v dmem.v regfile.v && vvp /tmp/e2_control'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2_shift -o /tmp/e2_shift testbench_e2_shift.v e2_pipeline.v regfile.v && vvp /tmp/e2_shift'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2_directed -o /tmp/e2_directed testbench_e2_directed.v e2_pipeline.v regfile.v && vvp /tmp/e2_directed'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_medicion_e2 -o /tmp/medicion *.v && vvp /tmp/medicion'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_regfile_dual -o /tmp/rf testbench_regfile_dual.v regfile.v && vvp /tmp/rf'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" -w /src --entrypoint sh hdlc/iverilog -c 'cd /tmp && iverilog -g2012 -s testbench_control -o control /src/*.v && ln -s /src/test_control.mem test_control.mem && vvp control'
```

Las pruebas E2 principal, de control y shifts, la de banco de registros y la de control E1 se ejecutaron con esa imagen y dieron respectivamente `PASS E2: 23 ordered retirements, memory and directed issue coverage`, `PASS E2 control: 7 directed integration scenarios`, `PASS E2 shifts: 14 register results and forwarding coverage`, `PASS: dual regfile writes, priority, x0, bypass and E1 compatibility` y `PASS CONTROL`/`PASS LINKS`. El banco directed debe terminar con `PASS E2 directed: 21 scenarios`; para la salida y ejecución de la medición, consultar `MEDICION_E2.md`. En la primera prueba E2, Icarus advierte sobre el rango de `imem` y que el archivo contiene menos de 64 palabras; la memoria se rellena previamente con NOP y el banco carga su propia imagen. Comprobar siempre tanto el código de salida como el `PASS` correspondiente; compilar no equivale a superar la prueba.

Para generar y consultar las formas de onda opcionales de las pruebas E2 principal y de control, seguir `GUIA_WAVEFORMS_E2.md`.

Los módulos y bancos E2 también están registrados en `PROYECTO2/PROYECTO2.xpr`, que abre con `testbench_e2` como Simulation Top. Para simular otro banco se elige como Simulation Top. En Vivado 2025.2 se ejecutaron `testbench_e2`, `testbench_e2_control`, `testbench_e2_directed` y `testbench_medicion_e2`; la tabla de `GUIA_EJECUCION_PROFE.md` indica cómo correr cada banco y cuáles se comprobaron solo con Icarus.

## Límites de verificación

Un `PASS` acredita únicamente los casos del banco. Aunque el banco directed cubre otras clases de ramas directamente en el pipeline, faltan más pruebas integradas con `e2_top`, JAL y JALR en más posiciones y con distintas instrucciones compañeras, interacciones simultáneas de redirect y stall, y ausencia de efectos descartados en más configuraciones. También faltan pruebas amplias de WAW y bypass entre vías y etapas, dependencias sobre ambos operandos, conflictos de memoria y reintentos, instrucciones no soportadas, reset durante ejecución y límites de memoria. Las operaciones de la ISA aceptada no están todas ejercitadas por los bancos E2.

Para ampliar la confianza hacen falta programas variados y comparación de efectos arquitectónicos ordenados y estado final con un modelo secuencial, además de regresión de E1. La medición existente cuenta retiros con instrumentación específica para su programa; `Issue0` y `Issue1` no bastan para inferir IPC.

# Medicion comparativa E1 vs E2

## Medicion generica (cualquier programa)

`testbench_comparacion.v` ejecuta en paralelo la configuracion A (`top`,
pipeline single-issue) y la B (`e2_top`, dual-issue) con el mismo programa, los
mismos datos iniciales y el mismo reset. No necesita listas de PCs esperados,
por lo que sirve para el programa propio y para el del profesor.

- **Fin de programa:** la ultima instruccion debe ser `halt` = `jal x0, 0`
  (`0000006f`).
- **Ciclos:** desde el primer flanco de subida tras soltar el reset hasta el
  ciclo en que `halt` llega a WB, incluido. Mismo criterio para A y B.
- **Instrucciones retiradas:** instrucciones validas que llegan a WB. No se
  cuentan burbujas, instrucciones anuladas por saltos ni el `halt`. Ambos
  nucleos tienen las salidas `RetireW`/`RetireCnt` y `HaltW` para esto.
- **Comprobaciones:** A y B deben terminar con los mismos 31 registros, la misma
  memoria de datos y el mismo numero de instrucciones retiradas. Si se pasan
  `EXP_REGS`/`EXP_MEM`, tambien se comparan con el resultado esperado.
- **Metricas:** retiradas, ciclos, IPC, CPI, speedup A->B, stalls load-use,
  saltos tomados, ciclos con 2 y con 1 instruccion emitida y uso de la doble
  emision.

```sh
iverilog -g2012 -s testbench_comparacion -o /tmp/cmp \
  -P testbench_comparacion.PROGRAM='"programa.mem"' \
  -P testbench_comparacion.DATA='"programa.data.mem"' \
  -P testbench_comparacion.EXP_REGS='""' -P testbench_comparacion.EXP_MEM='""' \
  *.v && vvp /tmp/cmp
```

En Vivado: Simulation Top = `testbench_comparacion` y los mismos parametros en
Generics/Parameters. `DATA`, `EXP_REGS` y `EXP_MEM` pueden quedar en `""`.

## Medicion original del programa `benchmark_e1_e2`

## Resultado reproducido

Ejecucion con Docker, imagen local `hdlc/iverilog:latest`, el 11-11-2026:

| Nucleo | Ciclos | Instrucciones retiradas | IPC | CPI |
| --- | ---: | ---: | ---: | ---: |
| E1 | 32 | 23 | 0.718750 | 1.391304 |
| E2 | 23 | 23 | 1.000000 | 1.000000 |

Speedup en ciclos = 32/23 = **1.391304x**. IPC = retiradas/ciclos;
CPI = ciclos/retiradas. Solo es speedup de tiempo si ambos tienen el mismo
periodo de reloj; no se ha medido frecuencia maxima, sintesis ni tiempo real.

Salida relevante real:

```text
PASS E1 cycles=32 retired=23 IPC=0.718750 CPI=1.391304
PASS E2 cycles=23 retired=23 IPC=1.000000 CPI=1.000000
speedup E1/E2=1.391304, stores=5/5, drain=8 cycles
coverage wrong-path discarded E1=2 E2=1, stall signal observations E1=1 E2=1
```

## Ejecucion

Desde la raiz del proyecto, con Docker funcionando (Linux o macOS):

```sh
docker run --rm --mount "type=bind,source=$(pwd),target=/src" --workdir /src hdlc/iverilog:latest sh -c 'iverilog -g2012 -s testbench_medicion_e2 -o /tmp/medicion.vvp *.v && vvp /tmp/medicion.vvp'
```

Comando efectivamente ejecutado en Windows Git Bash en esta maquina:

```sh
MSYS_NO_PATHCONV=1 docker run --rm --mount "type=bind,source=C:/Users/ssilvar/Documents/PROYECTO_MICROARQUITECTURA,target=/src" --workdir /src hdlc/iverilog sh -c "iverilog -g2012 -s testbench_medicion_e2 -o /tmp/medicion.vvp *.v && vvp /tmp/medicion.vvp"
```

En otra maquina Windows se debe sustituir `source` por la ruta absoluta del
proyecto. El ejecutable se genera dentro del contenedor, no en el repositorio.
La simulacion emite advertencias de `imem.v` por el orden de indices de su
array y porque el programa tiene 25 palabras y la memoria 64; las posiciones
restantes son inicializadas por `imem` con NOP antes de `$readmemh`. La prueba
verifica la secuencia y el estado, no interpreta esas advertencias como PASS.

## Metodologia

`benchmark_e1_e2.mem` contiene el mismo programa RV32I de 25 palabras para los
dos top reales (`top` para E1 y `e2_top` para E2). Es una copia del cuerpo de
`testbench_e2.mem` hasta el store final, sin el bucle terminal. Incluye ALU,
dependencias RAW, dos cargas, cinco stores validos y dos JAL que saltan sendos
stores incorrectos. No usa instrucciones comprimidas ni operaciones no comunes.
`benchmark_e1_e2.s` muestra la secuencia Assembly equivalente; la simulacion
carga directamente el archivo `.mem` y no ensambla el `.s`.
Las dos memorias de datos y bancos de registros se inicializan a cero desde el
banco; las memorias de instrucciones reciben exactamente el mismo archivo.
Se libera el mismo reset en un flanco descendente. Ciclo 1 es el primer flanco
ascendente posterior; el ultimo ciclo medido es aquel en que el store final,
PC `0x60`, alcanza WB. Se incluyen llenado, stalls y penalizaciones de control,
pero no los ocho ciclos de observacion posteriores. El store se ejecuta en MEM
antes de llegar a WB; esperar WB incluye su avance por todo el pipeline.

Los retiros son una reconstruccion del paso por WB, no una interfaz de retiro
arquitectonico ni una comprobacion de cada escritura intermedia. E2 cuenta
`wv[0]` y `wv[1]` en WB, en orden de antiguedad, no `Issue0/1`.
El banco lleva etiquetas PC externas desde EX a MEM/WB, comprueba PC e
instruccion contra una secuencia esperada y solo incluye PCs del programa
medido. Asi no cuenta el store especulativo de la via 1 que E2 invalida antes
de MEM. Se exige observar al menos uno de esos descartes. Los NOP de relleno
posteriores a `0x60` no son parte del benchmark.

E1 no tiene validos ni PC en WB. El banco propaga etiquetas PC y validos
externos siguiendo `StallD`, `FlushD` y `FlushE`, y las etapas E/M/W. Comprueba
en D que el PC etiquetado corresponde a la instruccion real y en WB exige el PC
esperado. Las burbujas y los caminos descartados no se cuentan; se exige ver
descartes reales y observaciones de senales de stall en ambos nucleos. En E1,
el descarte exige `PCSrcE` y `FlushE` con una etiqueta valida de PC 56 o 64;
`FlushE` por si sola tambien puede indicar una burbuja por carga. En E2 se
exige una via 1 valida con PC 56 o 64 y un control tomado en la via 0.
Esta reconstruccion depende de la estructura actual del RTL.

La cobertura de stalls cuenta flancos en que `StallD` de E1 esta activa o
alguna de `load_stall0/1` de E2 esta activa, respectivamente. Son observaciones
de senales, no ciclos perdidos ni una medida comparable de penalizacion: en E2
ambas senales activas en el mismo flanco cuentan una sola vez. Los contadores
de cobertura se acumulan desde el primer flanco tras reset hasta terminar la
observacion, incluidos los flancos posteriores al ultimo retiro de cada nucleo;
no estan acotados a sus ciclos medidos individuales.

Se esperan exactamente los 23 PCs dinamicos `0,4,...,52,60,68,72,...,96`
en bytes, incluyendo los dos saltos y cinco stores, sin los PCs 56 y 64.
Cualquier retiro incluido fuera de orden, store adicional, valor incorrecto en
las comprobaciones indicadas o timeout produce `$fatal`. Tras el retiro del marcador en ambos, se observan
ocho flancos adicionales: deben seguir existiendo exactamente 23 retiros del
programa y cinco stores por nucleo. Se comprueban los 31 registros modificables
contra valores esperados y las 64 palabras de memoria de ambos contra si mismas
y los valores esperados: `[12,19,5,6,1]` y ceros restantes. Los registros y
memorias se leen despues de las actualizaciones no bloqueantes del ultimo
flanco. El pipeline completo no queda vacio: sigue ejecutando NOP de relleno;
lo drenado y comprobado es el programa medido, no el fetch global.

## Limitaciones

Es una sola carga corta y dirigida, con entradas fijas: no representa rendimiento
general, cache, latencias variables, interrupciones ni otros programas. No es
una prueba exhaustiva RV32I ni un contador de retiro general: filtra por rango
de PC y usa una traza esperada fija, por lo que no sirve sin adaptacion para
bucles, retornos al rango o instrucciones adicionales. El banco verifica estado
final y orden de retiros, no todos los valores intermedios de cada escritura a
registro. La medicion depende de los nombres y controles internos actuales de
ambos nucleos; cambios de microarquitectura requieren revisar la instrumentacion.

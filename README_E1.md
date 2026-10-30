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

Durante la simulacion se imprimen `PC`, las dos instrucciones decodificadas y `dual_issue`. El contador final confirma cuantas emisiones de dos instrucciones fueron observadas.

## Alcance

La segunda via es preliminar, como solicita la E1: aun no hace commit independiente al banco de registros ni resuelve dos operaciones de memoria en el mismo ciclo. Esos elementos pertenecen a la ampliacion completa de E2/EF y deben agregarse si la rubrica completa los exige.

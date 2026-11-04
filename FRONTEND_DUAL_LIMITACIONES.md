# Frontend dual preliminar

El registro del frontend auxiliar sigue el control de IF/ID del pipeline
principal: reset y `FlushD` lo limpian, con prioridad sobre `StallD`, y
`StallD` conserva instrucciones e indicadores. `FlushE` no limpia Decode:
tambien se activa para insertar una burbuja durante un riesgo load-use.
Esta sincronizacion solo alinea la retencion y el descarte, no implementa
emision dual arquitectonica.

- El PC principal avanza una instruccion por ciclo, no por pares. La segunda
  instruccion observada puede aparecer de nuevo como primera en el ciclo siguiente;
  no hay cola ni reintento para una segunda instruccion no emitida.
- La segunda via no escribe resultados ni resuelve dependencias, forwarding,
  memoria o control de flujo entre ciclos. Sus resultados son observacionales.
- El frontend lee palabras crudas en `PC` y `PC+4`; no comparte la alineacion
  ni la descompresion RVC del pipeline principal. Con instrucciones comprimidas,
  sus instrucciones y operandos no representan necesariamente los de Decode.
- `ValidD*` exige una palabra no nula con formato de instruccion de 32 bits
  y PC alineado a palabra; `IssueD1` y `DualIssueD`
  son indicadores de elegibilidad preliminar, no eventos de retiro. Permanecen
  activos durante un stall, por lo que contarlos por ciclo puede duplicarlos.
  `ValidE*` son salidas combinacionales de esa misma etapa, no registros EX;
  no indican que la instruccion haya avanzado durante `FlushE` o `StallD`.
- Para una implementacion dual real hacen falta, entre otros, fetch RVC por
  instruccion, avance y reintento de ambas lanes, arbitraje de control/memoria,
  riesgos y forwarding entre lanes y ciclos, y commit preciso de ambas vias.

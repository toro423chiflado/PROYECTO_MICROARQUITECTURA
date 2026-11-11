# Propuesta de optimizacion para EF

**Pendiente de aprobacion del profesor. No esta implementada en E2.**

## Predictor dinamico de saltos

- Limitacion: el procesador actual resuelve los saltos en EX y descarta instrucciones jovenes cuando el salto se toma. Estos ciclos reducen el aprovechamiento de las dos vias.
- Propuesta: incorporar una tabla indexada por bits del PC con contadores saturados de dos bits para predecir ramas condicionales. Para una prediccion tomada se calcularia el destino a partir del PC y el inmediato de la instruccion. En EX se actualizaria el contador y se corregiria el PC ante una prediccion incorrecta.
- Modulos afectados: fetch y seleccion del PC, registros del pipeline para transportar la prediccion y el PC, y logica de resolucion y limpieza en `e2_pipeline.v`. La integracion y pruebas se harian tambien en `e2_top.v` y sus bancos.
- Metricas: ciclos, instrucciones retiradas, IPC y speedup frente a E2 sin optimizar, con el mismo programa y criterio de inicio y fin. Medir tambien predicciones, aciertos y penalizacion por errores.
- Verificacion: comparar registros y memoria con E2 sin optimizar y ejecutar ramas tomadas y no tomadas en ambas posiciones, incluyendo cambios de comportamiento y recuperacion ante predicciones incorrectas.

El predictor es adicional al manejo de saltos obligatorio en E2. Su posible efecto se evaluara con el programa propio y el programa del profesor; no se presupone que mejore todos los casos.

# Waveforms E2

Los bancos `testbench_e2` y `testbench_e2_control` solo generan un VCD si se
indica `+vcd=RUTA` a `vvp`. Sin ese argumento no generan waveforms. La ruta es
la del entorno donde corre el simulador y su directorio debe existir; cada
ejecucion con la misma ruta sobrescribe el archivo. Se vuelca la jerarquia del
banco; Icarus no incluye automaticamente todas las posiciones de memorias.

## Docker y PowerShell

Desde la raiz del proyecto, con Docker en ejecucion y acceso a la imagen
`hdlc/iverilog`, crear un directorio temporal fuera del repositorio y ejecutar:

```powershell
$waves = Join-Path $env:TEMP ("waveforms-e2-" + [guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $waves | Out-Null
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" --mount "type=bind,source=$waves,target=/waves" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2 -o /tmp/e2 testbench_e2.v e2_top.v e2_pipeline.v regfile.v imem.v dmem.v && vvp /tmp/e2 +vcd=/waves/e2.vcd && test -s /waves/e2.vcd && wc -c /waves/e2.vcd'
docker run --rm --mount "type=bind,source=$($PWD.Path),target=/src,readonly" --mount "type=bind,source=$waves,target=/waves" -w /src --entrypoint sh hdlc/iverilog -c 'iverilog -g2012 -s testbench_e2_control -o /tmp/e2_control testbench_e2_control.v e2_top.v e2_pipeline.v regfile.v imem.v dmem.v && vvp /tmp/e2_control +vcd=/waves/e2_control.vcd && test -s /waves/e2_control.vcd && wc -c /waves/e2_control.vcd'
Get-Item "$waves\*.vcd" | Select-Object FullName, Length
```

Las simulaciones deben mostrar respectivamente `PASS E2: 23 ordered
retirements` y `PASS E2 control: 7 directed integration scenarios`; comprobar
ademas que cada comando Docker termina con codigo cero (`$LASTEXITCODE`).
`test -s` exige que el VCD exista y no este vacio; `wc -c` muestra su tamaño
en bytes. Icarus puede advertir que el archivo de instrucciones contiene menos
palabras que la memoria; los bancos inicializan sus imagenes de prueba.

Los VCD quedan en `$waves` para abrirlos con un visor compatible, por ejemplo
GTKWave. Los ejecutables quedan en `/tmp` del contenedor y desaparecen al
terminar. Para ejecutar sin waveforms, quitar el argumento `+vcd=...` y las
comprobaciones `test -s` y `wc -c` del comando correspondiente. No versionar
los VCD ni otros productos generados; eliminar la carpeta temporal cuando ya
no se necesite.

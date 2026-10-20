# Pochoco SoC & Espino Core

Este repositorio contiene el diseño de un procesador de 32 bits y un System-on-Chip (SoC) implementado en Verilog para ser utilizado en una FPGA.

El proyecto está pensado para trabajar conceptos de Arquitectura de Computadores, como ejecución de instrucciones, memoria, periféricos, registros y comunicación entre distintos módulos del sistema.

![Pochoco SoC Architecture](pochoco_soc.svg)

## Estructura del proyecto

El diseño está dividido principalmente en dos partes: Espino Core y Pochoco SoC.

### Espino Core

Espino Core corresponde al procesador del sistema. Incluye los módulos principales necesarios para ejecutar instrucciones:

- Instruction Fetch
- Instruction Decode
- ALU
- Banco de registros
- Load/Store Unit
- Control del pipeline

El procesador implementa [RV32E](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html).

Actualmente las instrucciones de shift (`SLL`, `SRL`, `SRA`, `SLLI`, `SRLI` y `SRAI`) son decodificadas, pero no están implementadas en la ALU para disminuir el uso de LUTs en la FPGA.

Por este motivo, estas instrucciones deben evitarse en los programas Assembly utilizados actualmente.

### Pochoco SoC

Pochoco SoC es el módulo principal que conecta el procesador con el resto del sistema.

Incluye:

- Memoria RAM compartida para instrucciones y datos
- LEDs de la placa
- Botones
- Displays de 7 segmentos
- Interfaz SPI
- Periféricos mapeados en memoria

## Mapa de memoria

El sistema utiliza distintas direcciones para acceder a la memoria y a los periféricos.

### RAM

Dirección base:

```text
0x0000_0000
```

Esta memoria se utiliza tanto para instrucciones como para datos.

### Periféricos de la placa

Dirección base:

```text
0x8000_0000
```

Offsets disponibles:

| Offset | Periférico |
|---|---|
| `0x00` | Displays de 7 segmentos |
| `0x04` | LEDs |
| `0x08` | Botones |
| `0x0C` | Contador de ciclos |

### SPI

Dirección base:

```text
0x8001_0000
```

Offsets:

| Offset | Función |
|---|---|
| `0x00` | Estado SPI |
| `0x04` | Byte recibido |
| `0x08` | Byte enviado por el procesador |

## Compilación

Para compilar el proyecto es necesario tener instalado el toolchain para FPGA.

Se puede utilizar OSS CAD Suite:

https://github.com/YosysHQ/oss-cad-suite-build

Una vez instaladas las herramientas, desde la carpeta principal del proyecto se puede ejecutar:

```bash
make all
```

Este comando realiza la síntesis, place & route, genera el bitstream y programa la FPGA.

También se puede utilizar:

```bash
make bin
```

para generar el bitstream sin programar la placa.

## Software

La carpeta:

```text
sw/
```

contiene los programas en Assembly que se ejecutan en Espino Core.

Algunos ejemplos son:

```text
blink.s
7seg.s
buttons_leds.s
game.s
```

Estos archivos son ensamblados y convertidos a archivos `.hex`, que posteriormente son cargados en memoria mediante `$readmemh`.

Para compilar uno de los programas se puede utilizar:

```bash
cd sw
make blink
```

Esto genera el archivo:

```text
blink.hex
```

Si el toolchain instalado utiliza un prefijo diferente, este se puede indicar directamente al ejecutar `make`.

Por ejemplo:

```bash
make PREFIX=riscv64-elf- blink
```

También es posible agregar nuevos programas.

Si se crea un archivo:

```text
programa.s
```

se puede compilar con:

```bash
make programa
```

sin necesidad de modificar el `Makefile`.

Al cambiar el programa que se quiere ejecutar también se debe verificar el parámetro `MemFile` utilizado por el SoC.

---

# Proyecto 2: Juego de reflejos

Para el Proyecto 2 se implementó un juego de reflejos utilizando Espino Core y los periféricos disponibles en la Go Board.

El programa principal del juego se encuentra en:

```text
sw/game.s
```

## Comandos principales

| Comando | Función |
|---|---|
| `make hex` | Ensambla `sw/game.s` y genera `sw/game.hex` y `sw/game.lst` |
| `make` | Genera el programa, sintetiza el hardware y programa la Go Board |
| `make bin` | Realiza el proceso de compilación sin programar la FPGA |
| `make sim` | Simula una partida utilizando Icarus Verilog |
| `make test` | Ejecuta las pruebas del assembler |

También se puede generar el archivo `.hex` manualmente utilizando:

```bash
python3 tools/rvasm.py sw/game.s -o sw/game.hex -l sw/game.lst
```

Algunas constantes del programa pueden modificarse desde la línea de comandos sin cambiar directamente el archivo Assembly.

Por ejemplo, para cambiar el tiempo inicial:

```bash
python3 tools/rvasm.py sw/game.s -o sw/game.hex -D ALL_ON_TIME=100000000
make
```

## Cómo se juega

Al encender el sistema, los LEDs realizan una secuencia en carrusel.

Para comenzar una partida se debe presionar cualquiera de los botones.

Cada ronda funciona de la siguiente manera:

1. Los cuatro LEDs se encienden durante aproximadamente 3 segundos.
2. Después queda encendido solamente uno de los LEDs.
3. El jugador debe presionar el botón correspondiente a ese LED.
4. El tiempo de respuesta se muestra en los displays en décimas de segundo.
5. Si se presiona el botón incorrecto, los displays muestran `EE`.
6. Los LEDs parpadean para indicar el error.
7. La ronda se repite hasta obtener una respuesta correcta.
8. Las respuestas correctas anteriores se mantienen.
9. Después de 10 respuestas correctas se calcula el tiempo promedio.
10. El promedio se muestra en los displays.
11. Los LEDs alternan entre `0101` y `1010`.
12. Al presionar nuevamente un botón comienza una nueva partida.

El tiempo máximo mostrado es:

```text
9.9 segundos
```

que aparece en el display como:

```text
99
```

## Cambios realizados al RTL

Para implementar el juego se realizaron algunos cambios y se agregaron módulos al diseño original.

### `rtl/game_top.v`

Este archivo corresponde al top-level utilizado para el juego.

El módulo instancia `pochoco_soc` utilizando:

```text
sw/game.hex
```

como programa cargado inicialmente en memoria.

### `rtl/pochoco_periph.v`

En este módulo se agregó:

- Un contador de ciclos de 32 bits
- Un sincronizador de dos flip-flops para las entradas de los botones

El contador de ciclos se encuentra mapeado en la dirección:

```text
0x8000_000C
```

La FPGA utiliza un reloj de:

```text
25 MHz
```

Por lo tanto:

```text
1 décima de segundo = 2.500.000 ciclos
```

Este contador se utiliza para medir el tiempo de reacción del jugador durante cada ronda.

# Pochoco SoC & Espino Core

> Meet Pochoco SoC and Espino Core. Inspired by the native flora of the Pochoco trails, it is an entry-level, highly efficient architecture designed to flourish in resource-constrained environments.

![Pochoco SoC Architecture](pochoco_soc.svg)

Welcome to the repository! This project contains the RTL for a custom 32-bit processor and its surrounding System-on-Chip (SoC) designed for FPGA deployment. The design is kept straightforward to help explore and understand computer architecture fundamentals.

This is meant to be forked, not just cloned. You'll be poking around the RTL, so make it your own, we won't judge (we might even be a little proud).

## Repository Structure

The hardware is written in Verilog and divided into these main categories:

* **The Espino Core**: The central processing unit. It includes all standard pipeline stages like instruction fetch, instruction decode, an ALU for execution, a register file, a load/store unit for memory operations, and a pipeline controller. It implements [RV32E](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html) with a catch you might want to check out the code for.
* **The Pochoco SoC**: The top-level system wrapper. It connects the CPU core to a unified instruction/data RAM, physical board peripherals (like LEDs, switches, and displays), and an external SPI slave interface.
* **Build Files**: Constraints to map the design to the physical FPGA pins, and automation scripts for synthesis, routing, and flashing using an open-source toolchain.

## Memory Map

The SoC routes memory and data requests using a hardcoded address decoding scheme based on the highest bits of the 32-bit address.

* **`0x0000_0000` - Unified RAM**: The shared memory space for both instructions and data.
* **`0x8000_0000` - Board Peripherals**: Memory-mapped I/O for the physical board.
  * `Offset 0x00`: 7-Segment Displays
  * `Offset 0x04`: LEDs
  * `Offset 0x08`: Button Inputs
* **`0x8001_0000` - SPI Slave**: Custom SPI interface routing.
  * `Offset 0x00`: SPI Status (Chip Select state, New Data flag)
  * `Offset 0x04`: Received "Price" byte (from external master)
  * `Offset 0x08`: "Decision" byte (written by CPU to transmit)

Dive into the source code to see exactly how these components and connections are built under the hood!

## How to Build

To synthesize and build the project, you will need the open-source FPGA toolchain.

1. Install the tools by following the instructions at the [oss-cad-suite-build repository](https://github.com/yosyshq/oss-cad-suite-build).
2. Once installed, ~~blindly copy-paste~~ (we strongly encourage reading the Makefile first to make sure we aren't deleting your home directory) the following command in the project root to generate and program the final bitstream:

```bash
make all
```

## Software

The `sw/` folder holds the RV32E assembly example programs that run on the Espino Core (`blink.s`, `7seg.s`, `buttons_leds.s`), plus a `Makefile` to assemble them into the `.hex` files the RTL loads at boot via `$readmemh`.

You'll need a RISC-V toolchain on your `PATH` (`riscv64-unknown-elf-{as,ld,objcopy}` on Debian/Ubuntu/WSL via `sudo apt install gcc-riscv64-unknown-elf`, or `brew install riscv64-unknown-elf-gcc` on macOS). If your toolchain uses a different prefix, override it on the command line rather than editing the Makefile:

```bash
cd sw
make blink                        # assembles blink.s -> blink.hex
make PREFIX=riscv64-elf- blink    # if your toolchain uses a different prefix
```

Drop a new `<name>.s` file in `sw/` and `make <name>` picks it up automatically, no `Makefile` changes needed. Don't forget to change the MemFile in pochoco_soc.v.

**CATCH:** The core implements [RV32E](https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html), with one thing worth knowing: shift instructions (`SLL`/`SRL`/`SRA`/`SLLI`/`SRLI`/`SRAI`) are decoded correctly but disabled in the ALU to save LUTs on the target FPGA, so they currently execute as `ADD` instead. Avoid shifts in your assembly, or design your own shifter...

---

## Proyecto 2: Juego de reflejos

### Cómo usar

| Comando | Qué hace |
|---|---|
| `make hex` | Ensambla `sw/game.s` → `sw/game.hex` (y `sw/game.lst`) con **nuestro** assembler |
| `make` | `hex` + síntesis + place & route + bitstream + programa la Go Board |
| `make bin` | Igual que `make` pero sin programar |
| `make sim` | Simula una partida completa (Icarus Verilog) |
| `make test` | Pruebas del assembler |

Regenerar el hex a mano:

```bash
python3 tools/rvasm.py sw/game.s -o sw/game.hex -l sw/game.lst
```

Cambiar una constante sin editar el fuente (por ejemplo, 4 s de fase inicial en vez de 3):

```bash
python3 tools/rvasm.py sw/game.s -o sw/game.hex -D ALL_ON_TIME=100000000
make
```

### Cómo se juega

1. Al encender, los LEDs giran en carrusel: presiona cualquier botón para empezar.
2. Cada ronda: los 4 LEDs se encienden 3,0 s, luego queda solo el LED objetivo.
3. Presiona el botón bajo ese LED. El display muestra el tiempo en décimas de segundo (máximo 9,9 s → `99`).
4. Botón incorrecto: el display muestra `EE`, los LEDs parpadean y se repite la ronda (las correctas se conservan).
5. Tras 10 respuestas correctas se muestra el promedio y los LEDs alternan `0101`/`1010`. Presiona un botón para jugar de nuevo.

### Cambios al RTL

* `rtl/game_top.v`: top-level que instancia `pochoco_soc` con `MemFile = "sw/game.hex"`.
* `rtl/pochoco_periph.v`: contador de ciclos de 32 bits en `0x8000_000C` y sincronizador de 2 FF para los botones.

Reloj: 25 MHz → 1 décima = 2.500.000 ciclos.

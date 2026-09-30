# Copyright 2026 Universidad de los Andes.
# Licensed under the Solderpad Hardware License, Version 0.51 (the "License");
# SPDX-License-Identifier: SHL-0.51
#
# Proyecto 2: top-level game_top + juego de reflejos (sw/game.s)
#
#   make hex    -> ensambla sw/game.s en sw/game.hex con NUESTRO assembler
#   make        -> hex + sintesis + place&route + bitstream + programar la Go Board
#   make bin    -> igual pero sin programar
#   make sim    -> simula una partida completa con Icarus Verilog
#   make test   -> pruebas del assembler

# Configuration
TOP  := game_top
PCF  := goboard.pcf
FREQ := 25

PYTHON ?= python3
ASM    := $(PYTHON) tools/rvasm.py
GAME_S := sw/game.s
GAME_H := sw/game.hex

# RTL Sources
SRC  := $(wildcard ./rtl/*.v ./rtl/**/*.v)

# Build Targets
JSON := $(TOP).json
ASC  := $(TOP).asc
BIN  := $(TOP).bin

.PHONY: all prog bin hex sim test clean

# Default target
all: prog

# Step 0: assembly -> hex con el assembler del grupo
hex: $(GAME_H)
$(GAME_H): $(GAME_S) tools/rvasm.py
	$(ASM) $(GAME_S) -o $(GAME_H) -l sw/game.lst

# Step 1: Synthesis using Yosys (el hex se incrusta en la BRAM via $$readmemh)
$(JSON): $(SRC) $(GAME_H)
	yosys -p "read_verilog $(SRC); synth_ice40 -top $(TOP) -json $(JSON); stat"

# Step 2: Place and Route using NextPNR
$(ASC): $(JSON) $(PCF)
	nextpnr-ice40 --hx1k --package vq100 --freq $(FREQ) --json $(JSON) --pcf $(PCF) --asc $(ASC)

# Step 3: Bitstream Generation
$(BIN): $(ASC)
	icepack $(ASC) $(BIN)
bin: $(BIN)

# Step 4: Flash the Board
prog: $(BIN)
	iceprog $(BIN)

# Simulacion: reloj ficticio de 20 kHz para que 3 s = 60.000 ciclos
CELLS := $(shell yosys-config --datdir 2>/dev/null)/ice40/cells_sim.v
sim:
	$(ASM) $(GAME_S) -D CLK_HZ=20000 -o sim/game_sim.hex
	iverilog -g2012 -o sim/tb_game.vvp sim/tb_game.v $(SRC) $(CELLS)
	vvp -n sim/tb_game.vvp

test:
	$(PYTHON) tools/test_rvasm.py

# Clean up generated files
clean:
	rm -f $(JSON) $(ASC) $(BIN) sim/*.vvp sim/*.vcd sim/game_sim.hex

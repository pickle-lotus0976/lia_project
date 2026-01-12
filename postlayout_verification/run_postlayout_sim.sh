#!/bin/bash

echo "=========================================="
echo "LIA Post-Layout Simulation"
echo "=========================================="

# Check if PDK_ROOT is set
if [ -z "$PDK_ROOT" ]; then
    echo "ERROR: PDK_ROOT not set!"
    echo "Run: export PDK_ROOT=/path/to/your/pdk"
    exit 1
fi

echo "PDK location: $PDK_ROOT"

# Compile with Icarus Verilog
echo ""
echo "Step 1: Compiling gate-level netlist..."
iverilog -o postlayout_sim.vvp \
  -DFUNCTIONAL \
  -DSIM \
  -DUNIT_DELAY=#1 \
  -I $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog \
  $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog/primitives.v \
  $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v \
  lia_digital_core.nl.v \
  lia_postlayout_tb.v

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed!"
    exit 1
fi

echo "Compilation successful!"

# Run simulation
echo ""
echo "Step 2: Running simulation..."
echo "(This will take 2-5 minutes)"
echo ""

vvp postlayout_sim.vvp

if [ $? -ne 0 ]; then
    echo "ERROR: Simulation failed!"
    exit 1
fi

echo ""
echo "=========================================="
echo "Simulation Complete!"
echo "Check postlayout_iq_data.txt for results"
echo "=========================================="

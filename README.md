# Digital Lock-In Amplifier (LIA) Core

A synthesizable digital lock-in amplifier core written in Verilog for the SkyWater 130nm process. The design demodulates a 12-bit signed input signal using internally generated quadrature reference signals.

## System Specifications

* **Process**: SkyWater 130nm (`sky130_fd_sc_hd`)
* **Input**: 12-bit signed ADC data
* **Reference**: 12-bit internal NCO (Sine/Cosine)
* **Output**: 24-bit signed mixed data (I and Q channels)
* **Clock Target**: 50 MHz (20ns period)
* **Area**: 640µm × 640µm

## Architecture

The core (`lia_digital_core`) consists of two primary subsystems:

1.  **NCO (`nco_with_lut`)**:
    * **Method**: Direct Digital Synthesis (DDS) using a 32-bit phase accumulator.
    * **Storage**: 256-entry × 12-bit signed Sine LUT.
    * **Quadrature**: Generates Cosine by offsetting the Sine address by 64 (90°).

2.  **Dual Mixers (`lia_mixer`)**:
    * **Operation**: Multiplies ADC input with NCO sine (In-phase) and cosine (Quadrature).
    * **Pipelining**: Includes input/output registering and hold-time buffering to ensure valid signal synchronization.

## Interface

| Signal | Width | Type | Description |
| :--- | :--- | :--- | :--- |
| `clk`, `rst_n` | 1 | Input | System clock and active-low reset |
| `adc_data` | 12 | Input | Signed ADC samples |
| `adc_valid` | 1 | Input | Data validity strobe |
| `phase_increment` | 32 | Input | Frequency control word for NCO |
| `mixer_i_out` | 24 | Output | In-phase demodulated output |
| `mixer_q_out` | 24 | Output | Quadrature demodulated output |
| `mixer_valid` | 1 | Output | Output validity strobe |

## Verification

The testbench (`lia_digital_core_tb.v`) verifies functional correctness:

* **Stimulus**: 100 MHz clock, 10 kHz synthetic sine wave input.
* **Checks**:
    * Verifies lockstep synchronization between I/Q channels.
    * Monitors for arithmetic overflow in the 24-bit output.
    * Ensures atomic output capture.
* **Output**: Writes `lia_output.txt` for external analysis.

## Physical Implementation

Designed for the **OpenLane** flow with the following constraints:

* **Utilization**: 42% core density target.
* **Layers**: Metal 1 through Metal 5.
* **Timing**:
    * Max Fanout: 8.
    * Output Load: 0.10 pF.
    * Antenna Repair: Iterative diode insertion enabled.

## Directory Layout

* `rtl/`: Verilog source and memory files (`.mem`).
* `tb/`: Simulation testbenches.
* `constraints/`: SDC timing constraints and pin configurations.
* `config.json`: OpenLane configuration file.


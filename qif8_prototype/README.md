# QIF8 — Event-driven phase-domain QIF RTL prototype

**Research starter, not a complete scientific-ML QIF accelerator.**

This module implements one event-driven QIF neuron PE and an 8-bit nonlinear phase-transition lookup from Wan et al., *From LIF to QIF: Toward Differentiable Spiking Neurons for Scientific Machine Learning*, arXiv:2511.06614v1, Eq. (6)–(10). This is **not** the piecewise-linear IQIF (2021) neuron.

## Contents
- `rtl/qif_h8_rom.sv`: 8-bit input phase × signed 8-bit weight lookup, 8-bit phase output
- `rtl/qif8_pe.sv`: single-neuron synaptic and autonomous firing event state machine
- `tools/generate_rom.py`: deterministic ROM generator (65536 entries)
- `tools/check_model.py`: functional reference and exhaustive ROM check
- `tb/tb_qif8_pe.sv`: simulation testbench
- `Makefile`: local build targets

## Numerical formats
- Circular phase: unsigned 8-bit bin index (0–255).
- Weights: signed 8-bit Q4.4 (real weight = integer / 16).
- Absolute timestamps: unsigned 24 bits in model ticks.
- 256 ticks per spontaneous firing period; I0=1.25, tau_m=1, so physical period is pi.
- Lookup is generated offline using Python double precision, with phase-bin midpoint evaluation and floor quantization.
- This discretization does **not** preserve exact gradient differentiability.
- Timestamp adders have guard bits; this is **not** an entirely 8-bit system.

## Running from this subdirectory

```bash
make check
make sim  # requires iverilog and vvp
```

The generated `rtl/qif_h8.mem` is intentionally **not tracked**. Run `make rom` before using the ROM. The ROM filename resolves relative to the working directory; run `make` from inside `qif8_prototype/` as shown above.

## Execution contract
A network scheduler must process a predicted firing before a later synaptic input. The PE accepts one event per clock:
1. `syn_valid` at time `syn_time` strictly before `next_spike_time` advances phase and applies `H_w`.
2. `fire_valid` at exactly `next_spike_time` emits a spike and schedules the next autonomous firing.

Re-scheduling, fanout, coincident spikes, and event invalidation are not handled by this single-neuron PE.

## Limitations
No network event scheduler, pseudospike computation, gradient/backpropagation, network SRAM, DeepONet/PINN or paired-timestamp regression output. The 64 KiB combinational ROM is an accuracy baseline, not an area-optimized implementation. Python functional checks passed in the original environment; HDL simulation and FPGA/ASIC PPA have **not** been verified.

## Next steps
Add an event priority scheduler and timestamp-difference output, then test quantized accuracy on parabola/Poisson. Compare segmented LUT, PWL and CORDIC nonlinear blocks, and extend to INT4/FP4/FP8/Posit8 with well-defined rounding/format conversion.

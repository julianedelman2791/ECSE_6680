# Quick-Start Guide & Repository Summary

## Overview
This repository accompanies the report _Matched Filter Design and Simulation_. It explains the purpose of each file and provides exact steps to:
- Reproduce the MATLAB reference results
- Synthesize the design in Quartus Prime
- Run the RTL simulation in ModelSim

## File Structure
- **ECSE_6680_MATCHED_FILTER.pdf**  
  Final report: theory, MATLAB design, Verilog RTL, and results.
- **matched_filter.v**  
  Verilog-2001 RTL — 250-tap shift register, parallel complex multipliers, pipelined adder tree.
- **matched_filter_tb.v**  
  Test-bench — reads binary vectors, drives DUT, writes `sim_io.txt`.
- **rte_viewer.pdf**  
  Quartus Prime RTL viewer snapshot and resource-usage summary.
- **MATLAB_Design/**  
  Folder containing MATLAB scripts and generated data:
  - `matched_filter_design.m` — generate chirp, add noise, decimate, design/apply matched filter.
  - `comparison.m` — align and compare ModelSim output vs. MATLAB reference (RMSE, Pearson _R_).
  - `simulation_results.m` — produce plots and print summary metrics.
  - Binary text files: coefficient and input vectors in Q1.15 format.
  - `sim_io.txt` — ModelSim dump: cycle, ℜ/ℑ in, ℜ/ℑ out.

## Step-by-Step Instructions

### 1. MATLAB Reference Flow
1. **Change directory** to the design folder:
   ```bash
   cd MATLAB_Design
2. **Generate test vectors and ideal output:
   ```bash
   matched_filter_design    % exports *_bin.txt and runs ideal filter
3. **Compare hardware vs. reference (once ModelSim has produced sim_io.txt):
   ```bash
   comparison               % aligns, prints RMSE and Pearson R
   simulation_results       % recreates comparison plots

### 2. Quartus Prime Synthesis
Run the following Tcl commands in the Quartus console (or a shell):
```bash
quartus_map  --read_settings_files=on --write_settings_files=off matched_filter -c matched_filter
quartus_fit  matched_filter -c matched_filter
quartus_asm  matched_filter -c matched_filter
```
After compilation, open `rte_viewer.pdf` to inspect the RTL diagram and resource utilisation.

### 3. ModelSim Simulation
```bash
# Compile RTL and testbench
vlog matched_filter.v matched_filter_tb.v

# Launch simulation
vsim work.matched_filter_tb

# ModelSim prompt
run 10us   # processes all 499 samples
exit       # writes sim_io.txt
```
The test-bench automatically reads the binary coefficient and input files, then dumps the DUT output to `sim_io.txt`.

## Key Numerical Results
| Metric (499 samples)       | Raw    | Aligned |
|----------------------------|-------:|--------:|
| **RMSE (LSB, Q1.15)**      | 625.77 | 625.74  |
| **Pearson _R_**            | 0.21   | 0.77    |

_Alignment compensates the 13-cycle pipeline latency; residual error is dominated by fixed-point quantisation (≈2% of full-scale)._








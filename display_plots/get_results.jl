using CSV
using DataFrames
using JuMP
using MacroEnergy

#import MacroEnergy: write_co2_cap_duals
system = systems[1]

# ---- Base directory (fixed) ----
const BASE = "/Users/abbie/MacroEnergy-Abbie.jl/MacroEnergyExamples/examples/multisector_3zone"

# ---- Function to build paths ----
make_path(parts...) = joinpath(BASE, parts...)

# ---- Results directory ----
results_dir = make_path("results_001", "results")

print("Adding CO2 cap duals now")

# This will create co2_cap_duals.csv in the results_dir
MacroEnergy.write_co2_cap_duals(results_dir, system)

println("CSV written to: ", joinpath(results_dir, "co2_cap_duals.csv"))
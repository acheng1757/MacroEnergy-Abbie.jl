using CSV
using DataFrames
using JuMP
using MacroEnergy

import MacroEnergy: id, find_node, all_constraints_types, get_constraint_by_type, constraint_ref
system = systems[1]

# ---- Results directory ----
const BASE = "/Users/abbie/MacroEnergy-Abbie.jl/MacroEnergyExamples/dolphyn_conversion/SE_power"
make_path(parts...) = joinpath(BASE, parts...)
results_dir = make_path("results_001", "results")

print("Adding CO2 cap duals now")

# This will create co2_cap_duals.csv in the results_dir
MacroEnergy.write_co2_cap_duals(results_dir, system)
println("CSV written to: ", joinpath(results_dir, "co2_cap_duals.csv"))

# This will create co2_cap_duals.csv in the results_dir
MacroEnergy.write_balance_duals(results_dir, system)
println("CSV written to: ", joinpath(results_dir, "balance_duals.csv"))

# Get the non served energy for each of the demand nodes
locations_vector = system.locations
node_ids = [id(n) for n in locations_vector if n isa Node]
node_ids = [id(n) for n in locations_vector if n isa Node]

nse_dict = Dict{Symbol, Vector{Float64}}()

for node_id in node_ids
    node = find_node(system.locations, node_id)
    constraints_list = all_constraints_types(node)

    if MaxNonServedDemandConstraint in constraints_list
        println("MaxNonServedDemandConstraint is in ", node_id)
        nse_constraint_container = get_constraint_by_type(node, MaxNonServedDemandConstraint);
        nse_constraint = constraint_ref(nse_constraint_container);
        nse_value = vec(transpose(value.(nse_constraint).data))

        nse_dict[Symbol(node_id)] = nse_value
    end
end

nse_df = DataFrame(nse_dict)
nse_df.time = 1:nrow(nse_df)
nse_df = select(nse_df, :time, Not(:time))  # Move :time to front

file_path = joinpath(results_dir, "nse.csv")
CSV.write(file_path, nse_df)
println("CSV written to: ", joinpath(results_dir, "nse.csv"))

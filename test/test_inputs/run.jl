using MacroEnergy
using Gurobi

println()

system = MacroEnergy.load_system(@__DIR__)
model = MacroEnergy.generate_model(system)
MacroEnergy.set_optimizer(model, Gurobi.Optimizer)
MacroEnergy.optimize!(model)
macro_objval = MacroEnergy.objective_value(model)
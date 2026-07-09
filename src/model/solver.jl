####### Entry point: dispatch on ExpansionHorizon then SolutionAlgorithm #######
function solve_case(case::Case, opt::O) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    solve_case(case, opt, expansion_horizon(case))
end

####### Perfect foresight: generate a single model + optimize! #######
function solve_case(case::Case, opt::O, ::PerfectForesight) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    alg = solution_algorithm(case)

    @info("*** Running simulation with Perfect Foresight expansion horizon and $(nameof(typeof(alg))) solution algorithm ***")

    # For Perfect Foresight, we generate a single model for the entire case (planning periods) and solve it once
    # generate_model will dispatch on the solution algorithm (e.g., Monolithic or Benders) to generate the appropriate model structure
    model = generate_model(case, opt, alg)

    optimize!(model)
    check_termination_status(model)

    return (case, model)
end

####### Myopic: one model for each period, capacity carry-over, and outputs #######
function solve_case(case::Case, opt::O, ::Myopic) where O <: Union{Optimizer, Dict{Symbol, Dict{Symbol, Any}}}
    alg = solution_algorithm(case)

    @info("*** Running simulation with Myopic expansion horizon and $(nameof(typeof(alg))) solution algorithm ***")

    periods = get_periods(case)
    settings = get_settings(case)
    myopic_settings = settings.MyopicSettings
    return_results = myopic_settings[:ReturnModels]

     # Output path for writing results during iteration
    output_path = create_output_path(case.systems[1])

    # Only allocate models vector if returning models is requested
    stored = return_results ? Vector{Any}(undef, length(periods)) : nothing

    if myopic_settings[:Restart][:enabled]
        if myopic_settings[:Restart][:from_period] == 1
            @warn("Restarting from the first period; no previous period to load, proceeding with normal iteration.")
        else
            restart_folder = joinpath(case.systems[1].data_dirpath, myopic_settings[:Restart][:folder])
            restart_period_idx = myopic_settings[:Restart][:from_period]
            @info("Restarting myopic iteration from period $(restart_period_idx) using capacities in $(restart_folder)")
            capacity_results = Dict{Int,DataFrame}()
            for period_idx in 1:restart_period_idx-1
                capacity_results[period_idx] = load_previous_capacity_results(
                    joinpath(restart_folder, "results_period_$(period_idx)", "capacity.csv")
                )
            end
            carry_over_capacities!(periods[restart_period_idx], capacity_results, restart_period_idx-1, parameter_scaling_factor(settings))
        end
    end

    for (period_idx, system) in enumerate(periods)
        myopic_settings[:Restart][:enabled] && (period_idx < myopic_settings[:Restart][:from_period]) && continue

        if period_idx > myopic_settings[:StopAfterPeriod]
            @info("Reached specified period termination at period $(myopic_settings[:StopAfterPeriod]). Ending myopic iteration.")
            break
        end

        # generate_model will dispatch on the solution algorithm (e.g., Monolithic or Benders) to generate the appropriate model structure for this period
        model = generate_model(system, opt, settings, alg)

        optimize!(model)
        check_termination_status(model)

        period_idx < length(periods) && carry_over_capacities!(periods[period_idx+1], system, perfect_foresight=false)

        write_outputs(output_path, case, model, system, period_idx)

        return_results ? (stored[period_idx] = model) : (model = nothing; GC.gc())
    end

    write_settings(case, joinpath(output_path, "settings.json"))

    return (case, MyopicResults(stored,output_path))
end

####### optimize! for BendersModel #######
function JuMP.optimize!(bm::BendersModel)
    # call MESolvers.jl to solve the Benders decomposition problem
    raw = MacroEnergySolvers.benders(
        bm.planning_problem, bm.subproblems, bm.linking_variables_sub, Dict(pairs(bm.settings))
    )

    # update case or system with the best planning solution found by Benders
    update_with_planning_solution!(bm.update_target, raw.planning_sol.values)

    @info "Perform a final solve of the subproblems to extract the operational decisions corresponding to the best planning solution."
    bm.planning_sol = raw.planning_sol
    bm.subop_sol = MacroEnergySolvers.solve_subproblems(bm.subproblems, raw.planning_sol, true)

    bm.convergence = BendersConvergence(raw)
end

"""
    ensure_duals_available!(model::Model)

Ensure that dual values are available in the model. If the model has integer variables
and duals are not available, fixes the integer variables and re-solves the LP model to 
compute duals.

# Arguments
- `model::Model`: The JuMP model to ensure duals for

# Throws
- `ErrorException`: If the model is not solved and feasible or if the dual values are not 
available after linearization

# Notes
- This function modifies the model in-place by fixing integer and binary variables to their 
current values.
- The model is solved again in silent mode to avoid redundant output
"""
function ensure_duals_available!(model::Model)
    if has_duals(model)
        @debug "Dual values available in the model"
        return nothing
    end

    assert_is_solved_and_feasible(model)
    
    @info "Dual values not available in the model. Linearizing model and re-solving to compute duals."
    
    # Fix integer and binary variables to their current values
    fix_discrete_variables(model);
    
    # Re-solve the LP model
    optimize!(model)
    
    # Verify that duals are now available
    assert_is_solved_and_feasible(model)
    if dual_status(model) != MOI.FEASIBLE_POINT
        error("Model is not feasible after linearization.")
    end
    
    @info "Linearization successful, dual values now available."

    return nothing
end

"""
    check_termination_status(model::Model)

Log the model's solve status. If the solve did not produce a usable solution
(infeasible, unbounded, or a numerical failure that prevented a solution being
found), attempt to diagnose the cause by computing an IIS via [`find_iis`](@ref),
then throw an error rather than letting the caller proceed to post-processing
with no solution available.
"""
function check_termination_status(model::Model)
    status = termination_status(model)

    if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED
        return status
    end

    @error "Model did not solve to optimality. Termination status: $status"

    if status in (
        MOI.INFEASIBLE,
        MOI.INFEASIBLE_OR_UNBOUNDED,
        MOI.DUAL_INFEASIBLE,
        MOI.NUMERICAL_ERROR,
        MOI.OTHER_ERROR,
    )
        find_iis(model)
        status = termination_status(model)
    end

    if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED
        @info "Model solved successfully after retry (termination status: $status)."
        return status
    end

    if !has_values(model)
        error("Solve did not produce a usable solution (termination status: $status). Aborting before post-processing.")
    end

    @warn "Proceeding with a non-optimal solution (termination status: $status)."
    return status
end

"""
    find_iis(model::Model)

Diagnose an infeasible model by computing an Irreducible Infeasible Subsystem (IIS)
via the solver's conflict refiner. Only supported for Gurobi-backed models: JuMP's
conflict computation (`compute_conflict!`) is not supported by HiGHS.

If the termination status is not a certified `INFEASIBLE` (e.g. `NUMERICAL_ERROR`),
first retries the solve with Gurobi's homogeneous barrier algorithm (`BarHomogeneous
= 1`), which is more robust to the numerical trouble that produces false
"infeasible-or-unbounded" results. If that retry solves the model, the original
failure was numerical rather than a true infeasibility, and no IIS is computed.

Prints the constraints found to be in conflict and returns them, or `nothing` if no
IIS could be computed.
"""
function find_iis(model::Model)
    if !occursin("Gurobi", solver_name(model))
        @warn "IIS computation is only supported for Gurobi-backed models (current solver: $(solver_name(model))). Re-run with Gurobi.Optimizer to diagnose infeasibility."
        return nothing
    end

    status = termination_status(model)
    if status != MOI.INFEASIBLE
        @info "Termination status is $status, not a certified INFEASIBLE. Retrying with Gurobi's homogeneous barrier algorithm (BarHomogeneous=1) to rule out numerical trouble before computing an IIS..."
        try
            set_optimizer_attribute(model, "BarHomogeneous", 1)
            optimize!(model)
        catch e
            @warn "Failed to re-solve with BarHomogeneous=1: $e"
        end

        status = termination_status(model)
        @info "Termination status after BarHomogeneous retry: $status"

        if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED
            @info "Model solved successfully with BarHomogeneous=1. The original failure was numerical, not a true infeasibility. Consider adding \"BarHomogeneous\" => 1 to your optimizer_attributes."
            return nothing
        end
    end

    @info "Computing IIS to diagnose infeasibility..."
    try
        compute_conflict!(model)
    catch e
        @warn "Gurobi failed to compute an IIS for this model (it may not have been able to certify infeasibility): $e"
        return nothing
    end

    if get_attribute(model, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        @warn "Gurobi could not find a conflict (IIS) for this model."
        return nothing
    end

    conflict_constraints = ConstraintRef[]
    for (F, S) in list_of_constraint_types(model)
        for con in all_constraints(model, F, S)
            if MOI.get(model, MOI.ConstraintConflictStatus(), con) == MOI.IN_CONFLICT
                push!(conflict_constraints, con)
            end
        end
    end

    @info "IIS found: $(length(conflict_constraints)) constraint(s) in conflict:"
    for con in conflict_constraints
        println(con)
    end

    return conflict_constraints
end
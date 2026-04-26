struct SyntheticEthylene <: AbstractAsset
    id::AssetId
    synthetic_ethylene_transform::Transformation
    co2_captured_edge::Edge{<:CO2Captured}
    elec_consumption_edge::Edge{<:Electricity}
    h2_consumption_edge::Edge{<:Hydrogen}
    natgas_production_edge::Edge{<:NaturalGas}
    gasoline_production_edge::Edge{<:LiquidFuels}
    ethylene_production_edge::Edge{<:Ethylene}
    co2_emission_edge::Edge{<:CO2}
end

function default_data(t::Type{SyntheticEthylene}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{SyntheticEthylene}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "CO2Captured",
            :ethylene_production => 0.0,
            :gasoline_production => 0.0,
            :natgas_production => 0.0,
            :h2_consumption => 0.0,
            :elec_consumption => 0.0,
            :emission_rate => 1.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true
                ),
            ),
            :gasoline_production_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :h2_consumption_edge => @edge_data(
                :commodity => "Hydrogen",
            ),
            :ethylene_production_edge => @edge_data(
                :commodity => "Ethylene",
            ),
            :natgas_production_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{SyntheticEthylene}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :gasoline_commodity => "LiquidFuels",
        :gasoline_production => 0.0,
        :h2_consumption => 0.0,
        :elec_consumption => 0.0,
        :natgas_production => 0.0,
        :ethylene_production => 0.0,
        :emission_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{SyntheticEthylene}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # transformation
    synthetic_ethylene_transform_key = :transforms
    @process_data(
        transform_data,
        data[synthetic_ethylene_transform_key],
        [
            (data[synthetic_ethylene_transform_key], key),
            (data[synthetic_ethylene_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    synthetic_ethylene_transform = Transformation(;
        id = Symbol(id, "_", synthetic_ethylene_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # co2 captured input edge
    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data,
        data[:edges][co2_captured_edge_key],
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
            (data, key),
        ]
    )
    @start_vertex(
        co2_captured_start_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :start_vertex), (data, :location)],
    )
    co2_captured_end_node = synthetic_ethylene_transform
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

    # gasoline production edge
    gasoline_production_edge_key = :gasoline_production_edge
    @process_data(
        gasoline_production_edge_data,
        data[:edges][gasoline_production_edge_key],
        [
            (data[:edges][gasoline_production_edge_key], key),
            (data[:edges][gasoline_production_edge_key], Symbol("gasoline_production_", key)),
            (data, Symbol("gasoline_production_", key)),
        ]
    )
    commodity_symbol = Symbol(gasoline_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    gasoline_production_start_node = synthetic_ethylene_transform
    @end_vertex(
        gasoline_production_end_node,
        gasoline_production_edge_data,
        commodity,
        [(gasoline_production_edge_data, :end_vertex), (data, :location)],
    )
    gasoline_production_edge = Edge(
        Symbol(id, "_", gasoline_production_edge_key),
        gasoline_production_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gasoline_production_start_node,
        gasoline_production_end_node,
    )

    # natgas production edge (in the form of methane)
    natgas_production_edge_key = :natgas_production_edge
    @process_data(
        natgas_production_edge_data, 
        data[:edges][natgas_production_edge_key], 
        [
            (data[:edges][natgas_production_edge_key], key),
            (data[:edges][natgas_production_edge_key], Symbol("natgas_production_", key)),
            (data, Symbol("natgas_production_", key)),
            (data, key), 
        ]
    )
    natgas_production_start_node = synthetic_ethylene_transform
    @end_vertex(
        natgas_production_end_node,
        natgas_production_edge_data,
        NaturalGas,
        [(natgas_production_edge_data, :end_vertex), (data, :location)],
    )
    natgas_production_edge = Edge(
        Symbol(id, "_", natgas_production_edge_key),
        natgas_production_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_production_start_node,
        natgas_production_end_node,
    )

    # ethylene production edge
    ethylene_production_edge_key = :ethylene_production_edge
    @process_data(
        ethylene_production_edge_data, 
        data[:edges][ethylene_production_edge_key], 
        [
            (data[:edges][ethylene_production_edge_key], key),
            (data[:edges][ethylene_production_edge_key], Symbol("ethylene_production_", key)),
            (data, Symbol("ethylene_production_", key)),
            (data, key), 
        ]
    )
    ethylene_production_start_node = synthetic_ethylene_transform
    @end_vertex(
        ethylene_production_end_node,
        ethylene_production_edge_data,
        Ethylene,
        [(ethylene_production_edge_data, :end_vertex), (data, :location)],
    )
    ethylene_production_edge = Edge(
        Symbol(id, "_", ethylene_production_edge_key),
        ethylene_production_edge_data,
        system.time_data[:Ethylene],
        Ethylene,
        ethylene_production_start_node,
        ethylene_production_end_node,
    )

    # elec consumption edge
    elec_consumption_edge_key = :elec_consumption_edge
    @process_data(
        elec_consumption_edge_data,
        data[:edges][elec_consumption_edge_key],
        [
            (data[:edges][elec_consumption_edge_key], key),
            (data[:edges][elec_consumption_edge_key], Symbol("elec_consumption_", key)),
            (data, Symbol("elec_consumption_", key)),
        ]
    )
    @start_vertex(
        elec_consumption_start_node,
        elec_consumption_edge_data,
        Electricity,
        [(elec_consumption_edge_data, :start_vertex), (data, :location)],
    )
    elec_consumption_end_node = synthetic_ethylene_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_consumption_start_node,
        elec_consumption_end_node,
    )

    # h2 consumption edge
    h2_consumption_edge_key = :h2_consumption_edge
    @process_data(
        h2_consumption_edge_data,
        data[:edges][h2_consumption_edge_key],
        [
            (data[:edges][h2_consumption_edge_key], key),
            (data[:edges][h2_consumption_edge_key], Symbol("h2_consumption_", key)),
            (data, Symbol("h2_consumption_", key)),
        ]
    )
    @start_vertex(
        h2_consumption_start_node,
        h2_consumption_edge_data,
        Hydrogen,
        [(h2_consumption_edge_data, :start_vertex), (data, :location)],
    )
    h2_consumption_end_node = synthetic_ethylene_transform
    h2_consumption_edge = Edge(
        Symbol(id, "_", h2_consumption_edge_key),
        h2_consumption_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_consumption_start_node,
        h2_consumption_end_node,
    )

    # co2 emission output edge
    co2_emission_edge_key = :co2_emission_edge
    @process_data(
        co2_emission_edge_data,
        data[:edges][co2_emission_edge_key],
        [
            (data[:edges][co2_emission_edge_key], key),
            (data[:edges][co2_emission_edge_key], Symbol("co2_emission_", key)),
            (data, Symbol("co2_emission_", key)),
        ]
    )
    co2_emission_start_node = synthetic_ethylene_transform
    @end_vertex(
        co2_emission_end_node,
        co2_emission_edge_data,
        CO2,
        [(co2_emission_edge_data, :end_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_emission_edge = Edge(
        Symbol(id, "_", co2_emission_edge_key),
        co2_emission_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_emission_start_node,
        co2_emission_end_node,
    )

    synthetic_ethylene_transform.balance_data = Dict(
        :gasoline_production => Dict(
            gasoline_production_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :gasoline_production, 0.0)
        ),
        :ethylene_production => Dict(
            ethylene_production_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :ethylene_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :elec_consumption, 0.0)
        ),
        :h2_consumption => Dict(
            h2_consumption_edge.id => -1.0,
            co2_captured_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),
        :natgas_production => Dict(
            natgas_production_edge.id => 1.0,
            co2_captured_edge.id => get(transform_data, :natgas_production, 0.0)
        ),
        :emissions => Dict(
            co2_captured_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        )
    )

    return SyntheticEthylene(id, synthetic_ethylene_transform, co2_captured_edge,elec_consumption_edge,h2_consumption_edge,natgas_production_edge,gasoline_production_edge,ethylene_production_edge, co2_emission_edge) 
end
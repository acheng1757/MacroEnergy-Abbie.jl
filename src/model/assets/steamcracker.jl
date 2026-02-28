# steam cracker asset, which includes all thermal steam crackers + electrified steam crackers
# all asset parameters are per MWh ethane, normalizded by the primary feedstock
struct SteamCracker <: AbstractAsset
    id::AssetId
    steamcracker_transform::Transformation
    elec_consumption_edge::Edge{<:Electricity}
    h2_consumption_edge::Edge{<:Hydrogen}
    h2_production_edge::Edge{<:Hydrogen}
    natgas_consumption_edge::Edge{<:NaturalGas}
    natgas_production_edge::Edge{<:NaturalGas}
    ethane_consumption_edge::Edge{<:Ethane}
    ethylene_production_edge::Edge{<:Ethylene}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{SteamCracker}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{SteamCracker}, id=missing)
    return Dict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Ethylene",
            :elec_consumption => 0.0,
            :h2_production => 0.0,
            :h2_consumption => 0.0,
            :natgas_consumption => 0.0,
            :natgas_production => 0.0,
            :ethylene_production => 0.0,
            :emission_rate => 0.0,
            :capture_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity"
            ),
            :h2_consumption_edge => @edge_data(
                :commodity => "Hydrogen"
            ),
            :h2_production_edge => @edge_data(
                :commodity => "Hydrogen"
            ),
            :natgas_consumption_edge => @edge_data(
                :commodity => "NaturalGas"
            ),
            :natgas_production_edge => @edge_data(
                :commodity => "NaturalGas"
            ),
            :ethylene_production_edge => @edge_data(
                :commodity => "Ethylene"
            ),
            :ethane_consumption_edge => @edge_data(
                :commodity=>"Ethane",
                :has_capacity => true,
                :can_retire => true,
                :can_expand => true,
                :capacity_size => 1,
                :investment_cost => 0.0,
                :fixed_om_cost => 0.0,
                :variable_om_cost => 0.0,
                :constraints => Dict{Symbol, Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
                :co2_sink => missing,
            ),
        ),
    )
end

function simple_default_data(::Type{SteamCracker}, id=missing)
    return Dict{Symbol, Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :timedata => "Ethylene",
        :elec_consumption => 0.0,
        :h2_production => 0.0,
        :h2_consumption => 0.0,
        :natgas_consumption => 0.0,
        :natgas_production => 0.0,
        :ethylene_production => 0.0,
        :emission_rate => 0.0,
        :capture_rate => 0.0,
        :co2_sink => missing,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{SteamCracker}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # SteamCracker Transformation
    steamcracker_key = :transforms
    @process_data(
        transform_data,
        data[steamcracker_key],
        [
            (data[steamcracker_key], key),
            (data[steamcracker_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    steamcracker_transform = Transformation(;
        id = Symbol(id, "_", steamcracker_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = get(transform_data, :constraints, [BalanceConstraint()]),
    )

    # electricity_consumption_edge
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
    elec_consumption_end_node = steamcracker_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_consumption_start_node,
        elec_consumption_end_node,
    )

    # h2_production_edge
    h2_production_edge_key = :h2_production_edge
    @process_data(
        h2_production_edge_data, 
        data[:edges][h2_production_edge_key], 
        [
            (data[:edges][h2_production_edge_key], key),
            (data[:edges][h2_production_edge_key], Symbol("h2_production_", key)),
            (data, Symbol("h2_production_", key)),
            (data, key), 
        ]
    )
    h2_production_start_node = steamcracker_transform
    @end_vertex(
        h2_production_end_node,
        h2_production_edge_data,
        Hydrogen,
        [(h2_production_edge_data, :end_vertex), (data, :location)],
    )
    h2_production_edge = Edge(
        Symbol(id, "_", h2_production_edge_key),
        h2_production_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_production_start_node,
        h2_production_end_node,
    )

    # h2_consumption edge
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
    h2_consumption_end_node = steamcracker_transform
    h2_consumption_edge = Edge(
        Symbol(id, "_", h2_consumption_edge_key),
        h2_consumption_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_consumption_start_node,
        h2_consumption_end_node,
    )

    # natgas_consumption_edge
    natgas_consumption_edge_key = :natgas_consumption_edge
    @process_data(
        natgas_consumption_edge_data, 
        data[:edges][natgas_consumption_edge_key], 
        [
            (data[:edges][natgas_consumption_edge_key], key),
            (data[:edges][natgas_consumption_edge_key], Symbol("natgas_consumption_", key)),
            (data, Symbol("natgas_consumption_", key)),
        ]
    )
    @start_vertex(
        natgas_consumption_start_node,
        natgas_consumption_edge_data,
        NaturalGas,
        [(natgas_consumption_edge_data, :start_vertex), (data, :location)],
    )
    natgas_consumption_end_node = steamcracker_transform
    natgas_consumption_edge = Edge(
        Symbol(id, "_", natgas_consumption_edge_key),
        natgas_consumption_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_consumption_start_node,
        natgas_consumption_end_node,
    )

    # natgas_production_edge
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
    natgas_production_start_node = steamcracker_transform
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

    # ethane_edge
    ethane_consumption_edge_key = :ethane_consumption_edge
    @process_data(
        ethane_consumption_edge_data, 
        data[:edges][ethane_consumption_edge_key], 
        [
            (data[:edges][ethane_consumption_edge_key], key),
            (data[:edges][ethane_consumption_edge_key], Symbol("ethane_consumption_", key)),
            (data, Symbol("ethane_consumption_", key)),
        ]
    )
    @start_vertex(
        ethane_consumption_start_node,
        ethane_consumption_edge_data,
        Ethane,
        [(ethane_consumption_edge_data, :start_vertex), (data, :location)],
    )
    ethane_consumption_end_node = steamcracker_transform
    ethane_consumption_edge = Edge(
        Symbol(id, "_", ethane_consumption_edge_key),
        ethane_consumption_edge_data,
        system.time_data[:Ethane],
        Ethane,
        ethane_consumption_start_node,
        ethane_consumption_end_node,
    )

    # ethylene_edge
    ethylene_production_edge_key = :ethylene_production_edge
    @process_data(
        ethylene_production_edge_data, 
        data[:edges][ethylene_production_edge_key], 
        [
            (data[:edges][ethylene_production_edge_key], key),
            (data[:edges][ethylene_production_edge_key], Symbol("ethylene_production_", key)),
            (data, Symbol("ethylene_production_", key)),
        ]
    )
    ethylene_production_start_node = steamcracker_transform
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

    # co2_emission_edge
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
    co2_emission_start_node = steamcracker_transform
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

    # co2_captured_edge
    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key], 
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
        ],
    )
    co2_captured_start_node = steamcracker_transform
    @end_vertex(
        co2_captured_end_node,
        co2_captured_edge_data,
        CO2Captured,
        [(co2_captured_edge_data, :end_vertex), (data, :location)],
    )
    co2_captured_edge = Edge(
        Symbol(id, "_", co2_captured_edge_key),
        co2_captured_edge_data,
        system.time_data[:CO2Captured],
        CO2Captured,
        co2_captured_start_node,
        co2_captured_end_node,
    )

    # Balance Constraint Values
        # mapping asset transformation values to balance equations
        steamcracker_transform.balance_data = Dict(

        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            ethane_consumption_edge.id => get(transform_data, :elec_consumption, 0.0),
        ),

        :h2_production => Dict(
            h2_production_edge.id => 1.0,
            ethane_consumption_edge.id => get(transform_data, :h2_production, 0.0)
        ),

        :h2_consumption => Dict(
            h2_consumption_edge.id => -1.0,
            ethane_consumption_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),

        :natgas_consumption => Dict(
            ethane_consumption_edge.id => get(transform_data, :natgas_consumption, 0.0),
            natgas_consumption_edge.id => -1.0
        ),

        :natgas_production => Dict(
            natgas_production_edge.id => 1.0,
            ethane_consumption_edge.id => get(transform_data, :natgas_production, 0.0)
        ),
        
        :ethylene_production => Dict(
            ethane_consumption_edge.id => get(transform_data, :ethylene_production, 0.0),
            ethylene_production_edge.id => 1.0
        ),

        :co2_emissions => Dict(
            co2_emission_edge.id => 1.0,
            ethane_consumption_edge.id => get(transform_data, :emission_rate, 0.0)
        ),

        :co2_capture => Dict(
            co2_captured_edge.id => 1.0,
            ethane_consumption_edge.id => get(transform_data, :capture_rate, 0.0)
        )
    )
    return SteamCracker(id, steamcracker_transform, elec_consumption_edge, h2_production_edge, h2_consumption_edge, natgas_consumption_edge, natgas_production_edge, ethane_consumption_edge, ethylene_production_edge, co2_emission_edge, co2_captured_edge)
end
# steam cracker asset, which includes all thermal steam crackers + electrified steam crackers
    # _consumption or _production are only distinguished if flow can go in either direction
struct SteamCracker <: AbstractAsset
    id::AssetId
    steamcracker_transform::Transformation
    elec_consumption_edge::Edge{<:Electricity}
    elec_production_edge::Edge{<:Electricity}
    h2_consumption_edge::Edge{<:Hydrogen}
    h2_production_edge::Edge{<:Hydrogen}
    natgas_consumption_edge::Edge{<:NaturalGas}
    natgas_production_edge::Edge{<:NaturalGas} # methane production only for ESC asset
    ethane_edge::Edge{<:Ethane}
    ethylene_edge::Edge{<:Ethylene}
    co2_emission_edge::Edge{<:CO2}
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
            :electricity_consumption => 0.0,
            :electricity_production => 0.0,
            :h2_consumption => 0.0,
            :h2_production => 0.0,
            :natgas_consumption => 0.0,
            :natgas_production => 0.0,
            :ethane_consumption => 0.0,
            :emission_rate => 0.0,
            :constraints => Dict{Symbol, Bool}(
                :BalanceConstraint => true,
            ),
        ),
        :edges => Dict{Symbol,Any}(
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity"
            ),
            :elec_production_edge => @edge_data(
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
            :ethane_edge => @edge_data(
                :commodity => "Ethane"
            ),
            :ethylene_edge => @edge_data(
                :commodity=>"Ethylene",
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
        :electricity_consumption => 0.0,
        :electricity_production => 0.0,
        :h2_consumption => 0.0,
        :h2_production => 0.0,
        :natgas_consumption => 0.0,
        :natgas_production => 0.0,
        :ethane_consumption => 0.0,
        :emission_rate => 0.0,
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
        elec_start_node,
        elec_consumption_edge_data,
        Electricity,
        [(elec_consumption_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = steamcracker_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    # electricity_production_edge
    elec_production_edge_key = :elec_production_edge
    @process_data(
        elec_production_edge_data, 
        data[:edges][elec_production_edge_key], 
        [
            (data[:edges][elec_production_edge_key], key),
            (data[:edges][elec_production_edge_key], Symbol("elec_production_", key)),
            (data, Symbol("elec_production_", key)),
        ]
    )
    elec_start_node = steamcracker_transform
    @end_vertex(
        elec_end_node,
        elec_production_edge_data,
        Electricity,
        [(elec_production_edge_data, :end_vertex), (data, :location)],
    )
    elec_production_edge = Edge(
        Symbol(id, "_", elec_production_edge_key),
        elec_production_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    # h2_consumption_edge
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
        h2_start_node,
        h2_consumption_edge_data,
        Hydrogen,
        [(h2_consumption_edge_data, :start_vertex), (data, :location)],
    )
    h2_end_node = steamcracker_transform
    h2_consumption_edge = Edge(
        Symbol(id, "_", h2_consumption_edge_key),
        h2_consumption_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
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
    h2_start_node = steamcracker_transform
    @end_vertex(
        h2_end_node,
        h2_production_edge_data,
        Hydrogen,
        [(h2_production_edge_data, :end_vertex), (data, :location)],
    )
    h2_production_edge = Edge(
        Symbol(id, "_", h2_production_edge_key),
        h2_production_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
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
        natgas_start_node,
        natgas_consumption_edge_data,
        NaturalGas,
        [(natgas_consumption_edge_data, :start_vertex), (data, :location)],
    )
    natgas_end_node = steamcracker_transform
    natgas_consumption_edge = Edge(
        Symbol(id, "_", natgas_consumption_edge_key),
        natgas_consumption_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
    )

    # natgas_production_edge (represents methane production)
    natgas_production_edge_key = :natgas_production_edge
    @process_data(
        natgas_production_edge_data, 
        data[:edges][natgas_production_edge_key], 
        [
            (data[:edges][natgas_production_edge_key], key),
            (data[:edges][natgas_production_edge_key], Symbol("natgas_production_", key)),
            (data, Symbol("natgas_production_", key)),
        ]
    )
    natgas_start_node = steamcracker_transform
    @end_vertex(
        natgas_end_node,
        natgas_production_edge_data,
        NaturalGas,
        [(natgas_production_edge_data, :end_vertex), (data, :location)],
    )
    natgas_production_edge = Edge(
        Symbol(id, "_", natgas_production_edge_key),
        natgas_production_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
    )

    # ethane_edge
    ethane_edge_key = :ethane_edge
    @process_data(
        ethane_edge_data, 
        data[:edges][ethane_edge_key], 
        [
            (data[:edges][ethane_edge_key], key),
            (data[:edges][ethane_edge_key], Symbol("ethane_", key)),
            (data, Symbol("ethane_", key)),
        ]
    )
    @start_vertex(
        ethane_start_node,
        ethane_edge_data,
        Ethane,
        [(ethane_edge_data, :start_vertex), (data, :location)],
    )
    ethane_end_node = steamcracker_transform
    ethane_edge = Edge(
        Symbol(id, "_", ethane_edge_key),
        ethane_edge_data,
        system.time_data[:Ethane],
        Ethane,
        ethane_start_node,
        ethane_end_node,
    )

    # ethylene_edge
    ethylene_edge_key = :ethylene_edge
    @process_data(
        ethylene_edge_data, 
        data[:edges][ethylene_edge_key], 
        [
            (data[:edges][ethylene_edge_key], key),
            (data[:edges][ethylene_edge_key], Symbol("ethylene_", key)),
            (data, Symbol("ethylene_", key)),
        ]
    )
    ethylene_start_node = steamcracker_transform
    @end_vertex(
        ethylene_end_node,
        ethylene_edge_data,
        Ethylene,
        [(ethylene_edge_data, :end_vertex), (data, :location)],
    )
    ethylene_edge = Edge(
        Symbol(id, "_", ethylene_edge_key),
        ethylene_edge_data,
        system.time_data[:Ethylene],
        Ethylene,
        ethylene_start_node,
        ethylene_end_node,
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

    # Balance Constraint Values
        # mapping asset transformation values to balance equations
        steamcracker_transform.balance_data = Dict(
        # Electricity Balance: Net flow of consumption (-) and production (+)
        :electricity => Dict(
            elec_consumption_edge.id => -1.0,
            elec_production_edge.id => 1.0,
            ethylene_edge.id => get(transform_data, :electricity_consumption, 0.0) - get(transform_data, :electricity_production, 0.0)
        ),
        
        # Hydrogen Balance: Net flow of consumption (-) and production (+)
        :hydrogen => Dict(
            h2_consumption_edge.id => -1.0,
            h2_production_edge.id => 1.0,
            ethylene_edge.id => get(transform_data, :h2_consumption, 0.0) - get(transform_data, :h2_production, 0.0)
        ),
        
        # Natural Gas Balance: Net flow of consumption (-) and production (+)
        :natural_gas => Dict(
            natgas_consumption_edge.id => -1.0,
            natgas_production_edge.id => 1.0,
            ethylene_edge.id => get(transform_data, :natgas_consumption, 0.0) - get(transform_data, :natgas_production, 0.0)
        ),
        
        # Ethane Feedstock: Flow in (-) balanced against production rate
        :ethane => Dict(
            ethane_edge.id => -1.0,
            ethylene_edge.id => get(transform_data, :ethane_consumption, 1.2) # Defaulting to ~1.2 MWh ethane per MWh ethylene
        ),

        # Ethylene: The reference commodity (1.0)
        :ethylene => Dict(
            ethylene_edge.id => 1.0
        ),
        
        # CO2 Emissions: Flow out (+)
        :co2_emissions => Dict(
            co2_emission_edge.id => 1.0,
            ethylene_edge.id => get(transform_data, :emission_rate, 0.0)
        )
    )
    return SteamCracker(id, steamcracker_transform, elec_consumption_edge, elec_production_edge, h2_consumption_edge, h2_production_edge, natgas_consumption_edge, natgas_production_edge, ethane_edge, ethylene_edge, co2_emission_edge)
end
struct EthanolDryMillCCS <: AbstractAsset
    id::AssetId
    drymillethanol_transform::Transformation
    biomass_edge::Edge{<:Biomass}
    ethanol_edge::Edge{<:LiquidFuels}
    elec_edge::Edge{<:Electricity}
    natgas_edge::Edge{<:Electricity}
    co2_edge::Edge{<:CO2}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{EthanolDryMillCCS}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{EthanolDryMillCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Biomass",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :ethanol_production => 0.0,
            :electricity_consumption => 0.0,
            :natgas_consumption => 0.0,
            :co2_content => 0.0,
            :emission_rate => 1.0,
            :capture_rate => 1.0
        ),
        :edges => Dict{Symbol,Any}(
            :biomass_edge => @edge_data(
                :commodity => "Biomass",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :ethanol_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :co2_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :elec_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :natgas_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            ),
        )
    )
end

function simple_default_data(::Type{EthanolDryMillCCS}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_retire => true,
        :can_expand => true,
        :existing_capacity => 0.0,
        :capacity_size => 1.0,
        :ethanol_commodity => "LiquidFuels",
        :co2_sink => missing,
        :electricity_consumption => 0.0,
        :natgas_consumption => 0.0,
        :co2_content => 0.0,
        :emission_rate => 1.0,
        :capture_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{EthanolDryMillCCS}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # set up the asset
    drymillethanol_transform_key = :transforms
    @process_data(
        transform_data,
        data[drymillethanol_transform_key],
        [
            (data[drymillethanol_transform_key], key),
            (data[drymillethanol_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    drymillethanol_transform = Transformation(;
        id = Symbol(id, "_", drymillethanol_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )

    # biomass
    biomass_edge_key = :biomass_edge
    @process_data(
        biomass_edge_data,
        data[:edges][biomass_edge_key],
        [
            (data[:edges][biomass_edge_key], key),
            (data[:edges][biomass_edge_key], Symbol("biomass_", key)),
            (data, Symbol("biomass_", key)),
            (data, key),
        ])
    commodity_symbol = Symbol(biomass_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        biomass_start_node,
        biomass_edge_data,
        commodity,
        [(biomass_edge_data, :start_vertex), (data, :location)],
    )
    biomass_end_node = drymillethanol_transform
    biomass_edge = Edge(
        Symbol(id, "_", biomass_edge_key),
        biomass_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        biomass_start_node,
        biomass_end_node,
    )

    # ethanol
    ethanol_edge_key = :ethanol_edge
    @process_data(
        ethanol_edge_data,
        data[:edges][ethanol_edge_key],
        [
            (data[:edges][ethanol_edge_key], key),
            (data[:edges][ethanol_edge_key], Symbol("ethanol_", key)),
            (data, Symbol("ethanol_", key)),
        ]
    )
    commodity_symbol = Symbol(ethanol_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    ethanol_start_node = drymillethanol_transform
    @end_vertex(
        ethanol_end_node,
        ethanol_edge_data,
        commodity,
        [(ethanol_edge_data, :end_vertex), (data, :location)],
    )
    ethanol_edge = Edge(
        Symbol(id, "_", ethanol_edge_key),
        ethanol_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_start_node,
        ethanol_end_node,
    )

    # electricity
    elec_edge_key = :elec_edge
    @process_data(
        elec_edge_data,
        data[:edges][elec_edge_key],
        [
            (data[:edges][elec_edge_key], key),
            (data[:edges][elec_edge_key], Symbol("elec_", key)),
            (data, Symbol("elec_", key)),
        ]
    )
    @start_vertex(
        elec_start_node,
        elec_edge_data,
        Electricity,
        [(elec_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = drymillethanol_transform
    elec_edge = Edge(
        Symbol(id, "_", elec_edge_key),
        elec_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
    )

    # natural gas
    natgas_edge_key = :natgas_edge
    @process_data(
        natgas_edge_data,
        data[:edges][natgas_edge_key],
        [
            (data[:edges][natgas_edge_key], key),
            (data[:edges][natgas_edge_key], Symbol("natgas_", key)),
            (data, Symbol("natgas_", key)),
        ]
    )
    @start_vertex(
        natgas_start_node,
        natgas_edge_data,
        NaturalGas,
        [(natgas_edge_data, :start_vertex), (data, :location)],
    )
    natgas_end_node = drymillethanol_transform
    natgas_edge = Edge(
        Symbol(id, "_", natgas_edge_key),
        natgas_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_start_node,
        natgas_end_node,
    )

    # co2 content
    co2_edge_key = :co2_edge
    @process_data(
        co2_edge_data, 
        data[:edges][co2_edge_key],
        [
            (data[:edges][co2_edge_key], key),
            (data[:edges][co2_edge_key], Symbol("co2_", key)),
            (data, Symbol("co2_", key)),
        ]
    )
    @start_vertex(
        co2_start_node,
        co2_edge_data,
        CO2,
        [(co2_edge_data, :start_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_end_node = drymillethanol_transform
    co2_edge = Edge(
        Symbol(id, "_", co2_edge_key),
        co2_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_start_node,
        co2_end_node,
    )

    # co2 emission
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
    co2_emission_start_node = drymillethanol_transform
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

    # co2 captured
    co2_captured_edge_key = :co2_captured_edge
    @process_data(
        co2_captured_edge_data, 
        data[:edges][co2_captured_edge_key],
        [
            (data[:edges][co2_captured_edge_key], key),
            (data[:edges][co2_captured_edge_key], Symbol("co2_captured_", key)),
            (data, Symbol("co2_captured_", key)),
        ]
    )
    co2_captured_start_node = drymillethanol_transform
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

    # balance equations
    drymillethanol_transform.balance_data = Dict(
        :ethanol_production => Dict(
            ethanol_edge.id => 1.0,
            biomass_edge.id => get(transform_data, :ethanol_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_edge.id => -1.0,
            biomass_edge.id => get(transform_data, :electricity_consumption, 0.0)
        ),
        :natgas_consumption => Dict(
            natgas_edge.id => -1.0,
            biomass_edge.id => get(transform_data, :natgas_consumption, 0.0)
        ),
        :negative_emissions => Dict(
            biomass_edge.id => get(transform_data, :co2_content, 0.0),
            co2_edge.id => -1.0
        ),
        :emissions => Dict(
            biomass_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            biomass_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return EthanolDryMillCCS(id, drymillethanol_transform, biomass_edge,ethanol_edge,elec_edge,natgas_edge,co2_edge,co2_emission_edge,co2_captured_edge) 
end

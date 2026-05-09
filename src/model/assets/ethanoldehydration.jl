# all transformation parameters are per MWh-ethanol, normalized by primary feedstock
struct EthanolDehydration <: AbstractAsset
    id::AssetId
    ethanoldehydration_transform::Transformation
    ethanol_consumption_edge::Edge{<:LiquidFuels}
    ethylene_production_edge::Edge{<:Ethylene}
    elec_consumption_edge::Edge{<:Electricity}
    h2_consumption_edge::Edge{<:Hydrogen}
    natgas_consumption_edge::Edge{<:NaturalGas}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{EthanolDehydration}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{EthanolDehydration}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :h2_consumption => 0.0,
            :natgas_consumption => 0.0,
            :elec_consumption => 0.0,
            :ethylene_production => 0.0,
            :process_emission_rate => 1.0,
            :process_capture_rate => 1.0,
            :fuel_emission_rate => 0.0,
            :fuel_capture_rate => 0.0,
        ),
        :edges => Dict{Symbol,Any}(
            :ethanol_consumption_edge => @edge_data(
                :commodity => "LiquidFuels",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                )
            ),
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :ethylene_production_edge => @edge_data(
                :commodity => "Ethylene",
            ),
            :h2_consumption_edge => @edge_data(
                :commodity => "Hydrogen",
            ),
            :natgas_consumption_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            )
        )
    )
end

function simple_default_data(::Type{EthanolDehydration}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :elec_consumption => 0.0,
        :h2_consumption => 0.0,
        :natgas_consumption => 0.0,
        :ethylene_production => 0.0,
        :process_emission_rate => 1.0,
        :process_capture_rate => 1.0,
        :fuel_emission_rate => 0.0,
        :fuel_capture_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{EthanolDehydration}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # set up transformation
    ethanoldehydration_transform_key = :transforms
    @process_data(
        transform_data,
        data[ethanoldehydration_transform_key],
        [
            (data[ethanoldehydration_transform_key], key),
            (data[ethanoldehydration_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    ethanoldehydration_transform = Transformation(;
        id = Symbol(id, "_", ethanoldehydration_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )

    # ethanol input edge (special)
    ethanol_consumption_edge_key = :ethanol_consumption_edge
    @process_data(
        ethanol_consumption_edge_data,
        data[:edges][ethanol_consumption_edge_key],
        [
            (data[:edges][ethanol_consumption_edge_key], key),
            (data[:edges][ethanol_consumption_edge_key], Symbol("ethanol_consumption_", key)),
            (data, Symbol("ethanol_consumption_", key)),
            (data, key),
        ]
    )
    commodity_symbol = Symbol(ethanol_consumption_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        ethanol_consumption_start_node,
        ethanol_consumption_edge_data,
        commodity,
        [(ethanol_consumption_edge_data, :start_vertex), (data, :location)],
    )
    ethanol_consumption_end_node = ethanoldehydration_transform
    ethanol_consumption_edge = Edge(
        Symbol(id, "_", ethanol_consumption_edge_key),
        ethanol_consumption_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_consumption_start_node,
        ethanol_consumption_end_node,
    )

    # ethylene output edge
    ethylene_production_edge_key = :ethylene_production_edge
    @process_data(
        ethylene_production_edge_data,
        data[:edges][ethylene_production_edge_key],
        [
            (data[:edges][ethylene_production_edge_key], key), 
            (data[:edges][ethylene_production_edge_key], Symbol("ethylene_production_", key)),
            (data, Symbol("ethylene_production_", key)), 
        ],
    )
    commodity_symbol = Symbol(ethylene_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    ethylene_production_start_node = ethanoldehydration_transform
    @end_vertex(
        ethylene_production_end_node,
        ethylene_production_edge_data,
        commodity,
        [(ethylene_production_edge_data, :end_vertex), (data, :location)],
    )
    ethylene_production_edge = Edge(
        Symbol(id, "_", ethylene_production_edge_key),
        ethylene_production_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethylene_production_start_node,
        ethylene_production_end_node,
    )

    # elec input edge
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
    elec_consumption_end_node = ethanoldehydration_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_consumption_start_node,
        elec_consumption_end_node,
    )

    # natgas input edge
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
    natgas_consumption_end_node = ethanoldehydration_transform
    natgas_consumption_edge = Edge(
        Symbol(id, "_", natgas_consumption_edge_key),
        natgas_consumption_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_consumption_start_node,
        natgas_consumption_end_node,
    )

    # h2 input edge
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
    h2_consumption_end_node = ethanoldehydration_transform
    h2_consumption_edge = Edge(
        Symbol(id, "_", h2_consumption_edge_key),
        h2_consumption_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_consumption_start_node,
        h2_consumption_end_node,
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
    co2_emission_start_node = ethanoldehydration_transform
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
    co2_captured_start_node = ethanoldehydration_transform
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

    ethanoldehydration_transform.balance_data = Dict(
        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            ethanol_consumption_edge.id => get(transform_data, :elec_consumption, 0.0)
        ),
        :h2_consumption => Dict(
            h2_consumption_edge.id => -1.0,
            ethanol_consumption_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),
        :natgas_consumption => Dict(
            natgas_consumption_edge.id => -1.0,
            ethanol_consumption_edge.id => get(transform_data, :natgas_consumption, 0.0)
        ),
        :ethylene_production => Dict(
            ethylene_production_edge.id => 1.0,
            ethanol_consumption_edge.id => get(transform_data, :ethylene_production, 0.0)
        ),
        :emissions => Dict(
            ethanol_consumption_edge.id => get(transform_data, :process_emission_rate, 1.0),
            ethanol_consumption_edge.id => get(transform_data, :fuel_emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture => Dict(
            ethanol_consumption_edge.id => get(transform_data, :process_capture_rate, 1.0),
            ethanol_consumption_edge.id => get(transform_data, :fuel_capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return EthanolDehydration(id, ethanoldehydration_transform, ethanol_consumption_edge, ethylene_production_edge, elec_consumption_edge, h2_consumption_edge, natgas_consumption_edge, co2_emission_edge, co2_captured_edge) 
end
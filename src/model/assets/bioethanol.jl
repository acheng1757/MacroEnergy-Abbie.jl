struct BioEthanol <: AbstractAsset
    id::AssetId
    bioethanol_transform::Transformation
    biomass_consumption_edge::Edge{<:Biomass}
    ethanol_production_edge::Edge{<:LiquidFuels}
    elec_production_edge::Edge{<:Electricity}
    elec_consumption_edge::Edge{<:Electricity}
    natgas_consumption_edge::Edge{<:NaturalGas}
    co2_content_edge::Edge{<:CO2}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{BioEthanol}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{BioEthanol}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "Biomass",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :co2_biomass_content => 0.0,
            :natgas_consumption => 0.0,
            :elec_consumption => 0.0,
            :elec_production => 0.0,
            :ethanol_production => 0.0,
            :process_emission_rate => 1.0,
            :process_capture_rate => 1.0,
            :fuel_emission_rate => 0.0,
            :fuel_capture_rate => 0.0,
        ),
        :edges => Dict{Symbol,Any}(
            :biomass_consumption_edge => @edge_data(
                :commodity => "Biomass",
                :has_capacity => true,
                :can_expand => true,
                :can_retire => true,
                :constraints => Dict{Symbol,Bool}(
                    :CapacityConstraint => true,
                ),
                :min_flow_fraction => 0.0,
            ),
            :ethanol_production_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :natgas_consumption_edge => @edge_data(
                :commodity => "NaturalGas",
            ),
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :elec_production_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :co2_content_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
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

function simple_default_data(::Type{BioEthanol}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :co2_sink => missing,
        :ethanol_production => 0.0,
        :natgas_consumption => 0.0,
        :elec_consumption => 0.0,
        :elec_production => 0.0,
        :co2_biomass_content => 0.0,
        :process_emission_rate => 1.0,
        :process_capture_rate => 1.0,
        :fuel_emission_rate => 0.0,
        :fuel_capture_rate => 0.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
        :ethanol_commodity => "LiquidFuels",
        :biomass_commodity => "Biomass",
        :min_flow_fraction => 0.0,
    )
end

function make(asset_type::Type{BioEthanol}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))

    @setup_data(asset_type, data, id)

    # transformation
    bioethanol_transform_key = :transforms
    @process_data(
        transform_data,
        data[bioethanol_transform_key],
        [
            (data[bioethanol_transform_key], key),
            (data[bioethanol_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    bioethanol_transform = Transformation(;
        id = Symbol(id, "_", bioethanol_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,
        constraints = transform_data[:constraints],
    )

    # biomass consumption edge (special since Biomass > corn or corn stover)
    biomass_consumption_edge_key = :biomass_consumption_edge
    @process_data(
        biomass_consumption_edge_data,
        data[:edges][biomass_consumption_edge_key],
        [
            (data[:edges][biomass_consumption_edge_key], key),
            (data[:edges][biomass_consumption_edge_key], Symbol("biomass_consumption_", key)), 
            (data, Symbol("biomass_consumption_", key)),
            (data, key),
        ]
    )
    commodity_symbol = Symbol(biomass_consumption_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        biomass_consumption_start_node,
        biomass_consumption_edge_data,
        commodity,
        [(biomass_consumption_edge_data, :start_vertex), (data, :location)],
    )
    biomass_consumption_end_node = bioethanol_transform
    biomass_consumption_edge = Edge(
        Symbol(id, "_", biomass_consumption_edge_key),
        biomass_consumption_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        biomass_consumption_start_node,
        biomass_consumption_end_node,
    )

    # ethanol production edge (also special since Liquid Fuels > Ethanol)
    ethanol_production_edge_key = :ethanol_production_edge
    @process_data(
        ethanol_production_edge_data,
        data[:edges][ethanol_production_edge_key],
        [
            (data[:edges][ethanol_production_edge_key], key), 
            (data[:edges][ethanol_production_edge_key], Symbol("ethanol_production_", key)),
            (data, Symbol("ethanol_production_", key)), 
        ],
    )
    commodity_symbol = Symbol(ethanol_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    ethanol_production_start_node = bioethanol_transform
    @end_vertex(
        ethanol_production_end_node,
        ethanol_production_edge_data,
        commodity,
        [(ethanol_production_edge_data, :end_vertex), (data, :location)],
    )
    ethanol_production_edge = Edge(
        Symbol(id, "_", ethanol_production_edge_key),
        ethanol_production_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_production_start_node,
        ethanol_production_end_node,
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
    elec_consumption_end_node = bioethanol_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_consumption_start_node,
        elec_consumption_end_node,
    )

    # natgas consumption edge
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
    natgas_consumption_end_node = bioethanol_transform
    natgas_consumption_edge = Edge(
        Symbol(id, "_", natgas_consumption_edge_key),
        natgas_consumption_edge_data,
        system.time_data[:NaturalGas],
        NaturalGas,
        natgas_consumption_start_node,
        natgas_consumption_end_node,
    )

    # elec production edge
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
    elec_production_start_node = bioethanol_transform
    @end_vertex(
        elec_production_end_node,
        elec_production_edge_data,
        Electricity,
        [(elec_production_edge_data, :end_vertex), (data, :location)],
    )
    elec_production_edge = Edge(
        Symbol(id, "_", elec_production_edge_key),
        elec_production_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_production_start_node,
        elec_production_end_node,
    )

    # co2 content edge
    co2_content_edge_key = :co2_content_edge
    @process_data(
        co2_content_edge_data,
        data[:edges][co2_content_edge_key],
        [
            (data[:edges][co2_content_edge_key], key),
            (data[:edges][co2_content_edge_key], Symbol("co2_content_", key)),
            (data, Symbol("co2_content_", key)),
        ]
    )
    @start_vertex(
        co2_content_start_node,
        co2_content_edge_data,
        CO2,
        [(co2_content_edge_data, :start_vertex), (data, :co2_sink), (data, :location)],
    )
    co2_content_end_node = bioethanol_transform
    co2_content_edge = Edge(
        Symbol(id, "_", co2_content_edge_key),
        co2_content_edge_data,
        system.time_data[:CO2],
        CO2,
        co2_content_start_node,
        co2_content_end_node,
    )

    # co2 emission edge
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
    co2_emission_start_node = bioethanol_transform
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

    # co2 captured edge
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
    co2_captured_start_node = bioethanol_transform
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

    # write balance equations
    bioethanol_transform.balance_data = Dict(
        :ethanol_production => Dict(
            ethanol_production_edge.id => 1.0,
            biomass_consumption_edge.id => get(transform_data, :ethanol_production, 0.0)
        ),
        :natgas_consumption => Dict(
            natgas_consumption_edge.id => -1.0,
            biomass_consumption_edge.id => get(transform_data, :natgas_consumption, 0.0)
        ),
        :elec_production => Dict(
            elec_production_edge.id => 1.0,
            biomass_consumption_edge.id => get(transform_data, :elec_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            biomass_consumption_edge.id => get(transform_data, :elec_consumption, 0.0)
        ),
        :co2_biomass_content => Dict(
            biomass_consumption_edge.id => get(transform_data, :co2_biomass_content, 0.0),
            co2_content_edge.id => -1.0
        ),
        :co2_emissions => Dict(
            co2_emission_edge.id => 1.0,
            biomass_consumption_edge.id => get(transform_data, :process_emission_rate, 0.0)
                                + get(transform_data, :fuel_emission_rate, 0.0)
        ),

        :co2_capture => Dict(
            co2_captured_edge.id => 1.0,
            biomass_consumption_edge.id => get(transform_data, :process_capture_rate, 0.0)
                                + get(transform_data, :fuel_capture_rate, 0.0)
        ),
    )

    return BioEthanol(id, bioethanol_transform, biomass_consumption_edge, ethanol_production_edge, elec_production_edge, elec_consumption_edge, natgas_consumption_edge, co2_content_edge, co2_emission_edge, co2_captured_edge) 
end
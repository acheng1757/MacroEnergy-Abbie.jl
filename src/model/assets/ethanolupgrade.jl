struct EthanolUpgrade <: AbstractAsset
    id::AssetId
    ethanolupgrade_transform::Transformation
    ethanol_consumption_edge::Edge{<:LiquidFuels}
    gasoline_production_edge::Edge{<:LiquidFuels}
    jetfuel_production_edge::Edge{<:LiquidFuels}
    diesel_production_edge::Edge{<:LiquidFuels}
    elec_production_edge::Edge{<:Electricity}
    elec_consumption_edge::Edge{<:Electricity}
    h2_consumption_edge::Edge{<:Hydrogen}
    co2_emission_edge::Edge{<:CO2}
    co2_captured_edge::Edge{<:CO2Captured}
end

function default_data(t::Type{EthanolUpgrade}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{EthanolUpgrade}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :gasoline_production => 0.0,
            :jetfuel_production => 0.0,
            :diesel_production => 0.0,
            :elec_consumption => 0.0,
            :elec_production => 0.0,
            :h2_consumption => 0.0,
            :emission_rate => 1.0,
            :capture_rate => 1.0
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
            :gasoline_production_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :jetfuel_production_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :diesel_production_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :co2_emission_edge => @edge_data(
                :commodity => "CO2",
                :co2_sink => missing,
            ),
            :elec_consumption_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :elec_production_edge => @edge_data(
                :commodity => "Electricity",
            ),
            :h2_consumption_edge => @edge_data(
                :commodity => "Hydrogen",
            ),
            :co2_captured_edge => @edge_data(
                :commodity => "CO2Captured",
            )
        )
    )
end

function simple_default_data(::Type{EthanolUpgrade}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :can_expand => true,
        :can_retire => true,
        :existing_capacity => 0.0,
        :gasoline_production_commodity => "LiquidFuels",
        :jetfuel_production_commodity => "LiquidFuels",
        :diesel_production_commodity => "LiquidFuels",
        :co2_sink => missing,
        :gasoline_production => 0.0,
        :jetfuel_production => 0.0,
        :diesel_production => 0.0,
        :elec_consumption => 0.0,
        :elec_production => 0.0,
        :h2_consumption => 0.0,
        :emission_rate => 1.0,
        :capture_rate => 1.0,
        :investment_cost => 0.0,
        :fixed_om_cost => 0.0,
        :variable_om_cost => 0.0,
    )
end

function make(asset_type::Type{EthanolUpgrade}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # transform
    ethanolupgrade_transform_key = :transforms
    @process_data(
        transform_data,
        data[ethanolupgrade_transform_key],
        [
            (data[ethanolupgrade_transform_key], key),
            (data[ethanolupgrade_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    ethanolupgrade_transform = Transformation(;
        id = Symbol(id, "_", ethanolupgrade_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )

    # ethanol consumption edge
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
    ethanol_consumption_end_node = ethanolupgrade_transform
    ethanol_consumption_edge = Edge(
        Symbol(id, "_", ethanol_consumption_edge_key),
        ethanol_consumption_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_consumption_start_node,
        ethanol_consumption_end_node,
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
        ],
    )
    commodity_symbol = Symbol(gasoline_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    gasoline_production_start_node = ethanolupgrade_transform
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

    # jetfuel production edge
    jetfuel_production_edge_key = :jetfuel_production_edge
    @process_data(
        jetfuel_production_edge_data, 
        data[:edges][jetfuel_production_edge_key], 
        [
            (data[:edges][jetfuel_production_edge_key], key),
            (data[:edges][jetfuel_production_edge_key], Symbol("jetfuel_production_", key)),
            (data, Symbol("jetfuel_production_", key)),
        ]
    )
    commodity_symbol = Symbol(jetfuel_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    jetfuel_production_start_node = ethanolupgrade_transform
    @end_vertex(
        jetfuel_production_end_node,
        jetfuel_production_edge_data,
        commodity,
        [(jetfuel_production_edge_data, :end_vertex), (data, :location)],
    )
    jetfuel_production_edge = Edge(
        Symbol(id, "_", jetfuel_production_edge_key),
        jetfuel_production_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        jetfuel_production_start_node,
        jetfuel_production_end_node,
    )

    # diesel production edge
    diesel_production_edge_key = :diesel_production_edge
    @process_data(
        diesel_production_edge_data,
        data[:edges][diesel_production_edge_key],
        [
            (data[:edges][diesel_production_edge_key], key),
            (data[:edges][diesel_production_edge_key], Symbol("diesel_production_", key)),
            (data, Symbol("diesel_production_", key)),
        ]
    )
    commodity_symbol = Symbol(diesel_production_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    diesel_production_start_node = ethanolupgrade_transform
    @end_vertex(
        diesel_production_end_node,
        diesel_production_edge_data,
        commodity,
        [(diesel_production_edge_data, :end_vertex), (data, :location)],
    )
    diesel_production_edge = Edge(
        Symbol(id, "_", diesel_production_edge_key),
        diesel_production_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        diesel_production_start_node,
        diesel_production_end_node,
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
        h2_start_node,
        h2_consumption_edge_data,
        Hydrogen,
        [(h2_consumption_edge_data, :start_vertex), (data, :location)],
    )
    h2_end_node = ethanolupgrade_transform
    h2_consumption_edge = Edge(
        Symbol(id, "_", h2_consumption_edge_key),
        h2_consumption_edge_data,
        system.time_data[:Hydrogen],
        Hydrogen,
        h2_start_node,
        h2_end_node,
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
        elec_start_node,
        elec_consumption_edge_data,
        Electricity,
        [(elec_consumption_edge_data, :start_vertex), (data, :location)],
    )
    elec_end_node = ethanolupgrade_transform
    elec_consumption_edge = Edge(
        Symbol(id, "_", elec_consumption_edge_key),
        elec_consumption_edge_data,
        system.time_data[:Electricity],
        Electricity,
        elec_start_node,
        elec_end_node,
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
    elec_start_node = ethanolupgrade_transform
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
    co2_emission_start_node = ethanolupgrade_transform
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
    co2_captured_start_node = ethanolupgrade_transform
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

    ethanolupgrade_transform.balance_data = Dict(
        :gasoline_production => Dict(
            gasoline_production_edge.id => 1.0,
            ethanol_consumption_edge.id => get(transform_data, :gasoline_production, 0.0)
        ),
        :jetfuel_production => Dict(
            jetfuel_production_edge.id => 1.0,
            ethanol_consumption_edge.id => get(transform_data, :jetfuel_production, 0.0)
        ),
        :diesel_production => Dict(
            diesel_production_edge.id => 1.0,
            ethanol_consumption_edge.id => get(transform_data, :diesel_production, 0.0)
        ),
        :elec_production => Dict(
            elec_production_edge.id => 1.0,
            ethanol_consumption_edge.id => get(transform_data, :elec_production, 0.0)
        ),
        :elec_consumption => Dict(
            elec_consumption_edge.id => -1.0,
            ethanol_consumption_edge.id => get(transform_data, :elec_consumption, 0.0)
        ),
        :h2_consumption => Dict(
            h2_consumption_edge.id => -1.0,
            ethanol_consumption_edge.id => get(transform_data, :h2_consumption, 0.0)
        ),
        :emissions => Dict(
            ethanol_consumption_edge.id => get(transform_data, :emission_rate, 1.0),
            co2_emission_edge.id => 1.0
        ),
        :capture =>Dict(
            ethanol_consumption_edge.id => get(transform_data, :capture_rate, 1.0),
            co2_captured_edge.id => 1.0
        )
    )

    return EthanolUpgrade(id, ethanolupgrade_transform,ethanol_consumption_edge,gasoline_production_edge,jetfuel_production_edge,diesel_production_edge,elec_production_edge,elec_consumption_edge,h2_consumption_edge,co2_emission_edge,co2_captured_edge) 
end
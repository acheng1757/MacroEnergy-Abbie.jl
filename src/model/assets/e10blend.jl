struct E10Blend <: AbstractAsset
    id::AssetId
    e10_blend_transform::Transformation
    gasoline_edge::Edge{<:LiquidFuels}
    ethanol_edge::Edge{<:LiquidFuels}
    e10_edge::Edge{<:LiquidFuels}
end

function default_data(t::Type{E10Blend}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{E10Blend}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :gasoline_consumption => 0.0,
            :ethanol_consumption => 0.0,
        ),
        :edges => Dict{Symbol,Any}(
            :gasoline_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :ethanol_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
            :e10_edge => @edge_data(
                :commodity => "LiquidFuels",
            ),
        )
    )
end

function make(asset_type::Type{E10Blend}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])

    @setup_data(asset_type, data, id)

    # transform
    e10_blend_transform_key = :transforms
    @process_data(
        transform_data,
        data[e10_blend_transform_key],
        [
            (data[e10_blend_transform_key], key),
            (data[e10_blend_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    e10_blend_transform = Transformation(;
        id = Symbol(id, "_", e10_blend_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        constraints = transform_data[:constraints],
    )

    # gasoline edge
    gasoline_edge_key = :gasoline_edge
    @process_data(
        gasoline_edge_data, 
        data[:edges][gasoline_edge_key], 
        [
            (data[:edges][gasoline_edge_key], key),
            (data[:edges][gasoline_edge_key], Symbol("gasoline_", key)),
            (data, Symbol("gasoline_", key)),
        ]
    )
    commodity_symbol = Symbol(gasoline_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    @start_vertex(
        gasoline_start_node,
        gasoline_edge_data,
        commodity,
        [(gasoline_edge_data, :start_vertex), (data, :location)],
    )
    gasoline_end_node = e10_blend_transform
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gasoline_start_node,
        gasoline_end_node,
    )

    # ethanol edge
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
    @start_vertex(
        ethanol_start_node,
        ethanol_edge_data,
        commodity,
        [(ethanol_edge_data, :start_vertex), (data, :location)],
    )
    ethanol_end_node = e10_blend_transform
    ethanol_edge = Edge(
        Symbol(id, "_", ethanol_edge_key),
        ethanol_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_start_node,
        ethanol_end_node,
    )

    # e10 edge
    e10_edge_key = :e10_edge
    @process_data(
        e10_edge_data,
        data[:edges][e10_edge_key],
        [
            (data[:edges][e10_edge_key], key),
            (data[:edges][e10_edge_key], Symbol("e10_", key)),
            (data, Symbol("e10_", key)),
        ]
    )
    commodity_symbol = Symbol(e10_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    e10_start_node = e10_blend_transform
    @end_vertex(
        e10_end_node,
        e10_edge_data,
        commodity,
        [(e10_edge_data, :end_vertex), (data, :location)],
    )
    e10_edge = Edge(
        Symbol(id, "_", e10_edge_key),
        e10_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        e10_start_node,
        e10_end_node,
    )

    # transform
    e10_blend_transform.balance_data = Dict(
        :ethanol_consumption => Dict(
            ethanol_edge.id => 1.0,
            e10_edge.id => get(transform_data, :ethanol_consumption, 0.0)
        ),
        :gasoline_consumption => Dict(
            gasoline_edge.id => 1.0,
            e10_edge.id => get(transform_data, :gasoline_consumption, 0.0)
        ),
    )

    return E10Blend(id, e10_blend_transform, gasoline_edge,ethanol_edge, e10_edge) 
end
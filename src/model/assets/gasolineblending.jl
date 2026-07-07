struct BlendedGasoline <: AbstractAsset
    id::AssetId
    gasoline_blend_transform::Transformation
    gasoline_edge::Edge{<:LiquidFuels}
    ethanol_edge::Edge{<:LiquidFuels}
    gasoline_blend_edge::Edge{<:LiquidFuels}
end

function default_data(t::Type{BlendedGasoline}, id=missing, style="full")
    if style == "full"
        return full_default_data(t, id)
    else
        return simple_default_data(t, id)
    end
end

function full_default_data(::Type{BlendedGasoline}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :transforms => @transform_data(
            :timedata => "LiquidFuels",
            :constraints => Dict{Symbol,Bool}(
                :BalanceConstraint => true
            ),
            :min_ethanol_fraction => 0.0,   # the minimum fraction of ethanol in the blend
            :max_ethanol_fraction => 0.0,   # replaces the two fixed-ratio params
        ),
        :edges => Dict{Symbol,Any}(
            :gasoline_edge => @edge_data(
                :commodity => "LiquidFuels",
                :has_capacity => false,
                :unidirectional => true,
            ),
            :ethanol_edge => @edge_data(
                :commodity => "LiquidFuels",
                :has_capacity => false,
                :unidirectional => true,
            ),
            :gasoline_blend_edge => @edge_data(
                :commodity => "LiquidFuels",
                :has_capacity => false,
                :unidirectional => true,

            ),
        )
    )
end

function simple_default_data(::Type{BlendedGasoline}, id=missing)
    return OrderedDict{Symbol,Any}(
        :id => id,
        :location => missing,
        :max_ethanol_fraction => 0.0,
        :min_ethanol_fraction => 0.0,
    )
end

function make(asset_type::Type{BlendedGasoline}, data::AbstractDict{Symbol,Any}, system::System)
    id = AssetId(data[:id])
    location = as_symbol_or_missing(get(data, :location, missing))  # fix #3

    @setup_data(asset_type, data, id)

    gasoline_blend_transform_key = :transforms
    @process_data(
        transform_data,
        data[gasoline_blend_transform_key],
        [
            (data[gasoline_blend_transform_key], key),
            (data[gasoline_blend_transform_key], Symbol("transform_", key)),
            (data, Symbol("transform_", key)),
            (data, key),
        ]
    )
    gasoline_blend_transform = Transformation(;
        id = Symbol(id, "_", gasoline_blend_transform_key),
        timedata = system.time_data[Symbol(transform_data[:timedata])],
        location = location,                       # fix #3
        constraints = transform_data[:constraints],
    )

    # gasoline edge (unchanged from your version)
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
    gasoline_end_node = gasoline_blend_transform
    gasoline_edge = Edge(
        Symbol(id, "_", gasoline_edge_key),
        gasoline_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gasoline_start_node,
        gasoline_end_node,
    )

    # ethanol edge (unchanged from your version)
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
    ethanol_end_node = gasoline_blend_transform
    ethanol_edge = Edge(
        Symbol(id, "_", ethanol_edge_key),
        ethanol_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        ethanol_start_node,
        ethanol_end_node,
    )

    # gasoline_blend edge — FIXED typo here
    gasoline_blend_edge_key = :gasoline_blend_edge
    @process_data(
        gasoline_blend_edge_data,
        data[:edges][gasoline_blend_edge_key],
        [
            (data[:edges][gasoline_blend_edge_key], key),
            (data[:edges][gasoline_blend_edge_key], Symbol("gasoline_blend_", key)),
            (data, Symbol("gasoline_blend_", key)),
        ]
    )
    commodity_symbol = Symbol(gasoline_blend_edge_data[:commodity])
    commodity = commodity_types()[commodity_symbol]
    gasoline_blend_start_node = gasoline_blend_transform   # fix #1 — was gasoline_blend_blend_transform
    @end_vertex(
        gasoline_blend_end_node,
        gasoline_blend_edge_data,
        commodity,
        [(gasoline_blend_edge_data, :end_vertex), (data, :location)],
    )
    gasoline_blend_edge = Edge(
        Symbol(id, "_", gasoline_blend_edge_key),
        gasoline_blend_edge_data,
        system.time_data[commodity_symbol],
        commodity,
        gasoline_blend_start_node,
        gasoline_blend_end_node,
    )

    # --- Balances: mass conservation + flexible max-blend cap, fix #2 ---
    min_ethanol_fraction = get(transform_data, :min_ethanol_fraction, 0.0) # the 0.0 is just a fallback value
    max_ethanol_fraction = get(transform_data, :max_ethanol_fraction, 0.0) # the 0.0 is just a fallback value

    @add_balance(
        gasoline_blend_transform,
        :mass_balance,
        flow(ethanol_edge) + flow(gasoline_edge) == flow(gasoline_blend_edge),
    )

    @add_balance(
        gasoline_blend_transform,
        :max_ethanol_blend,
        flow(ethanol_edge) <= max_ethanol_fraction * flow(gasoline_blend_edge),
    )

    @add_balance(
        gasoline_blend_transform,
        :min_ethanol_fraction,
        flow(ethanol_edge) >= min_ethanol_fraction * flow(gasoline_blend_edge),
    )

    return BlendedGasoline(id, gasoline_blend_transform, gasoline_edge, ethanol_edge, gasoline_blend_edge)
end
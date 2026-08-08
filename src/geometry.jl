# ==============================================================================
# GRID GEOMETRY
#
# Everything in here turns a Ferrite grid plus a vector of (possibly deformed) node
# coordinates into plain geometric primitives. Nothing here knows about TikZ.
# ==============================================================================

"""
    checksupported(grid)

Throw a descriptive error if `grid` cannot be plotted by FerriteTikz. Grids embedded in one
or two spatial dimensions are supported; 3D is not implemented yet.
"""
function checksupported(grid::Ferrite.AbstractGrid)
    sdim = Ferrite.getspatialdim(grid)
    if !(sdim in (1, 2))
        throw(
            ArgumentError(
                "FerriteTikz currently only supports grids in one or two spatial dimensions, " *
                    "got a grid with spatial dimension $sdim. Support for 3D grids is not " *
                    "implemented yet."
            )
        )
    end
    return nothing
end

"""
    isline(cell) -> Bool

Whether `cell` is a line element, i.e. a cell of reference dimension one such as `Line` or
`QuadraticLine`. Line elements are drawn as stroked paths rather than filled areas, and
their [`celledges`](@ref) is the cell itself.
"""
isline(::Ferrite.AbstractCell) = false
isline(::Ferrite.AbstractCell{<:Ferrite.AbstractRefShape{1}}) = true

"""
    nodecoordinates(grid) -> Vector{Vec{2, T}}

The coordinates of all nodes of `grid`, in node order, lifted to two dimensions. Grids
embedded in one spatial dimension are drawn along the x axis, i.e. a node at `x` becomes
`(x, 0)`.
"""
function nodecoordinates(grid::Ferrite.AbstractGrid)
    return [to2d(Ferrite.get_node_coordinate(grid, i)) for i in 1:getnnodes(grid)]
end

"""
    to2d(x) -> Vec{2}

Lift a coordinate or displacement to two dimensions, placing one-dimensional data on the
x axis. Two-dimensional input is returned unchanged.

A bare `Real` is accepted because `Ferrite.evaluate_at_grid_nodes` returns plain scalars for
one-component fields, which is how a displacement field on a one-dimensional grid is usually
declared.
"""
to2d(x::Vec{2}) = x
to2d(x::Vec{1, T}) where {T} = Vec{2, T}((x[1], zero(T)))
to2d(x::T) where {T <: Real} = Vec{2, T}((x, zero(T)))

"""
    celledges(cell) -> Vector{NTuple{N, Int}}

The global node ids of every edge of `cell`, in local edge order. Each entry holds the two
end nodes first, followed by the interior nodes of that edge, i.e. `(n1, n2)` for a linear
edge and `(n1, n2, nmid)` for an edge with a quadratic geometric interpolation.

For an area cell the edges are its facets, resolved through `Ferrite.facetdof_indices`. This
is the same pattern Ferrite itself uses when writing facet sets to VTK, so higher-order cells
are handled without a per-cell-type lookup table.

For a line element (see [`isline`](@ref)) the facets are its two *end points*, which are not
edges at all — the drawable edge is the cell itself, so its node ids are returned as a single
entry. Ferrite orders those as `(start, end)` and `(start, end, mid)`, which already matches
the convention above.
"""
function celledges(cell::Ferrite.AbstractCell)
    gip = Ferrite.geometric_interpolation(typeof(cell))
    nodeids = Ferrite.get_node_ids(cell)
    return [map(i -> nodeids[i], facetdofs) for facetdofs in Ferrite.facetdof_indices(gip)]
end

celledges(cell::Ferrite.AbstractCell{<:Ferrite.AbstractRefShape{1}}) = [Ferrite.get_node_ids(cell)]

"""
    edgekey(edge) -> NTuple{2, Int}

Orientation-independent identity of an edge, used to draw shared edges only once.
"""
edgekey(edge) = minmax(edge[1], edge[2])

# ==============================================================================
# CURVED EDGES
# ==============================================================================

"""
    beziercontrolpoints(p1, p2, pm) -> (c1, c2)

The two cubic Bezier control points that reproduce *exactly* the quadratic Bezier curve
through the end points `p1`, `p2` with mid-side node `pm` at the parametric mid point.

The quadratic control point is `q = 2pm - (p1 + p2)/2`; degree elevation to a cubic gives
`c1 = p1 + 2/3 (q - p1)` and `c2 = p2 + 2/3 (q - p2)`. TikZ only speaks cubic Beziers
(`.. controls (c1) and (c2) ..`), hence the elevation.
"""
function beziercontrolpoints(p1::Vec{2}, p2::Vec{2}, pm::Vec{2})
    q = 2 * pm - (p1 + p2) / 2
    c1 = p1 + (2 // 3) * (q - p1)
    c2 = p2 + (2 // 3) * (q - p2)
    return c1, c2
end

"""
    EdgeSegment

A single edge of a cell, resolved to coordinates and ready to be emitted as TikZ.

- `from`, `to`: the corner points of the edge.
- `controls`: `nothing` for a straight edge, or the two cubic Bezier control points.
"""
struct EdgeSegment{T}
    from::Vec{2, T}
    to::Vec{2, T}
    controls::Union{Nothing, Tuple{Vec{2, T}, Vec{2, T}}}
end

"""
    edgesegment(coords, edge; bezier = true) -> EdgeSegment

Resolve the node ids in `edge` (see [`celledges`](@ref)) against the coordinate vector
`coords`. Edges with exactly one interior node are drawn as curves when `bezier` is `true`;
edges with more interior nodes than that are not representable by a single cubic Bezier and
fall back to a straight line.
"""
function edgesegment(coords::AbstractVector{Vec{2, T}}, edge; bezier::Bool = true) where {T}
    p1, p2 = coords[edge[1]], coords[edge[2]]
    if bezier && length(edge) == 3
        pm = coords[edge[3]]
        return EdgeSegment{T}(p1, p2, beziercontrolpoints(p1, p2, pm))
    end
    return EdgeSegment{T}(p1, p2, nothing)
end

"""
    celledgesegments(grid, coords, cellid; bezier = true) -> Vector{EdgeSegment}

The boundary of cell `cellid` as a closed, consecutively ordered sequence of edge segments.
"""
function celledgesegments(
        grid::Ferrite.AbstractGrid, coords::AbstractVector{<:Vec{2}}, cellid::Int;
        bezier::Bool = true
    )
    cell = getcells(grid, cellid)
    return [edgesegment(coords, edge; bezier) for edge in celledges(cell)]
end

# ==============================================================================
# CENTROIDS
# ==============================================================================

"""
    cellcentroid(grid, coords, cellid) -> Vec{2}

The centroid of cell `cellid`, obtained by mapping the centroid of the reference nodes
through the geometric interpolation of the cell. This places the point inside the cell also
for curved and non-convex elements, and is where cell labels are anchored.
"""
function cellcentroid(grid::Ferrite.AbstractGrid, coords::AbstractVector{Vec{2, T}}, cellid::Int) where {T}
    cell = getcells(grid, cellid)
    gip = Ferrite.geometric_interpolation(typeof(cell))
    refcoords = Ferrite.reference_coordinates(gip)
    ξ = sum(refcoords) / length(refcoords)
    nodeids = Ferrite.get_node_ids(cell)
    x = zero(Vec{2, T})
    for i in 1:Ferrite.getnbasefunctions(gip)
        x += Ferrite.reference_shape_value(gip, ξ, i) * coords[nodeids[i]]
    end
    return x
end

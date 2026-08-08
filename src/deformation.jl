# ==============================================================================
# DEFORMED CONFIGURATION
# ==============================================================================

"""
    nodedisplacements(dh::DofHandler, u::AbstractVector; field = :u) -> Vector{Vec{2}}
    nodedisplacements(grid, u::AbstractVector{<:Vec}) -> Vector{Vec{2}}
    nodedisplacements(grid, u::AbstractVector{<:Real}) -> Vector{Vec{2}}

The displacement of every grid node, in node order, lifted to two dimensions.

Given a `DofHandler` and a global solution vector, the nodal values of `field` are obtained
with `Ferrite.evaluate_at_grid_nodes`, i.e. by evaluating the shape functions of the field at
the reference coordinates of the nodes. The field must have as many components as the grid
has spatial dimensions. Nodes on which `field` is not defined come back as `NaN` from Ferrite
and are reported as zero displacement together with a warning.

Alternatively the displacements can be handed over directly, either as a vector of `Vec` of
length `getnnodes(grid)` or as a flat vector of length `sdim * getnnodes(grid)` laid out as
`[u1x, u1y, u2x, u2y, ...]`, where `sdim = Ferrite.getspatialdim(grid)`.

On a grid embedded in one spatial dimension the displacements may still be given as `Vec{2}`,
which draws the deflection of a one-dimensional mesh transverse to its axis.
"""
function nodedisplacements(dh::Ferrite.DofHandler, u::AbstractVector; field::Symbol = :u)
    grid = Ferrite.get_grid(dh)
    checksupported(grid)
    sdim = Ferrite.getspatialdim(grid)
    @argcheck field in Ferrite.getfieldnames(dh) "the DofHandler has no field :$field, available fields are $(Ferrite.getfieldnames(dh))"
    @argcheck length(u) == ndofs(dh) "length(u) == $(length(u)) does not match ndofs(dh) == $(ndofs(dh))"
    ncomp = Ferrite.n_components(dh, field)
    @argcheck ncomp == sdim "field :$field has $ncomp components, expected $sdim to match the spatial dimension of the grid"
    nodal = Ferrite.evaluate_at_grid_nodes(dh, u, field)
    return _replacenans(map(to2d, nodal))
end

_vdim(::AbstractVector{<:Vec{N}}) where {N} = N

function nodedisplacements(grid::Ferrite.AbstractGrid, u::AbstractVector{<:Vec})
    checksupported(grid)
    sdim = Ferrite.getspatialdim(grid)
    vdim = _vdim(u)
    @argcheck vdim in (sdim, 2) "displacements are Vec{$vdim} but the grid has spatial dimension $sdim"
    @argcheck length(u) == getnnodes(grid) "length(u) == $(length(u)) does not match getnnodes(grid) == $(getnnodes(grid))"
    return _replacenans(map(to2d, u))
end

function nodedisplacements(grid::Ferrite.AbstractGrid, u::AbstractVector{<:Real})
    checksupported(grid)
    sdim = Ferrite.getspatialdim(grid)
    nnodes = getnnodes(grid)
    @argcheck length(u) == sdim * nnodes "length(u) == $(length(u)) matches neither getnnodes(grid) == $nnodes (as a vector of Vec) nor $sdim * getnnodes(grid) == $(sdim * nnodes) (as a flat vector)"
    flat = [Vec{sdim}(ntuple(c -> u[sdim * (i - 1) + c], sdim)) for i in 1:nnodes]
    return _replacenans(map(to2d, flat))
end

function _replacenans(u::AbstractVector{<:Vec{2, T}}) where {T}
    any(x -> any(isnan, x), u) || return collect(u)
    @warn "the displacement field is not defined on all nodes of the grid; undefined nodes are drawn undeformed"
    return [any(isnan, x) ? zero(Vec{2, T}) : x for x in u]
end

"""
    deformedcoordinates(grid, u; scale = 1.0) -> Vector{Vec{2}}
    deformedcoordinates(dh::DofHandler, u; scale = 1.0, field = :u) -> Vector{Vec{2}}

The node coordinates of the deformed configuration, `x_i + scale * u_i`. The displacements
`u` are resolved by [`nodedisplacements`](@ref), so all of its input formats are accepted.
"""
function deformedcoordinates(dh::Ferrite.DofHandler, u::AbstractVector; scale::Real = 1.0, field::Symbol = :u)
    grid = Ferrite.get_grid(dh)
    return _deform(nodecoordinates(grid), nodedisplacements(dh, u; field), scale)
end

function deformedcoordinates(grid::Ferrite.AbstractGrid, u::AbstractVector; scale::Real = 1.0)
    return _deform(nodecoordinates(grid), nodedisplacements(grid, u), scale)
end

_deform(x, u, scale) = [xi + scale * ui for (xi, ui) in zip(x, u)]

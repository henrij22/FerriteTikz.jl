# ==============================================================================
# USER FACING API
# ==============================================================================

"""
    tikzgrid(grid::AbstractGrid; kwargs...) -> TikzPicture
    tikzgrid(grid::AbstractGrid, u::AbstractVector; scale = 1.0, reference = nothing, kwargs...)
    tikzgrid(dh::DofHandler, u::AbstractVector; field = :u, scale = 1.0, reference = nothing, kwargs...)

Draw a two-dimensional Ferrite grid as a `TikzPictures.TikzPicture`.

The result renders inline in VSCode, Pluto and IJulia and can be written to disk with the
usual `TikzPictures` machinery:

```julia
save(PDF("grid"), p)                        # standalone PDF
save(SVG("grid"), p)                        # standalone SVG
save(TEX("grid"), p)                        # standalone .tex document
save(TEX("grid"; limit_to = :picture), p)   # just the tikzpicture, for \\input
```

# Deformed configuration
Passing a displacement vector draws the deformed configuration `x_i + scale * u_i`:

- with a `DofHandler`, `u` is the global solution vector and the nodal displacements of
  `field` are extracted with `Ferrite.evaluate_at_grid_nodes`;
- with a bare grid, `u` is either a `Vector{Vec{2}}` of length `getnnodes(grid)` or a flat
  `Vector{<:Real}` of length `2 * getnnodes(grid)`.

`scale` is the displacement magnification factor.

# Overlaying the reference configuration
`reference` draws the undeformed grid underneath the deformed one. Pass a `NamedTuple` or a
[`GridStyle`](@ref) with the style it should be drawn in; it inherits every option not given
explicitly from the main style, except that it is never filled and carries no labels by
default:

```julia
tikzgrid(dh, u; scale = 20, cellcolor = "blue!15",
         reference = (linecolor = "gray", linestyle = "dashed"))
```

Pass `reference = true` to use the defaults, or leave it at `nothing` to draw the deformed
configuration alone.

# Styling
Everything else is forwarded to [`GridStyle`](@ref) — colours (`cellcolor`,
`cellsetcolors`, `linecolor`), line appearance (`linewidth`, `linestyle`), markers and
labels (`drawnodes`, `nodelabels`, `celllabels`) and geometry (`scale` of the picture via
`picturescale`, `bezier`).

!!! note
    The picture scale is exposed as `picturescale` in `tikzgrid` because `scale` is taken by
    the displacement magnification. `GridStyle` itself calls it `scale`.
"""
function tikzgrid end

function tikzgrid(grid::Ferrite.AbstractGrid; reference = nothing, kwargs...)
    checksupported(grid)
    style, refstyle = _styles(reference; kwargs...)
    coords = nodecoordinates(grid)
    return _picture(grid, coords, style, refstyle === nothing ? nothing : (coords, refstyle))
end

function tikzgrid(grid::Ferrite.AbstractGrid, u::AbstractVector; scale::Real = 1.0, reference = nothing, kwargs...)
    checksupported(grid)
    style, refstyle = _styles(reference; kwargs...)
    refcoords = nodecoordinates(grid)
    coords = deformedcoordinates(grid, u; scale)
    return _picture(grid, coords, style, refstyle === nothing ? nothing : (refcoords, refstyle))
end

function tikzgrid(dh::Ferrite.DofHandler, u::AbstractVector; field::Symbol = :u, scale::Real = 1.0, reference = nothing, kwargs...)
    grid = Ferrite.get_grid(dh)
    checksupported(grid)
    style, refstyle = _styles(reference; kwargs...)
    refcoords = nodecoordinates(grid)
    coords = deformedcoordinates(dh, u; scale, field)
    return _picture(grid, coords, style, refstyle === nothing ? nothing : (refcoords, refstyle))
end

"""
    TikzPictures.TikzPicture(grid::Ferrite.AbstractGrid; kwargs...)

Alias for [`tikzgrid`](@ref), mirroring the interface of Gridap's TikzPictures extension.
"""
TikzPictures.TikzPicture(grid::Ferrite.AbstractGrid; kwargs...) = tikzgrid(grid; kwargs...)
TikzPictures.TikzPicture(dh::Ferrite.DofHandler, u::AbstractVector; kwargs...) = tikzgrid(dh, u; kwargs...)

# ==============================================================================
# INTERNALS
# ==============================================================================

# Split the user's keyword arguments into the main style and the (optional) style of the
# reference configuration. The reference style inherits everything the user did not set
# explicitly on it, but never inherits the fills or the labels.
function _styles(reference; picturescale::Real = 1.0, kwargs...)
    style = GridStyle(; scale = picturescale, kwargs...)
    reference === nothing && return style, nothing
    reference === false && return style, nothing
    inherited = setproperties(
        style;
        cellcolor = nothing, cellsetcolors = Pair{String, TikzColor}[],
        drawnodes = false, nodelabels = false, celllabels = false,
    )
    reference === true && return style, inherited
    reference isa GridStyle && return style, reference
    return style, setproperties(inherited; pairs(reference)...)
end

function _picture(grid, coords, style::GridStyle, ref)
    reg = ColorRegistry()
    io = IOBuffer()
    if ref !== nothing
        refcoords, refstyle = ref
        gridcode!(io, reg, grid, refcoords, refstyle)
    end
    gridcode!(io, reg, grid, coords, style)
    return TikzPicture(
        String(take!(io));
        options = "scale=$(_fmt(style.scale, 6))",
        preamble = definecolors(reg),
    )
end

# ==============================================================================
# TIKZ CODE GENERATION
#
# The whole package funnels into `gridcode`, which turns a grid plus a coordinate vector
# plus a `GridStyle` into a TikZ string. Keeping this free of any LaTeX invocation makes
# the output testable without a TeX installation.
# ==============================================================================

"""
    coordstring(p::Vec{2}, digits::Int) -> String

A single TikZ coordinate `(x,y)` with the components rounded to `digits` digits.
"""
function coordstring(p::Vec{2}, digits::Int)
    return string("(", _fmt(p[1], digits), ",", _fmt(p[2], digits), ")")
end

function _fmt(x::Real, digits::Int)
    s = Printf.format(Printf.Format("%.$(digits)f"), float(x))
    # trim trailing zeros, they only bloat the emitted .tex file
    if occursin('.', s)
        s = rstrip(rstrip(s, '0'), '.')
    end
    # "-0.00000" must not come out as "-0"
    return (isempty(s) || all(c -> c in ".-0", s)) ? "0" : s
end

"""
    appendsegment!(io, seg::EdgeSegment, digits; moveto = false)

Append the path fragment for `seg` to `io`. With `moveto = true` the starting point is
emitted as well, otherwise the fragment continues an existing path.
"""
function appendsegment!(io::IO, seg::EdgeSegment, digits::Int; moveto::Bool = false, close::Bool = false)
    moveto && print(io, coordstring(seg.from, digits))
    target = close ? "cycle" : coordstring(seg.to, digits)
    if seg.controls === nothing
        print(io, " -- ", target)
    else
        c1, c2 = seg.controls
        print(io, " .. controls ", coordstring(c1, digits), " and ", coordstring(c2, digits), " .. ", target)
    end
    return io
end

"""
    cellpath(grid, coords, cellid, style) -> String

The closed TikZ path around cell `cellid`, used for the cell fill.
"""
function cellpath(grid::Ferrite.AbstractGrid, coords::AbstractVector{<:Vec{2}}, cellid::Int, style::GridStyle)
    segments = celledgesegments(grid, coords, cellid; bezier = style.bezier)
    io = IOBuffer()
    for (i, seg) in enumerate(segments)
        appendsegment!(io, seg, style.digits; moveto = (i == 1), close = (i == length(segments)))
    end
    return String(take!(io))
end

"""
    optionstring(parts...) -> String

Join non-empty TikZ options with `", "`.
"""
optionstring(parts...) = join(Iterators.filter(!isempty, parts), ", ")

# ==============================================================================
# THE INDIVIDUAL LAYERS
# ==============================================================================

function fillcode!(io::IO, reg::ColorRegistry, grid, coords, style::GridStyle)
    fills = cellfills(grid, style)
    all(isnothing, fills) && return io
    opacity = style.fillopacity < 1 ? "opacity=$(_fmt(style.fillopacity, 3))" : ""
    for cellid in 1:getncells(grid)
        color = fills[cellid]
        color === nothing && continue
        opts = optionstring(tikzcolor(reg, color), opacity)
        println(io, "\\fill[", opts, "] ", cellpath(grid, coords, cellid, style), ";")
    end
    return io
end

function wireframecode!(io::IO, reg::ColorRegistry, grid, coords, style::GridStyle)
    style.drawcells || return io
    opts = optionstring(style.linewidth, tikzcolor(reg, style.linecolor), style.linestyle)
    drawn = Set{NTuple{2, Int}}()
    for cellid in 1:getncells(grid)
        cell = getcells(grid, cellid)
        for edge in celledges(cell)
            key = edgekey(edge)
            key in drawn && continue   # interior edges are shared, draw them once
            push!(drawn, key)
            seg = edgesegment(coords, edge; bezier = style.bezier)
            print(io, "\\draw[", opts, "] ")
            appendsegment!(io, seg, style.digits; moveto = true)
            println(io, ";")
        end
    end
    return io
end

function nodecode!(io::IO, ::ColorRegistry, grid, coords, style::GridStyle)
    (style.drawnodes || style.nodelabels) || return io
    for nodeid in 1:getnnodes(grid)
        p = coords[nodeid]
        if style.drawnodes
            println(io, "\\node[", style.nodestyle, "] at ", coordstring(p, style.digits), " {};")
        end
        if style.nodelabels
            q = p + Vec{2}((style.labeloffset, style.labeloffset))
            println(io, "\\node[", style.labelstyle, "] at ", coordstring(q, style.digits), " {\$", nodeid, "\$};")
        end
    end
    return io
end

function celllabelcode!(io::IO, ::ColorRegistry, grid, coords, style::GridStyle)
    style.celllabels || return io
    for cellid in 1:getncells(grid)
        p = cellcentroid(grid, coords, cellid)
        println(io, "\\node[", style.labelstyle, "] at ", coordstring(p, style.digits), " {\$", cellid, "\$};")
    end
    return io
end

# ==============================================================================
# ENTRY POINTS
# ==============================================================================

"""
    gridcode!(io, reg::ColorRegistry, grid, coords, style::GridStyle)

Write the TikZ body for one grid (fills, wireframe, node markers, labels) to `io`,
registering any `Colorant`s in `reg`. Call this repeatedly with the same `reg` to compose
several grids into one picture, e.g. the reference and the deformed configuration.
"""
function gridcode!(io::IO, reg::ColorRegistry, grid::Ferrite.AbstractGrid, coords::AbstractVector{<:Vec{2}}, style::GridStyle)
    checksupported(grid)
    @argcheck length(coords) == getnnodes(grid) "length(coords) == $(length(coords)) does not match getnnodes(grid) == $(getnnodes(grid))"
    fillcode!(io, reg, grid, coords, style)
    wireframecode!(io, reg, grid, coords, style)
    nodecode!(io, reg, grid, coords, style)
    celllabelcode!(io, reg, grid, coords, style)
    return io
end

"""
    tikzcode(grid; kwargs...) -> String
    tikzcode(grid, u; scale = 1.0, kwargs...) -> String
    tikzcode(dh::DofHandler, u; field = :u, scale = 1.0, kwargs...) -> String

The raw TikZ code for a grid, i.e. the body of the `tikzpicture` environment, *without* the
`\\definecolor` statements (those live in the preamble of the [`TikzPicture`](@ref) built by
[`tikzgrid`](@ref)). Useful for composing pictures by hand.

All keyword arguments are documented in [`GridStyle`](@ref). See [`tikzgrid`](@ref) for the
meaning of `u`, `scale`, `field` and `reference`.
"""
function tikzcode(args...; kwargs...)
    picture = tikzgrid(args...; kwargs...)
    return picture.data
end

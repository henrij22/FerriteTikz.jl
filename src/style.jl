# ==============================================================================
# COLOURS
# ==============================================================================

"""
    TikzColor

Anything that can be used as a colour in `FerriteTikz`: an xcolor expression given as a
`String` (e.g. `"blue!20"`, `"black"`) or any `Colors.Colorant` (e.g. `colorant"#a6cee3"`,
`RGB(0.2, 0.4, 0.9)`). `Colorant`s are emitted as `\\definecolor` statements, `String`s are
passed through to TikZ verbatim.
"""
const TikzColor = Union{AbstractString, Colorant}

"""
    ColorRegistry()

Collects the `Colorant`s used by a picture and assigns them stable TikZ names so that they
can be emitted as `\\definecolor` statements ahead of the drawing commands.
"""
struct ColorRegistry
    names::Dict{Colorant, String}
    order::Vector{Pair{String, Colorant}}
end

ColorRegistry() = ColorRegistry(Dict{Colorant, String}(), Pair{String, Colorant}[])

"""
    tikzcolor(reg::ColorRegistry, c) -> String

Return the TikZ colour expression for `c`, registering a new `\\definecolor` name when `c` is
a `Colorant`.
"""
tikzcolor(::ColorRegistry, c::AbstractString) = String(c)

function tikzcolor(reg::ColorRegistry, c::Colorant)
    return get!(reg.names, c) do
        name = "ftcolor$(length(reg.order) + 1)"
        push!(reg.order, name => c)
        return name
    end
end

"""
    definecolors(reg::ColorRegistry) -> String

The `\\definecolor` preamble for every `Colorant` registered in `reg`.
"""
function definecolors(reg::ColorRegistry)
    isempty(reg.order) && return ""
    io = IOBuffer()
    for (name, c) in reg.order
        rgb = convert(RGB{Float64}, c)
        r, g, b = round.(Int, 255 .* (red(rgb), green(rgb), blue(rgb)))
        println(io, "\\definecolor{", name, "}{RGB}{", r, ",", g, ",", b, "}")
    end
    return String(take!(io))
end

# ==============================================================================
# STYLE
# ==============================================================================

"""
    GridStyle(; kwargs...)

Styling options for [`tikzgrid`](@ref) and [`tikzcode`](@ref). All keyword arguments of
`tikzgrid` that are not listed in its own docstring are forwarded here.

# Geometry
- `scale = 1.0`: TikZ `scale=` factor, i.e. how many TikZ units one grid unit corresponds to.
- `bezier = true`: draw curved edges for cells with a quadratic geometric interpolation. Set
  to `false` to draw every edge as a straight line between its corner nodes.
- `digits = 5`: number of digits coordinates are rounded to in the emitted TikZ code.

# Lines
- `linewidth = "thin"`: TikZ line width key (`"ultra thin"`, `"thin"`, `"thick"`, …, or
  something like `"line width=0.6pt"`).
- `linecolor = "black"`: wireframe colour, see [`TikzColor`](@ref).
- `linestyle = ""`: extra TikZ options for the wireframe, e.g. `"dashed"` or `"densely dotted"`.
- `drawcells = true`: draw the wireframe at all. `false` gives a fills-only picture.

# Cell fills (flat/constant per cell)
- `cellcolor = nothing`: uniform fill colour for all cells. `nothing` means no fill.
- `cellsetcolors = []`: cell set names (see `Ferrite.getcellset`) mapped to colours, given as
  a vector of pairs (`["steel" => "blue!20", "rubber" => colorant"#e31a1c"]`) or as a `Dict`.
  Cells in one of these sets are filled with the corresponding colour instead of `cellcolor`.
  If a cell belongs to several listed sets, the *last* matching pair wins, so pass a vector
  when the order matters.
- `fillopacity = 1.0`: opacity of the cell fills.

# Nodes and labels
- `drawnodes = false`: draw a marker at every node.
- `nodestyle = "circle, fill=black, inner sep=0pt, minimum size=0.08cm"`: TikZ options for
  node markers.
- `nodelabels = false`: print the global node number next to every node.
- `celllabels = false`: print the global cell number at every cell centroid.
- `labelstyle = "font=\\\\scriptsize"`: TikZ options for the labels.
- `labeloffset = 0.06`: offset of node labels from the node, in grid units.
"""
struct GridStyle
    # geometry
    scale::Float64
    bezier::Bool
    digits::Int
    # lines
    linewidth::String
    linecolor::TikzColor
    linestyle::String
    drawcells::Bool
    # fills
    cellcolor::Union{Nothing, TikzColor}
    cellsetcolors::Vector{Pair{String, TikzColor}}
    fillopacity::Float64
    # nodes and labels
    drawnodes::Bool
    nodestyle::String
    nodelabels::Bool
    celllabels::Bool
    labelstyle::String
    labeloffset::Float64
end

function GridStyle(;
        scale = 1.0,
        bezier = true,
        digits = 5,
        linewidth = "thin",
        linecolor = "black",
        linestyle = "",
        drawcells = true,
        cellcolor = nothing,
        cellsetcolors = Pair{String, TikzColor}[],
        fillopacity = 1.0,
        drawnodes = false,
        nodestyle = "circle, fill=black, inner sep=0pt, minimum size=0.08cm",
        nodelabels = false,
        celllabels = false,
        labelstyle = "font=\\scriptsize",
        labeloffset = 0.06,
    )
    return GridStyle(
        scale, bezier, digits,
        linewidth, linecolor, linestyle, drawcells,
        cellcolor, _setcolorpairs(cellsetcolors), fillopacity,
        drawnodes, nodestyle, nodelabels, celllabels, labelstyle, labeloffset,
    )
end

_setcolorpairs(x) = Pair{String, TikzColor}[String(k) => v for (k, v) in x]

GridStyle(style::GridStyle) = style
GridStyle(nt::NamedTuple) = GridStyle(; nt...)

"""
    setproperties(style::GridStyle; kwargs...) -> GridStyle

Copy of `style` with the given fields replaced. Used to derive the reference-configuration
style from the deformed one.
"""
function setproperties(style::GridStyle; kwargs...)
    args = map(fieldnames(GridStyle)) do name
        return haskey(kwargs, name) ? kwargs[name] : getfield(style, name)
    end
    return GridStyle(args...)
end

"""
    cellfills(grid, style::GridStyle) -> Vector{Union{Nothing, TikzColor}}

Resolve the constant fill colour of every cell of `grid`: `style.cellcolor` by default,
overridden by `style.cellsetcolors` for cells contained in one of the named cell sets.
"""
function cellfills(grid::Ferrite.AbstractGrid, style::GridStyle)
    fills = Union{Nothing, TikzColor}[style.cellcolor for _ in 1:getncells(grid)]
    for (setname, color) in style.cellsetcolors
        @argcheck haskey(Ferrite.getcellsets(grid), setname) "grid has no cell set \"$setname\""
        for cellid in getcellset(grid, setname)
            fills[cellid] = color
        end
    end
    return fills
end

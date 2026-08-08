# FerriteTikz.jl

[![Documentation](https://img.shields.io/badge/docs-stable-blue.svg)](https://henrij22.github.io/FerriteTikz.jl/stable)
[![CI](https://github.com/henrij22/FerriteTikz.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/henrij22/FerriteTikz.jl/actions/workflows/CI.yml)

Publication-grade TikZ graphics of [Ferrite.jl](https://github.com/Ferrite-FEM/Ferrite.jl)
grids. FerriteTikz emits plain TikZ code and hands it to
[TikzPictures.jl](https://github.com/JuliaTeX/TikzPictures.jl), so the figures use the fonts,
line widths and colours of the document they end up in — and they stay vector graphics all
the way into the PDF.

The focus is wireframes with flat, constant per-cell colouring, and the deformed
configuration of a finite element solution. Two-dimensional grids are supported;
`Triangle`, `Quadrilateral` and their quadratic variants, the latter drawn with true curved
edges.

For interactive exploration of a solution field, use
[FerriteViz.jl](https://github.com/Ferrite-FEM/FerriteViz.jl) instead — the two packages are
complementary.

## Installation

```julia
julia> ]add FerriteTikz
```

## Usage

```julia
using FerriteTikz

grid = generate_grid(Quadrilateral, (8, 4))
p = tikzgrid(grid; cellcolor = "blue!12", picturescale = 1.5)

save(PDF("grid"), p)                        # standalone PDF
save(SVG("grid"), p)                        # standalone SVG
save(TEX("grid"; limit_to = :picture), p)   # just the tikzpicture, ready to \input
```

The picture also renders inline in VSCode, Pluto and IJulia.

### Colouring cells by cell set

```julia
addcellset!(grid, "steel",  x -> x[1] <= 0.0)
addcellset!(grid, "rubber", x -> x[1] >  0.0)

tikzgrid(grid; cellsetcolors = ["steel" => "gray!30", "rubber" => colorant"#e31a1c"])
```

Colours are either xcolor expressions given as `String`s (`"blue!20"`) or any
`Colors.Colorant`, which is emitted as a `\definecolor` statement in the preamble.

### The deformed configuration

```julia
p = tikzgrid(
    dh, u;                                  # DofHandler and global solution vector
    field = :u,                             # the displacement field
    scale = 20,                             # displacement magnification
    cellcolor = "blue!12",
    reference = (linecolor = "gray", linestyle = "dashed"),   # undeformed grid underneath
)
```

Instead of a `DofHandler`, nodal displacements can be passed directly, either as a
`Vector{Vec{2}}` or as a flat `Vector{<:Real}` of length `2 * getnnodes(grid)`.

### Element and mesh figures for papers

```julia
grid = generate_grid(QuadraticTriangle, (2, 2))
tikzgrid(
    grid;
    drawnodes = true, nodelabels = true, celllabels = true,
    linewidth = "thick", picturescale = 3,
)
```

Every styling option is documented in `GridStyle`.

## Why TikZ and not a plotting package

`tikzgrid` produces TikZ path commands (`\fill`, `\draw`, `\node`) rather than a plot with
axes, which is what a mesh figure actually needs: curved element edges become real cubic
Bézier segments, shared element edges are stroked exactly once, and the whole picture is a
handful of lines of LaTeX you can post-process by hand if a reviewer asks for it. Use
`tikzcode(...)` to get that code as a `String`.

## License

MIT, see [LICENSE](LICENSE).

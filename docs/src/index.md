# FerriteTikz.jl

Publication-grade TikZ graphics of [Ferrite.jl](https://github.com/Ferrite-FEM/Ferrite.jl)
grids.

FerriteTikz emits plain TikZ code and hands it to
[TikzPictures.jl](https://github.com/JuliaTeX/TikzPictures.jl). The figures therefore use the
fonts, line widths and colours of the document they end up in, and they stay vector graphics
all the way into the final PDF. The focus is wireframes with flat, constant per-cell
colouring, and the deformed configuration of a finite element solution.

Supported are grids in one or two spatial dimensions:

- **area cells** — `Triangle`, `Quadrilateral`, `QuadraticTriangle`,
  `QuadraticQuadrilateral` and `SerendipityQuadraticQuadrilateral`;
- **line elements** — `Line` and `QuadraticLine`, in 1D space (a one-dimensional mesh, drawn
  along the x axis) or in 2D space (trusses and frames). A grid may mix both.

Cells with a quadratic geometric interpolation are drawn with true curved edges.

!!! tip "Which package do I want?"
    Use [FerriteViz.jl](https://github.com/Ferrite-FEM/FerriteViz.jl) to *explore* a solution
    interactively, with colour maps, warping, clipping and 3D. Use FerriteTikz to produce the
    static mesh and deformation figures that go into a paper or a thesis. The two are
    complementary.

## Installation

```julia
julia> ]add FerriteTikz
```

## A first picture

```@example index
using FerriteTikz
TikzPictures.tikzUseTectonic(true) # hide

grid = generate_grid(Quadrilateral, (8, 4))
tikzgrid(grid; cellcolor = "blue!12", picturescale = 1.2)
```

The returned object is a `TikzPictures.TikzPicture`. It renders inline in VSCode, Pluto and
IJulia, and it is written to disk with the usual `TikzPictures` machinery:

```julia
save(PDF("grid"), p)                        # standalone PDF
save(SVG("grid"), p)                        # standalone SVG
save(TEX("grid"), p)                        # standalone .tex document
save(TEX("grid"; limit_to = :picture), p)   # just the tikzpicture, ready to \input
```

`save(TEX(...); limit_to = :picture)` is usually what you want for a paper: the figure is
`\input` into the document and picks up its font and colour definitions automatically.

## The generated code

Nothing is hidden — [`tikzcode`](@ref) returns exactly the code that goes inside the
`tikzpicture` environment, so a figure can always be tweaked by hand afterwards:

```@example index
grid = generate_grid(Quadrilateral, (2, 1))
print(tikzcode(grid; cellcolor = "blue!12", drawnodes = true))
```

Note that the shared interior edge is drawn once, not twice.

## Where to go next

- [Tutorials overview](tutorials/index.md)
- [API Reference](api_reference.md)

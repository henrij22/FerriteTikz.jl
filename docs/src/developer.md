# Developer documentation

## Layout

The package is three layers deep, so that the TikZ output can be tested without ever
invoking LaTeX.

| File | Responsibility |
|---|---|
| `src/style.jl` | [`GridStyle`](@ref), colour handling, `\definecolor` bookkeeping |
| `src/geometry.jl` | grid → geometric primitives (edges, Bézier control points, centroids). Knows nothing about TikZ. |
| `src/deformation.jl` | displacement vector → deformed nodal coordinates |
| `src/tikzcode.jl` | primitives + style → TikZ `String` |
| `src/plot.jl` | the user-facing `tikzgrid` API and `TikzPicture` construction |

Everything funnels through `FerriteTikz.gridcode!(io, reg, grid, coords, style)`, which
writes the fills, the wireframe, the node markers and the labels for *one* set of
coordinates. The reference/deformed overlay is just that function called twice with the same
grid and different coordinates.

## How cell edges are resolved

`FerriteTikz.celledges` does not carry a per-cell-type table of edges. It asks Ferrite:

```julia
gip = Ferrite.geometric_interpolation(typeof(cell))
nodeids = Ferrite.get_node_ids(cell)
[map(i -> nodeids[i], dofs) for dofs in Ferrite.facetdof_indices(gip)]
```

`facetdof_indices` lists the corner nodes of a facet first, followed by its interior nodes,
so a linear cell yields `(n1, n2)` and a cell with a quadratic geometric interpolation yields
`(n1, n2, nmid)`. Support for a new 2D cell type therefore requires no changes here — this is
the same pattern Ferrite itself uses in `write_facetset` for VTK export.

In 2D, `Ferrite.facets(cell) == Ferrite.edges(cell)`, which is why facet indices are the
right thing to ask for.

## Curved edges

A quadratic element edge is a quadratic Bézier curve with control point
`q = 2 pₘ - (p₁ + p₂)/2`. TikZ only understands cubic Béziers, so
`FerriteTikz.beziercontrolpoints` degree-elevates it:

```
c₁ = p₁ + ⅔ (q - p₁)
c₂ = p₂ + ⅔ (q - p₂)
```

This is exact, not an approximation. Edges with more than one interior node cannot be
represented by a single cubic and fall back to straight lines.

## Drawing shared edges once

`FerriteTikz.wireframecode!` keeps a `Set{NTuple{2, Int}}` of
`FerriteTikz.edgekey(edge) = minmax(edge[1], edge[2])`, so an interior edge shared by two
cells is stroked exactly once. This matters for translucent line colours and keeps the
emitted `.tex` roughly half the size on a structured mesh.

Fills are emitted before the wireframe, so the element outlines always stay visible.

## Extending to 3D

`FerriteTikz.checksupported` is the single gate: it rejects anything with
`Ferrite.getspatialdim(grid) != 2`. A 3D implementation needs

1. a projection `Vec{3} → Vec{2}` (TikZ's `[x=…, y=…, z=…]` or an explicit camera),
2. visibility handling — FerriteViz solves this by only keeping boundary cells, using
   `topology.face_face_neighbor`,
3. painter's-algorithm depth sorting of the filled facets.

Steps 1 and 3 belong in `src/geometry.jl` and `src/tikzcode.jl`; the style and deformation
layers are already dimension-agnostic apart from their `Vec{2}` signatures.

## Tests

Tests use `TestItems`/`TestItemRunner`, so individual `@testitem` blocks can be run from the
VSCode test explorer. They assert on the *emitted string*, which needs no LaTeX.

The end-to-end rendering test in `test/testrender.jl` actually compiles the output for every
supported cell type. It is skipped by default because it needs a LaTeX installation (or lets
TikzPictures download packages through the bundled Tectonic). Enable it with

```
FERRITETIKZ_TEST_RENDER=true julia --project -e 'using Pkg; Pkg.test()'
```

## Formatting

The repository is formatted with [Runic](https://github.com/fredrikekre/Runic.jl) and checked
in CI:

```
julia -e 'using Runic; Runic.main(["--inplace", "src", "test", "docs"])'
```

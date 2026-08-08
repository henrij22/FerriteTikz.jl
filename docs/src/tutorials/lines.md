# Line elements

```@example lines
using FerriteTikz
TikzPictures.tikzUseTectonic(true) # hide
nothing # hide
```

`Line` and `QuadraticLine` cells are supported in both one- and two-dimensional space. They
cover one-dimensional meshes, trusses, frames and reinforcement bars embedded in a solid.

Because a line element encloses no area, it is treated differently from an area cell in two
ways:

1. it is **stroked, never filled** — `cellcolor` and `cellsetcolors` set the *stroke* colour;
2. it is drawn **once per cell, without deduplication** — a member is an element in its own
   right, not a boundary shared between two cells.

## One-dimensional meshes

A grid with `Ferrite.getspatialdim(grid) == 1` is drawn along the x axis:

```@example lines
grid = generate_grid(Line, (6,))
tikzgrid(grid; drawnodes = true, nodelabels = true, celllabels = true, picturescale = 3)
```

## Trusses and frames

The same cells in a two-dimensional grid give a truss. `cellsetcolors` is the natural way to
pick out members:

```@example lines
nodes = [
    Node((0.0, 0.0)), Node((1.0, 0.0)), Node((2.0, 0.0)), Node((3.0, 0.0)),
    Node((0.5, 0.8)), Node((1.5, 0.8)), Node((2.5, 0.8)),
]
members = [
    Line((1, 2)), Line((2, 3)), Line((3, 4)),          # bottom chord
    Line((5, 6)), Line((6, 7)),                        # top chord
    Line((1, 5)), Line((5, 2)), Line((2, 6)),          # web
    Line((6, 3)), Line((3, 7)), Line((7, 4)),
]
truss = Grid(members, nodes)
addcellset!(truss, "bottom", 1:3)
addcellset!(truss, "top", 4:5)

tikzgrid(
    truss;
    cellsetcolors = ["bottom" => "blue!60!black", "top" => "red!60!black"],
    linewidth = "thick", drawnodes = true, picturescale = 2,
)
```

## Curved line elements

A `QuadraticLine` bent out of its chord is drawn as an exact cubic Bézier, the same machinery
that curves quadratic triangle and quadrilateral edges:

```@example lines
arch = Grid(
    [QuadraticLine((1, 2, 3)), QuadraticLine((2, 4, 5))],
    [
        Node((0.0, 0.0)), Node((2.0, 1.0)), Node((1.0, 0.75)),
        Node((4.0, 0.0)), Node((3.0, 0.75)),
    ],
)
tikzgrid(arch; linewidth = "very thick", drawnodes = true, picturescale = 1.5)
```

## Mixing line and area cells

A grid may hold both. The quadrilaterals are filled and their shared edges drawn once; the
bar is stroked on top in its own colour:

```@example lines
nodes = [Node((Float64(i), Float64(j))) for j in 0:2 for i in 0:3]
idx(i, j) = j * 4 + i + 1
quads = [Quadrilateral((idx(i, j), idx(i + 1, j), idx(i + 1, j + 1), idx(i, j + 1))) for j in 0:1 for i in 0:2]
bars = [Line((idx(i, 1), idx(i + 1, 1))) for i in 0:2]

reinforced = Grid(Union{Quadrilateral, Line}[quads; bars], nodes)
addcellset!(reinforced, "rebar", (length(quads) + 1):(length(quads) + length(bars)))

tikzgrid(
    reinforced;
    cellcolor = "gray!20", cellsetcolors = ["rebar" => "red"],
    linewidth = "thick", picturescale = 1.5,
)
```

## Deflection of a one-dimensional mesh

Displacements normally live in the grid's own space, so a scalar field on a 1D grid moves the
nodes along the x axis. Passing `Vec{2}` displacements instead draws a **transverse
deflection**, which is what you usually want for a beam:

```@example lines
grid = generate_grid(Line, (24,))
w = [Vec{2}((0.0, 0.4 * (1 - x[1]^2)^2)) for x in Ferrite.get_node_coordinate.((grid,), 1:getnnodes(grid))]

tikzgrid(
    grid, w;
    linewidth = "thick",
    reference = (linecolor = "gray", linestyle = "dashed"),
    picturescale = 3,
)
```

The reference-configuration overlay works exactly as it does for area cells, so the
undeformed axis is drawn dashed underneath.

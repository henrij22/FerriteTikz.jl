# API Reference

## Plotting

```@docs
tikzgrid
tikzcode
```

## Styling

```@docs
GridStyle
FerriteTikz.TikzColor
```

## Deformation

```@docs
deformedcoordinates
nodedisplacements
```

## Composing several grids into one picture

[`tikzgrid`](@ref) already draws a reference and a deformed configuration together. For more
layers than that — a load history, a sequence of refinements, several patches side by side —
build the picture up one grid at a time between [`setupMultiPlot`](@ref) and
[`drawMultiPlot`](@ref):

```julia
io, reg = setupMultiPlot()
gridcode!(io, reg, grid, coords_0, GridStyle(linecolor = "gray", linestyle = "dashed"))
gridcode!(io, reg, grid, coords_1, GridStyle(linecolor = "blue"))
gridcode!(io, reg, grid, coords_2, GridStyle(linecolor = "red"))
p = drawMultiPlot(io, reg; picturescale = 2)
```

Each [`gridcode!`](@ref) call appends one layer, in drawing order, with its own
[`GridStyle`](@ref). Sharing the one registry is what keeps a `Colors.Colorant` used by
several layers down to a single `\definecolor` statement.

```@docs
setupMultiPlot
drawMultiPlot
gridcode!
```

The pieces those two functions wrap, should you want to drive the process yourself:

```@docs
FerriteTikz.ColorRegistry
FerriteTikz.tikzcolor
FerriteTikz.definecolors
FerriteTikz.setproperties
FerriteTikz.cellfills
```

## Geometry

```@docs
FerriteTikz.checksupported
FerriteTikz.isline
FerriteTikz.to2d
FerriteTikz.nodecoordinates
FerriteTikz.celledges
FerriteTikz.edgekey
FerriteTikz.beziercontrolpoints
FerriteTikz.EdgeSegment
FerriteTikz.edgesegment
FerriteTikz.celledgesegments
FerriteTikz.cellcentroid
```

## Code generation internals

```@docs
FerriteTikz.coordstring
FerriteTikz.appendsegment!
FerriteTikz.cellpath
FerriteTikz.optionstring
```

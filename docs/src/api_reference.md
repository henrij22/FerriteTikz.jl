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

## Composing pictures by hand

The picture body is built by writing one grid at a time into an `IO`, sharing a
[`FerriteTikz.ColorRegistry`](@ref) so that `\definecolor` statements are emitted once. Use
this to stack more than the two configurations [`tikzgrid`](@ref) handles itself:

```julia
reg = FerriteTikz.ColorRegistry()
io = IOBuffer()
FerriteTikz.gridcode!(io, reg, grid, coords_0, GridStyle(linecolor = "gray"))
FerriteTikz.gridcode!(io, reg, grid, coords_1, GridStyle(linecolor = "blue"))
FerriteTikz.gridcode!(io, reg, grid, coords_2, GridStyle(linecolor = "red"))
p = TikzPicture(String(take!(io)); preamble = FerriteTikz.definecolors(reg))
```

```@docs
FerriteTikz.gridcode!
FerriteTikz.ColorRegistry
FerriteTikz.tikzcolor
FerriteTikz.definecolors
FerriteTikz.setproperties
FerriteTikz.cellfills
```

## Geometry

```@docs
FerriteTikz.checksupported
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

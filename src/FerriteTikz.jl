module FerriteTikz

# ==============================================================================
# DEPENDENCIES
# ==============================================================================

# Core Julia packages
using Printf: Printf

# Utility packages
using Reexport
using ArgCheck
using Colors: Colorant, RGB, red, green, blue

# Backend packages (re-exported)
@reexport using Ferrite
@reexport using TikzPictures

using Ferrite: Ferrite, Vec

# ==============================================================================
# MODULE STRUCTURE
# ==============================================================================

include("style.jl")
include("geometry.jl")
include("deformation.jl")
include("tikzcode.jl")
include("plot.jl")

# ==============================================================================
# EXPORTS
# ==============================================================================

# Plotting
export tikzgrid, tikzcode

# Composing several grids into one picture
export setupMultiPlot, drawMultiPlot, gridcode!

# Styling
export GridStyle, TikzColor

# Deformation
export deformedcoordinates, nodedisplacements

end # module FerriteTikz

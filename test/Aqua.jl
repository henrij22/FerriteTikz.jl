@testitem "Aqua.jl" begin
    using Aqua

    # `TikzPicture(grid)` is a deliberate alias for `tikzgrid`, mirroring Gridap's interface
    Aqua.test_all(FerriteTikz; piracies = false)
end

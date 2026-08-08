@testitem "Composing several grids into one picture" begin
    using Colors
    using FerriteTikz: nodecoordinates

    grid = generate_grid(Quadrilateral, (2, 2))
    c0 = nodecoordinates(grid)
    c1 = deformedcoordinates(grid, [Vec{2}((0.1, 0.0)) for _ in c0])
    c2 = deformedcoordinates(grid, [Vec{2}((0.2, 0.0)) for _ in c0])

    io, reg = setupMultiPlot()
    @test io isa IOBuffer
    @test reg isa FerriteTikz.ColorRegistry

    gridcode!(io, reg, grid, c0, GridStyle(linecolor = "gray", linestyle = "dashed"))
    gridcode!(io, reg, grid, c1, GridStyle(linecolor = "blue"))
    gridcode!(io, reg, grid, c2, GridStyle(linecolor = "red"))
    p = drawMultiPlot(io, reg; picturescale = 2.5)

    @test p isa TikzPicture
    @test p.options == "scale=2.5"
    # three layers of a 2x2 grid, 12 unique edges each
    @test count("\\draw", p.data) == 36
    @test count("\\draw[thin, gray, dashed]", p.data) == 12
    @test count("\\draw[thin, blue]", p.data) == 12
    @test count("\\draw[thin, red]", p.data) == 12
    # the layers are emitted in the order they were added
    @test findfirst("gray", p.data)[1] < findfirst("blue", p.data)[1] < findfirst("red", p.data)[1]

    # the buffer is emptied, so a fresh setup is independent
    io2, reg2 = setupMultiPlot()
    gridcode!(io2, reg2, grid, c0, GridStyle())
    @test count("\\draw", drawMultiPlot(io2, reg2).data) == 12
end

@testitem "One registry keeps definecolor statements unique" begin
    using Colors

    grid = generate_grid(Quadrilateral, (2, 2))
    coords = FerriteTikz.nodecoordinates(grid)
    c = colorant"#1f78b4"

    io, reg = setupMultiPlot()
    # the same Colorant used as a line colour, as a fill, and again in a second layer
    gridcode!(io, reg, grid, coords, GridStyle(linecolor = c, cellcolor = c))
    gridcode!(io, reg, grid, coords, GridStyle(linecolor = c))
    gridcode!(io, reg, grid, coords, GridStyle(linecolor = RGB(1.0, 0.0, 0.0)))
    p = drawMultiPlot(io, reg)

    @test count("\\definecolor", p.preamble) == 2
    @test occursin("\\definecolor{ftcolor1}{RGB}{31,120,180}", p.preamble)
    @test occursin("\\definecolor{ftcolor2}{RGB}{255,0,0}", p.preamble)
end

@testitem "drawMultiPlot accepts the setup tuple directly" begin
    grid = generate_grid(Triangle, (1, 1))
    setup = setupMultiPlot()
    gridcode!(setup[1], setup[2], grid, FerriteTikz.nodecoordinates(grid), GridStyle())

    p = drawMultiPlot(setup; picturescale = 3)
    @test p.options == "scale=3"
    @test count("\\draw", p.data) == 5

    # default scale, and an empty picture is still valid
    @test drawMultiPlot(setupMultiPlot()).options == "scale=1"
    @test isempty(drawMultiPlot(setupMultiPlot()).data)
end

@testitem "Multi-layer pictures work for line meshes too" begin
    grid = generate_grid(Line, (4,))
    coords = FerriteTikz.nodecoordinates(grid)

    io, reg = setupMultiPlot()
    for (i, color) in enumerate(("gray", "blue", "red"))
        shifted = deformedcoordinates(grid, [Vec{2}((0.0, 0.15 * i)) for _ in coords])
        gridcode!(io, reg, grid, shifted, GridStyle(linecolor = color, linewidth = "thick"))
    end
    p = drawMultiPlot(io, reg)

    @test count("\\draw", p.data) == 12
    @test count("\\draw[thick, red]", p.data) == 4
end

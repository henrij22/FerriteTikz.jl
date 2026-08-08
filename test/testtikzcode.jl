@testitem "Shared edges are drawn once" begin
    # a 2x2 quadrilateral grid has 4 * 4 = 16 cell edges but only 12 distinct ones
    grid = generate_grid(Quadrilateral, (2, 2))
    code = tikzcode(grid)
    @test count("\\draw", code) == 12

    # a 3x3 grid: 2 * 3 * (3 + 1) = 24 distinct edges
    grid = generate_grid(Quadrilateral, (3, 3))
    @test count("\\draw", tikzcode(grid)) == 24

    # triangles: 18 cells, 3 * 3 * 3 + 2 * 3 = ... just check it is below the naive count
    grid = generate_grid(Triangle, (3, 3))
    @test count("\\draw", tikzcode(grid)) < 3 * getncells(grid)
end

@testitem "Curved edges" begin
    # linear cells never emit Bezier control points
    grid = generate_grid(Quadrilateral, (2, 2))
    @test !occursin("controls", tikzcode(grid))

    # quadratic cells do, unless `bezier` is switched off
    for celltype in (QuadraticQuadrilateral, QuadraticTriangle)
        local g = generate_grid(celltype, (2, 2))
        @test occursin("controls", tikzcode(g))
        @test !occursin("controls", tikzcode(g; bezier = false))
    end

    # a straight quadratic edge puts its control points at one and two thirds
    grid = generate_grid(QuadraticQuadrilateral, (1, 1))
    @test occursin("(-1,-1) .. controls (-0.33333,-1) and (0.33333,-1) .. (1,-1)", tikzcode(grid))
end

@testitem "Cell fills" begin
    using Colors

    grid = generate_grid(Quadrilateral, (2, 1))
    addcellset!(grid, "left", x -> x[1] <= 0.0)

    # no fill by default
    @test !occursin("\\fill", tikzcode(grid))

    # uniform fill
    code = tikzcode(grid; cellcolor = "blue!15")
    @test count("\\fill[blue!15]", code) == 2

    # cell sets override the uniform fill
    code = tikzcode(grid; cellcolor = "blue!15", cellsetcolors = ["left" => "red!30"])
    @test count("\\fill[red!30]", code) == 1
    @test count("\\fill[blue!15]", code) == 1

    # later pairs win over earlier ones
    addcellset!(grid, "all", x -> true)
    code = tikzcode(grid; cellsetcolors = ["all" => "red!30", "left" => "green!30"])
    @test count("\\fill[green!30]", code) == 1
    @test count("\\fill[red!30]", code) == 1

    # an unknown cell set is an error rather than a silently empty picture
    @test_throws ArgumentError tikzcode(grid; cellsetcolors = ["nope" => "red"])

    # opacity
    @test occursin("opacity=0.5", tikzcode(grid; cellcolor = "blue", fillopacity = 0.5))

    # fills are emitted before the wireframe so the lines stay visible
    code = tikzcode(grid; cellcolor = "blue!15")
    @test findfirst("\\fill", code)[1] < findfirst("\\draw", code)[1]
end

@testitem "Colorants become definecolor statements" begin
    using Colors

    grid = generate_grid(Quadrilateral, (2, 1))
    p = tikzgrid(grid; cellcolor = RGB(1.0, 0.0, 0.0), linecolor = colorant"#a6cee3")
    @test occursin("\\definecolor{ftcolor1}{RGB}{255,0,0}", p.preamble)
    @test occursin("\\definecolor{ftcolor2}{RGB}{166,206,227}", p.preamble)
    @test occursin("\\fill[ftcolor1]", p.data)
    @test occursin("ftcolor2", p.data)

    # a colour used twice is defined once
    p = tikzgrid(grid; cellcolor = RGB(1.0, 0.0, 0.0), linecolor = RGB(1.0, 0.0, 0.0))
    @test count("\\definecolor", p.preamble) == 1

    # string colours never end up in the preamble
    p = tikzgrid(grid; cellcolor = "blue!15")
    @test isempty(p.preamble)
end

@testitem "Nodes, labels and picture options" begin
    grid = generate_grid(Quadrilateral, (1, 1))

    @test !occursin("\\node", tikzcode(grid))

    code = tikzcode(grid; drawnodes = true)
    @test count("\\node[circle", code) == 4

    code = tikzcode(grid; nodelabels = true, labeloffset = 0.0)
    @test occursin("at (-1,-1) {\$1\$}", code)
    @test count("\\node", code) == 4

    code = tikzcode(grid; celllabels = true)
    @test occursin("at (0,0) {\$1\$}", code)

    # `drawcells = false` gives a fills-only picture
    code = tikzcode(grid; cellcolor = "blue!15", drawcells = false)
    @test occursin("\\fill", code)
    @test !occursin("\\draw", code)

    # picture scale
    @test tikzgrid(grid).options == "scale=1"
    @test tikzgrid(grid; picturescale = 2.5).options == "scale=2.5"
end

@testitem "Coordinate formatting" begin
    using FerriteTikz: _fmt

    @test _fmt(1.0, 5) == "1"
    @test _fmt(-1.0, 5) == "-1"
    @test _fmt(0.0, 5) == "0"
    @test _fmt(-0.0000001, 5) == "0"        # would otherwise print as "-0"
    @test _fmt(1 / 3, 5) == "0.33333"
    @test _fmt(1 / 3, 2) == "0.33"
    @test _fmt(0.5, 5) == "0.5"

    grid = generate_grid(QuadraticQuadrilateral, (1, 1))
    @test occursin("(-0.33,-1)", tikzcode(grid; digits = 2))
end

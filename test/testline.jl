@testitem "Line elements are recognised" begin
    using FerriteTikz: isline, celledges, to2d

    @test isline(Line((1, 2)))
    @test isline(QuadraticLine((1, 2, 3)))
    @test !isline(Quadrilateral((1, 2, 3, 4)))
    @test !isline(Triangle((1, 2, 3)))

    # The facets of a line element are its two end *points*, which are not edges. The
    # drawable edge is the cell itself, returned as a single entry.
    @test celledges(Line((7, 9))) == [(7, 9)]
    @test celledges(QuadraticLine((7, 9, 8))) == [(7, 9, 8)]

    @test to2d(Vec{1}((3.0,))) === Vec{2}((3.0, 0.0))
    @test to2d(Vec{2}((3.0, 4.0))) === Vec{2}((3.0, 4.0))
    @test to2d(2.5) === Vec{2}((2.5, 0.0))
end

@testitem "One-dimensional grids are drawn on the x axis" begin
    using FerriteTikz: nodecoordinates

    grid = generate_grid(Line, (4,))
    @test all(x -> x[2] == 0.0, nodecoordinates(grid))

    code = tikzcode(grid)
    @test count("\\draw", code) == 4
    @test occursin("(-1,0) -- (-0.5,0)", code)

    # a 3D grid is still rejected, a 1D one is not
    @test_throws ArgumentError tikzcode(generate_grid(Hexahedron, (1, 1, 1)))

    # node markers, labels and cell labels all work; the cell label sits at the midpoint
    code = tikzcode(grid; drawnodes = true, celllabels = true)
    @test count("\\node[circle", code) == 5
    @test occursin("at (-0.75,0) {\$1\$}", code)
end

@testitem "Line elements are stroked, never filled" begin
    grid = generate_grid(Line, (3,))

    # a line encloses no area, so `cellcolor` must not emit a degenerate \fill
    code = tikzcode(grid; cellcolor = "blue!15")
    @test !occursin("\\fill", code)
    # instead the cell colour becomes the stroke colour
    @test count("\\draw[thin, blue!15]", code) == 3

    # cell sets colour individual members, cells outside them keep `linecolor`
    addcellset!(grid, "middle", [2])
    code = tikzcode(grid; cellsetcolors = ["middle" => "red"], linecolor = "gray")
    @test count("\\draw[thin, red]", code) == 1
    @test count("\\draw[thin, gray]", code) == 2

    # `drawcells = false` leaves nothing at all for a line mesh
    @test isempty(strip(tikzcode(grid; cellcolor = "blue!15", drawcells = false)))
end

@testitem "Line elements in two-dimensional space" begin
    nodes = [Node((0.0, 0.0)), Node((1.0, 0.0)), Node((2.0, 0.0)), Node((0.5, 0.8)), Node((1.5, 0.8))]
    cells = [
        Line((1, 2)), Line((2, 3)), Line((1, 4)), Line((4, 2)),
        Line((2, 5)), Line((5, 3)), Line((4, 5)),
    ]
    grid = Grid(cells, nodes)

    code = tikzcode(grid)
    @test count("\\draw", code) == 7
    @test occursin("(0,0) -- (0.5,0.8)", code)

    # Members are elements in their own right, not shared boundaries: two coincident bars
    # must both be drawn, unlike the shared edges of area cells.
    doubled = Grid([Line((1, 2)), Line((2, 1))], nodes[1:2])
    @test count("\\draw", tikzcode(doubled)) == 2

    addcellset!(grid, "chord", [1, 2])
    code = tikzcode(grid; cellsetcolors = ["chord" => "red"], linewidth = "thick")
    @test count("\\draw[thick, red]", code) == 2
    @test count("\\draw[thick, black]", code) == 5
end

@testitem "Curved line elements" begin
    # a QuadraticLine bent out of its chord becomes an exact cubic Bezier
    grid = Grid([QuadraticLine((1, 2, 3))], [Node((0.0, 0.0)), Node((2.0, 0.0)), Node((1.0, 0.6))])
    # q = 2*(1,0.6) - ((0,0)+(2,0))/2 = (1,1.2), c1 = 2/3*q, c2 = (2,0) + 2/3*(q-(2,0))
    @test occursin("(0,0) .. controls (0.66667,0.8) and (1.33333,0.8) .. (2,0)", tikzcode(grid))
    @test !occursin("controls", tikzcode(grid; bezier = false))

    # a straight QuadraticLine still puts its control points at one and two thirds
    @test occursin("(-1,0) .. controls (-0.66667,0) and (-0.33333,0) .. (0,0)", tikzcode(generate_grid(QuadraticLine, (2,))))
end

@testitem "Deformation of line meshes" begin
    grid = generate_grid(Line, (3,))

    # a scalar field on a 1D grid displaces along x
    dh = DofHandler(grid)
    add!(dh, :u, Lagrange{RefLine, 1}())
    close!(dh)
    u = [0.0, 0.1, 0.2, 0.3]
    x = deformedcoordinates(dh, u)
    @test x[1] ≈ Vec{2}((-1.0, 0.0))
    @test x[4] ≈ Vec{2}((1.3, 0.0))
    @test deformedcoordinates(dh, u; scale = 2.0)[4] ≈ Vec{2}((1.6, 0.0))

    # a flat vector is interpreted with the grid's spatial dimension, not always 2
    @test nodedisplacements(grid, [0.0, 0.1, 0.2, 0.3]) == [Vec{2}((v, 0.0)) for v in u]
    @test_throws ArgumentError nodedisplacements(grid, zeros(8))

    # Vec{2} displacements on a 1D grid draw a transverse deflection
    ud = [Vec{2}((0.0, 0.5)) for _ in 1:getnnodes(grid)]
    @test all(x -> x[2] ≈ 0.5, deformedcoordinates(grid, ud))
    @test occursin("(-1,0.5)", tikzcode(grid, ud))

    # trusses: flat 2D layout plus a reference overlay
    truss = Grid([Line((1, 2)), Line((2, 3)), Line((3, 1))], [Node((0.0, 0.0)), Node((1.0, 0.0)), Node((0.5, 0.8))])
    code = tikzcode(truss, [0.0, 0.0, 0.1, 0.0, 0.05, -0.2]; scale = 2.0, reference = true)
    @test count("\\draw", code) == 6
    @test occursin("(1.2,0)", code)
end

@testitem "Grids mixing area and line cells" begin
    grid = Grid(
        Union{Quadrilateral, Line}[Quadrilateral((1, 2, 4, 3)), Line((1, 4))],
        [Node((0.0, 0.0)), Node((1.0, 0.0)), Node((0.0, 1.0)), Node((1.0, 1.0))],
    )
    addcellset!(grid, "bar", [2])

    code = tikzcode(grid; cellcolor = "blue!12", cellsetcolors = ["bar" => "red"])
    # the quadrilateral is filled, the bar is not
    @test count("\\fill", code) == 1
    @test count("\\fill[blue!12]", code) == 1
    @test !occursin("\\fill[red]", code)
    # four quad edges plus the diagonal bar, the bar in its cell colour
    @test count("\\draw", code) == 5
    @test count("\\draw[thin, red]", code) == 1
end

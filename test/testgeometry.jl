@testitem "Cell edges" begin
    using FerriteTikz: celledges, edgekey

    # linear quadrilateral: four edges of two corner nodes each, forming a closed loop in
    # local vertex order 1-2-3-4-1 but reported as *global* node ids
    grid = generate_grid(Quadrilateral, (1, 1))
    cellnodes = getcells(grid, 1).nodes
    edges = celledges(getcells(grid, 1))
    @test length(edges) == 4
    @test all(e -> length(e) == 2, edges)
    @test edges == [
        (cellnodes[1], cellnodes[2]), (cellnodes[2], cellnodes[3]),
        (cellnodes[3], cellnodes[4]), (cellnodes[4], cellnodes[1]),
    ]
    # consecutive edges share a node, i.e. the boundary is a closed loop
    @test all(i -> edges[i][2] == edges[mod1(i + 1, 4)][1], 1:4)

    # linear triangle
    grid = generate_grid(Triangle, (1, 1))
    edges = celledges(getcells(grid, 1))
    @test length(edges) == 3
    @test all(e -> length(e) == 2, edges)

    # quadratic cells carry the mid side node as the third entry
    grid = generate_grid(QuadraticQuadrilateral, (1, 1))
    cellnodes = getcells(grid, 1).nodes
    edges = celledges(getcells(grid, 1))
    @test length(edges) == 4
    @test all(e -> length(e) == 3, edges)
    # local nodes 5..8 are the mid side nodes of the local edges (1,2), (2,3), (3,4), (4,1)
    @test edges == [
        (cellnodes[1], cellnodes[2], cellnodes[5]), (cellnodes[2], cellnodes[3], cellnodes[6]),
        (cellnodes[3], cellnodes[4], cellnodes[7]), (cellnodes[4], cellnodes[1], cellnodes[8]),
    ]
    # the mid side node really sits at the mid point of its edge
    coords = FerriteTikz.nodecoordinates(grid)
    @test all(e -> coords[e[3]] ≈ (coords[e[1]] + coords[e[2]]) / 2, edges)

    grid = generate_grid(QuadraticTriangle, (1, 1))
    edges = celledges(getcells(grid, 1))
    @test length(edges) == 3
    @test all(e -> length(e) == 3, edges)

    # edges are identified independently of their orientation
    @test edgekey((7, 3)) == edgekey((3, 7)) == (3, 7)
    @test edgekey((1, 2, 5)) == (1, 2)
end

@testitem "Bezier control points" begin
    using FerriteTikz: beziercontrolpoints

    # a straight edge with the mid node in the middle must give control points on the
    # segment at one and two thirds
    p1, p2 = Vec{2}((0.0, 0.0)), Vec{2}((3.0, 0.0))
    c1, c2 = beziercontrolpoints(p1, p2, (p1 + p2) / 2)
    @test c1 ≈ Vec{2}((1.0, 0.0))
    @test c2 ≈ Vec{2}((2.0, 0.0))

    # the cubic must reproduce the quadratic through the mid side node exactly, so
    # evaluating it at t = 1/2 has to return the mid side node again
    p1, p2, pm = Vec{2}((0.0, 0.0)), Vec{2}((2.0, 0.0)), Vec{2}((1.0, 1.0))
    c1, c2 = beziercontrolpoints(p1, p2, pm)
    bezier(t) = (1 - t)^3 * p1 + 3 * (1 - t)^2 * t * c1 + 3 * (1 - t) * t^2 * c2 + t^3 * p2
    @test bezier(0.5) ≈ pm
    @test bezier(0.0) ≈ p1
    @test bezier(1.0) ≈ p2
end

@testitem "Cell centroids" begin
    using FerriteTikz: cellcentroid, nodecoordinates

    grid = generate_grid(Quadrilateral, (2, 2))
    coords = nodecoordinates(grid)
    @test cellcentroid(grid, coords, 1) ≈ Vec{2}((-0.5, -0.5))
    @test cellcentroid(grid, coords, 4) ≈ Vec{2}((0.5, 0.5))

    grid = generate_grid(QuadraticQuadrilateral, (1, 1))
    coords = nodecoordinates(grid)
    @test cellcentroid(grid, coords, 1) ≈ Vec{2}((0.0, 0.0))
end

@testitem "Only 1D and 2D grids are supported" begin
    # three-dimensional grids are not implemented yet
    grid = generate_grid(Hexahedron, (1, 1, 1))
    @test_throws ArgumentError tikzgrid(grid)
    @test_throws ArgumentError tikzcode(grid)

    # one and two spatial dimensions are fine
    @test tikzgrid(generate_grid(Line, (2,))) isa TikzPicture
    @test tikzgrid(generate_grid(Quadrilateral, (2, 2))) isa TikzPicture
end

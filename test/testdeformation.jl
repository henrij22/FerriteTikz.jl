@testitem "Nodal displacements from raw vectors" begin
    grid = generate_grid(Quadrilateral, (1, 1))
    uvec = [Vec{2}((0.1, 0.2)), Vec{2}((0.0, 0.0)), Vec{2}((-0.1, 0.0)), Vec{2}((0.0, 0.3))]

    @test nodedisplacements(grid, uvec) == uvec

    # the flat layout [u1x, u1y, u2x, u2y, ...] gives the same result
    uflat = collect(Iterators.flatten(uvec))
    @test nodedisplacements(grid, uflat) == uvec

    # wrong lengths are rejected
    @test_throws ArgumentError nodedisplacements(grid, uvec[1:3])
    @test_throws ArgumentError nodedisplacements(grid, uflat[1:5])
end

@testitem "Deformed coordinates" begin
    grid = generate_grid(Quadrilateral, (1, 1))
    u = [Vec{2}((0.0, 0.0)), Vec{2}((0.1, 0.0)), Vec{2}((0.0, 0.2)), Vec{2}((0.0, 0.0))]

    # the nodes of a 1x1 grid are numbered (-1,-1), (1,-1), (-1,1), (1,1)
    x = deformedcoordinates(grid, u)
    @test x[1] ≈ Vec{2}((-1.0, -1.0))
    @test x[2] ≈ Vec{2}((1.1, -1.0))
    @test x[3] ≈ Vec{2}((-1.0, 1.2))
    @test x[4] ≈ Vec{2}((1.0, 1.0))

    # scaling magnifies the displacement, not the coordinates
    x = deformedcoordinates(grid, u; scale = 3.0)
    @test x[2] ≈ Vec{2}((1.3, -1.0))
    @test x[1] ≈ Vec{2}((-1.0, -1.0))

    # and it shows up in the emitted code
    @test occursin("(1.3,-1)", tikzcode(grid, u; scale = 3.0))
end

@testitem "Deformed configuration through a DofHandler" begin
    grid = generate_grid(Quadrilateral, (2, 2))
    dh = DofHandler(grid)
    add!(dh, :u, Lagrange{RefQuadrilateral, 1}()^2)
    close!(dh)

    # a homogeneous stretch u = (a * x, b * y) is reproduced exactly at the nodes
    a, b = 0.1, -0.2
    u = zeros(ndofs(dh))
    for cellid in 1:getncells(grid)
        dofs = celldofs(dh, cellid)
        for (i, nodeid) in pairs(getcells(grid, cellid).nodes)
            x = Ferrite.get_node_coordinate(grid, nodeid)
            u[dofs[2i - 1]] = a * x[1]
            u[dofs[2i]] = b * x[2]
        end
    end

    ud = nodedisplacements(dh, u)
    for nodeid in 1:getnnodes(grid)
        x = Ferrite.get_node_coordinate(grid, nodeid)
        @test ud[nodeid] ≈ Vec{2}((a * x[1], b * x[2]))
    end

    xd = deformedcoordinates(dh, u; scale = 2.0)
    for nodeid in 1:getnnodes(grid)
        x = Ferrite.get_node_coordinate(grid, nodeid)
        @test xd[nodeid] ≈ Vec{2}(((1 + 2a) * x[1], (1 + 2b) * x[2]))
    end

    # bad inputs
    @test_throws ArgumentError nodedisplacements(dh, u; field = :nope)
    @test_throws ArgumentError nodedisplacements(dh, u[1:(end - 1)])
end

@testitem "Scalar fields cannot be used as displacements" begin
    grid = generate_grid(Quadrilateral, (2, 2))
    dh = DofHandler(grid)
    add!(dh, :T, Lagrange{RefQuadrilateral, 1}())
    close!(dh)
    @test_throws ArgumentError nodedisplacements(dh, zeros(ndofs(dh)); field = :T)
end

@testitem "Reference configuration overlay" begin
    grid = generate_grid(Quadrilateral, (1, 1))
    u = [Vec{2}((0.0, 0.0)), Vec{2}((0.5, 0.0)), Vec{2}((0.5, 0.0)), Vec{2}((0.0, 0.0))]

    # without `reference` only the deformed configuration is drawn
    code = tikzcode(grid, u)
    @test count("\\draw", code) == 4
    @test !occursin("(1,-1) -- (1,1)", code)

    # with `reference` the undeformed grid is drawn first, in its own style
    code = tikzcode(grid, u; reference = (linecolor = "gray", linestyle = "dashed"))
    @test count("\\draw", code) == 8
    @test count("\\draw[thin, gray, dashed]", code) == 4
    @test count("\\draw[thin, black]", code) == 4
    @test findfirst("gray", code)[1] < findfirst("black", code)[1]

    # the reference configuration inherits the main style but is never filled or labelled
    code = tikzcode(grid, u; cellcolor = "blue!15", drawnodes = true, reference = true)
    @test count("\\fill", code) == 1
    @test count("\\node[circle", code) == 4

    # ... unless asked for explicitly
    code = tikzcode(grid, u; cellcolor = "blue!15", reference = (cellcolor = "gray!20",))
    @test count("\\fill[gray!20]", code) == 1
    @test count("\\fill[blue!15]", code) == 1

    # `reference = false` and `reference = nothing` are the same thing
    @test tikzcode(grid, u; reference = false) == tikzcode(grid, u)
end

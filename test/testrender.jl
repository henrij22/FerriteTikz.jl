@testitem "End to end rendering" begin
    using Colors

    # Compiling the generated code is the only way to catch syntax errors in the TikZ output,
    # but it needs a LaTeX installation. TikzPictures falls back on the bundled Tectonic
    # binary, which downloads its packages on first use, so this test is skipped unless
    # FERRITETIKZ_TEST_RENDER is set.
    if get(ENV, "FERRITETIKZ_TEST_RENDER", "false") != "true"
        @info "skipping the rendering test, set FERRITETIKZ_TEST_RENDER=true to enable it"
    else
        mktempdir() do dir
            for celltype in (Triangle, Quadrilateral, QuadraticTriangle, QuadraticQuadrilateral)
                grid = generate_grid(celltype, (2, 2))
                addcellset!(grid, "left", x -> x[1] <= 0.0)
                u = [Vec{2}((0.05 * x[2], 0.0)) for x in Ferrite.get_node_coordinate.((grid,), 1:getnnodes(grid))]
                p = tikzgrid(
                    grid, u;
                    scale = 2.0, picturescale = 2.0,
                    cellcolor = colorant"#a6cee3", cellsetcolors = ["left" => "orange!30"],
                    drawnodes = true, nodelabels = true, celllabels = true,
                    reference = (linecolor = "gray", linestyle = "dashed"),
                )
                file = joinpath(dir, "grid_$(nameof(celltype))")
                save(PDF(file), p)
                @test filesize(file * ".pdf") > 0
            end

            # line elements, in 1D space and as a truss in 2D space
            for (name, grid) in (
                    "line1d" => generate_grid(Line, (4,)),
                    "quadraticline1d" => generate_grid(QuadraticLine, (3,)),
                    "truss2d" => Grid(
                        [Line((1, 2)), Line((2, 3)), Line((1, 4)), Line((4, 2)), Line((4, 3))],
                        [Node((0.0, 0.0)), Node((1.0, 0.0)), Node((2.0, 0.0)), Node((0.5, 0.8))],
                    ),
                )
                addcellset!(grid, "first", [1])
                p = tikzgrid(
                    grid;
                    cellsetcolors = ["first" => "red"], cellcolor = colorant"#1f78b4",
                    linewidth = "thick", drawnodes = true, celllabels = true, picturescale = 2.0,
                )
                file = joinpath(dir, "grid_$name")
                save(PDF(file), p)
                @test filesize(file * ".pdf") > 0
            end
        end
    end
end

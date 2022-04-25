@testset verbose = true "graph" begin
    using MAPPFD: generate_grid

    @testset "generate_graph" begin
        G = generate_grid(4, 4; obstacle_locs = [11, 1])
        @test sum(v -> length(v.neigh), G) / 2 == 18
    end
end

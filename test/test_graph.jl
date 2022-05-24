@testset verbose = true "graph" begin
    @testset "generate_graph" begin
        import MAPPFD: generate_grid
        G = generate_grid(4, 4; obstacle_locs = [11, 1])
        @test sum(v -> length(v.neigh), G) / 2 == 18
    end

    @testset "generate_random_graph" begin
        import MAPPFD: generate_random_grid
        G = generate_random_grid(10, 10; occupancy_rate = 0.1)
        @test length(filter(v -> length(v.neigh) > 0, G)) <= 90
    end
end

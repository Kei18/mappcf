@testset verbose = true "graph" begin
    @testset "generate_graph" begin
        G = generate_grid(4, 4; obstacle_locs = [11, 1])
        @test sum(v -> length(v.neigh), G) / 2 == 18
    end

    @testset "generate_random_graph" begin
        G = generate_random_grid(10, 10; occupancy_rate = 0.1)
        @test length(filter(v -> length(v.neigh) > 0, G)) <= 90
    end

    @testset "cost evaluation" begin
        path = [1, 2, 2, 3, 4, 4]
        @test MAPPFD.get_path_length(path) == 3
        @test MAPPFD.get_traveling_time(path) == 4

        path = [1]
        @test MAPPFD.get_path_length(path) == 0
        @test MAPPFD.get_traveling_time(path) == 0
    end

    @testset "mapf bench" begin
        filename = joinpath(@__DIR__, "../assets/map/random-32-32-20.map")
        G = MAPPFD.load_mapf_bench(filename)
        @test MAPPFD.get_num_vertices(G) == 819
    end
end

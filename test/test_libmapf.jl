using MAPPFD:
    get_distance_table,
    find_timed_path,
    align_paths!,
    single_agent_pathfinding,
    prioritized_planning

@testset verbose = true "lib mapf" begin

    G = generate_sample_graph1()

    @testset "distance table" begin
        # distance table
        dist_table = get_distance_table(G, 3)
        @test dist_table[1] == 2
        @test dist_table[2] == 1
        @test dist_table[4] == 2
    end

    @testset "timed path finding" begin
        start = 1
        goal = 3
        path = find_timed_path(G, start, (S) -> S.v == goal)
        @test path == [1, 2, 3]
    end

    @testset "align paths" begin
        paths = [[1, 2, 3, 3], [4, 5, 5]]
        align_paths!(paths)
        @test paths == [[1, 2, 3], [4, 5, 5]]
    end

    @testset "single_agent_pathfinding" begin
        path = single_agent_pathfinding(G, [[1, 1, 2, 3]], 4, 5)
        @test path == [4, 2, 5]
    end

    @testset "prioritized planning" begin
        starts = [1, 4]
        goals = [3, 5]
        paths = prioritized_planning(G, starts, goals)
        @test paths == [[1, 2, 3], [4, 1, 5]]
    end
end

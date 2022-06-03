@testset verbose = true "pathfinding" begin
    import MAPPFD.Pathfinding:
        is_valid_path, timed_pathfinding, basic_pathfinding, get_distance_table
    G = generate_sample_graph1()

    @testset "is_valid_path" begin
        start = 1
        goal = 3
        @test is_valid_path([1, 2, 3], G, start, goal)
        @test !is_valid_path([2, 2, 3], G, start, goal)
        @test !is_valid_path([1, 2, 2], G, start, goal)
        @test !is_valid_path([1, 4, 3], G, start, goal)
    end

    @testset "timed_pathfinding" begin
        G = generate_sample_graph1()
        start = 1
        goal = 3
        path = timed_pathfinding(
            G = G,
            start = start,
            check_goal = (S) -> (S.v == goal),
            invalid = (S_from, S_to) -> (S_to.v == 2 && S_to.t == 2),
        )
        @test is_valid_path(path, G, start, goal)
        @test path == [1, 1, 2, 3]
    end

    @testset "timed_pathfinding timeout" begin
        G = generate_sample_graph1()
        path = timed_pathfinding(
            G = G,
            start = 1,
            check_goal = (S) -> false,
            deadline = generate_deadline(0.05),
        )
        @test isnothing(path)

        path = timed_pathfinding(
            G = G,
            start = 1,
            check_goal = (S) -> false,
            time_limit_sec = 0.1,
        )
        @test isnothing(path)
    end

    @testset "basic_pathfinding" begin
        start = 4
        goal = 5
        path = basic_pathfinding(
            G = G,
            start = start,
            goal = goal,
            invalid = (S_from, S_to) -> (S_to.v == 1),
        )
        @test is_valid_path(path, G, start, goal)
        @test path == [4, 2, 5]
    end

    @testset "distance table" begin
        dist_table = get_distance_table(G, 3)
        @test dist_table[1] == 2
        @test dist_table[2] == 1
        @test dist_table[4] == 2
    end
end

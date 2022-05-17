@testset verbose = true "libmapf" begin
    using MAPPFD:
        get_distance_table,
        find_timed_path,
        align_paths!,
        single_agent_pathfinding,
        prioritized_planning,
        verify_mapf_solution,
        astar_operator_decomposition

    G = generate_sample_graph1()
    starts = [1, 4]
    goals = [3, 5]
    ins = (G, starts, goals)

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
        paths = [[1, 1, 2, 3], Vector{Int}()]
        goals = [3, 5]
        @test single_agent_pathfinding(G, paths, 2, 4, goals) == [4, 2, 5]
    end

    @testset "verify_mapf_solution" begin
        # correct
        solution = [[1, 2, 3], [4, 1, 5]]
        @test verify_mapf_solution(ins..., solution)

        # invalid starts
        solution = [[2, 3], [4, 1, 5]]
        @test !verify_mapf_solution(ins..., solution)

        # invalid goal
        solution = [[1, 2, 3], [4, 1]]
        @test !verify_mapf_solution(ins..., solution)

        # vertex conflict
        solution = [[1, 2, 3], [4, 2, 5]]
        @test !verify_mapf_solution(ins..., solution)

        # swap conflict
        solution = [[1, 4, 2, 3], [4, 1, 5]]
        @test !verify_mapf_solution(ins..., solution)

        # continuity
        solution = [[1, 3], [4, 1, 5]]
        @test !verify_mapf_solution(ins..., solution)

    end

    @testset "prioritized planning" begin
        solution = prioritized_planning(ins...)
        @test verify_mapf_solution(ins..., solution)
        @test solution == [[1, 2, 3], [4, 1, 5]]
    end

    @testset "astar_operator_decomposition" begin
        solution = astar_operator_decomposition(ins...)
        @test verify_mapf_solution(ins..., solution; VERBOSE = 1)
    end
end

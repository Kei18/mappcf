@testset verbose = true "multi_agent_pathfinding" begin
    import MAPPFD.MAPF:
        prioritized_planning, astar_operator_decomposition, is_valid_mapf_solution

    I = generate_sample_sync_instance1()
    ins = (I.G, I.starts, I.goals)

    @testset "is_valid_mapf_solution" begin
        # correct
        solution = [[1, 2, 3], [4, 1, 5]]
        @test is_valid_mapf_solution(ins..., solution)

        # invalid starts
        solution = [[2, 3], [4, 1, 5]]
        @test !is_valid_mapf_solution(ins..., solution)

        # invalid goal
        solution = [[1, 2, 3], [4, 1]]
        @test !is_valid_mapf_solution(ins..., solution)

        # vertex conflict
        solution = [[1, 2, 3], [4, 2, 5]]
        @test !is_valid_mapf_solution(ins..., solution)

        # swap conflict
        solution = [[1, 4, 2, 3], [4, 1, 5]]
        @test !is_valid_mapf_solution(ins..., solution)

        # continuity
        solution = [[1, 3], [4, 1, 5]]
        @test !is_valid_mapf_solution(ins..., solution)

    end

    @testset "prioritized planning" begin
        solution = prioritized_planning(ins...)
        @test is_valid_mapf_solution(ins..., solution; VERBOSE = 1)
        @test solution == [[1, 2, 3], [4, 1, 5]]
    end

    @testset "astar_operator_decomposition" begin
        solution = astar_operator_decomposition(ins...)
        @test is_valid_mapf_solution(ins..., solution; VERBOSE = 1)
    end
end

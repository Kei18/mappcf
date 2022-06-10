@testset verbose = true "solver" begin
    @testset "planner1 sync" begin
        ins = generate_sample_sync_instance4()
        solution = MAPPFD.planner1(ins; multi_agent_path_planner = MAPPFD.Solver.RPP)
        @test solution[1][1].path == [4, 5, 6]
        @test solution[2][1].path == [8, 8, 5, 2]
        @test solution[2][2].path == [8, 8, 6, 2]
    end

    @testset "planner1 sync no crash" begin
        ins = generate_sample_sync_instance4(0)
        solution = MAPPFD.planner1(ins; multi_agent_path_planner = MAPPFD.Solver.RPP)
        @test length(solution[2]) == 1
    end

    @testset "planner1 seq" begin
        ins = generate_sample_seq_instance4()
        solution = MAPPFD.planner1(ins)
        @test solution[1][1].path == [4, 5, 6]
        @test solution[1][2].path == [4, 2, 6]
        @test solution[2][1].path == [8, 5, 2]
        @test solution[2][2].path == [8, 6, 2]
    end

    @testset "planner1 seq no crash" begin
        ins = generate_sample_seq_instance4(0)
        solution = MAPPFD.planner1(ins)
        @test length(solution[1]) == 1
        @test length(solution[2]) == 1
    end

    @testset "planner2" begin
        ins = generate_sample_sync_instance2()
        solution = MAPPFD.planner2(
            ins;
            multi_agent_path_planner = MAPPFD.astar_operator_decomposition,
        )
        @test all(plans -> length(plans) == 1, solution)
        @test solution[1][1].path == [11, 6, 1, 2, 3, 4, 5, 10, 15]
        @test solution[2][1].path == [22, 17, 12, 7]
        @test solution[3][1].path == [24, 19, 14, 9]
    end

    @testset "planner2 no crash" begin
        ins = generate_sample_sync_instance2(0)
        solution = MAPPFD.planner2(
            ins;
            multi_agent_path_planner = MAPPFD.astar_operator_decomposition,
        )
        @test all(plans -> length(plans) == 1, solution)
        @test solution[1][1].path == [11, 12, 13, 14, 15]
        @test solution[2][1].path == [22, 17, 12, 7]
        @test solution[3][1].path == [24, 19, 14, 9]
    end
end

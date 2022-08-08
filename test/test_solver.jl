@testset verbose = true "solver" begin
    @testset "DCRF sync" begin
        ins = generate_sample_sync_instance4()
        solution = MAPPFD.DCRF(
            ins;
            multi_agent_path_planner = MAPPFD.Solver.RPP,
            time_limit_sec = 3,
        )
        @test solution[1][1].path == [4, 5, 6]
        @test solution[2][1].path == [8, 8, 5, 2]
        @test solution[2][2].path == [8, 8, 6, 2]
    end

    @testset "DCRF sync no crash" begin
        ins = generate_sample_sync_instance4(0)
        solution = MAPPFD.DCRF(
            ins;
            multi_agent_path_planner = MAPPFD.Solver.RPP,
            time_limit_sec = 3,
        )
        @test length(solution[2]) == 1
    end

    @testset "DCRF seq" begin
        ins = generate_sample_seq_instance4()
        solution = MAPPFD.DCRF(ins, time_limit_sec = 3)
        @test solution[1][1].path == [4, 5, 6]
        @test solution[1][2].path == [4, 2, 6]
        @test solution[2][1].path == [8, 5, 2]
        @test solution[2][2].path == [8, 6, 2]
    end

    @testset "DCRF seq no crash" begin
        ins = generate_sample_seq_instance4(0)
        solution = MAPPFD.DCRF(ins, time_limit_sec = 3)
        @test length(solution[1]) == 1
        @test length(solution[2]) == 1
    end

    @testset "CBS" begin
        ins = generate_sample_sync_instance4()
        @test isa(MAPPFD.Solver.CBS(ins; time_limit_sec = 3), Failure)
    end
end

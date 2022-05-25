@testset verbose = true "solver" begin
    @testset "planner1 sync" begin
        import MAPPFD.MultiAgentPathfinding: astar_operator_decomposition
        ins = MAPPFD.SyncInstance(MAPPFD.generate_sample_graph4(), [4, 8], [6, 2])
        solution = MAPPFD.planner1(
            ins,
            (ins) -> astar_operator_decomposition(ins.G, ins.starts, ins.goals),
        )
        @test solution[1][1].path == [4, 5, 6]
        @test solution[2][1].path == [8, 8, 5, 2]
        @test solution[2][2].path == [8, 8, 6, 2]
    end

    @testset "planner1 seq" begin
        ins = MAPPFD.SeqInstance(MAPPFD.generate_sample_graph4(), [4, 8], [6, 2])
        solution = MAPPFD.planner1(
            ins,
            (ins) -> MAPPFD.OTIMAPP.prioritized_planning(ins.G, ins.starts, ins.goals),
        )
        @test solution[1][1].path == [4, 5, 6]
        @test solution[1][2].path == [4, 2, 6]
        @test solution[2][1].path == [8, 5, 2]
        @test solution[2][2].path == [8, 6, 2]
    end
end

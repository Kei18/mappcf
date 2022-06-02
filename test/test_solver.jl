@testset verbose = true "solver" begin
    @testset "planner1 sync" begin
        import MAPPFD.MAPF: astar_operator_decomposition
        ins = generate_sample_sync_instance4()
        solution = MAPPFD.planner1(
            ins,
            (ins) -> astar_operator_decomposition(ins.G, ins.starts, ins.goals),
        )
        @test solution[1][1].path == [4, 5, 6]
        @test solution[2][1].path == [8, 8, 5, 2]
        @test solution[2][2].path == [8, 8, 6, 2]
    end

    @testset "planner1 seq" begin
        ins = generate_sample_seq_instance4()
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

@testset verbose = true "complete_solver" begin
    G = MAPPFD.generate_sample_graph2()
    starts = [11, 22, 24]
    goals = [15, 7, 9]
    ins = MAPPFD.SyncInstance(G, starts, goals)

    @testset "identify critical sections" begin
        solution = MAPPFD.planner2(ins)
        @test all(plans -> length(plans) == 1, solution)
        @test solution[1][1].path == [11, 6, 1, 2, 3, 4, 5, 10, 15]
        @test solution[2][1].path == [22, 17, 12, 7]
        @test solution[3][1].path == [24, 19, 14, 9]
    end
end

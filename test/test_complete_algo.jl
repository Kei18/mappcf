@testset verbose = true "complete_solver" begin
    @testset "planner2" begin
        ins = generate_sample_sync_instance2()
        solution = MAPPFD.planner2(ins)
        @test all(plans -> length(plans) == 1, solution)
        @test solution[1][1].path == [11, 6, 1, 2, 3, 4, 5, 10, 15]
        @test solution[2][1].path == [22, 17, 12, 7]
        @test solution[3][1].path == [24, 19, 14, 9]
    end
end

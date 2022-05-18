@testset verbose = true "complete_solver" begin
    using MAPPFD: complete_algorithm

    G = MAPPFD.generate_sample_graph2()
    starts = [11, 22, 19]
    goals = [15, 7, 9]
    ins = (G, starts, goals)

    @testset "identify critical sections" begin
        solution = MAPPFD.complete_algorithm(ins...)
        @test sync_global_verification(ins..., solution)
    end
end

@testset verbose = true "libsolver_seq" begin
    using MAPPFD: aggressive_search

    G = MAPPFD.generate_sample_graph4()
    starts = [4, 8]
    goals = [6, 2]
    ins = (G, starts, goals)

    @testset "aggressive_search" begin
        solution = MAPPFD.aggressive_search(ins...)
        @test solution[1].path == [4, 5, 6]
        @test solution[2].path == [8, 5, 2]
    end
end

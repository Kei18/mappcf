@testset verbose = true "libotimapp" begin
    G = MAPPFD.generate_sample_graph3()
    starts = [6, 9]
    goals = [10, 2]
    ins = (G, starts, goals)

    @testset "prioritized_planning" begin
        paths = MAPPFD.OTIMAPP.prioritized_planning(ins...)
        @test paths == [[6, 7, 8, 9, 10], [9, 3, 8, 2]]
    end
end

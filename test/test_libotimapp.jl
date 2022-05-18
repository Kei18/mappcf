@testset verbose = true "libotimapp" begin
    using MAPPFD: seq_prioritized_planning

    G = MAPPFD.generate_sample_graph3()
    starts = [6, 9]
    goals = [10, 2]
    ins = (G, starts, goals)

    @testset "seq_prioritized_planning" begin
        expected_paths = [[6, 7, 8, 9, 10], [9, 3, 8, 2]]
        @test seq_prioritized_planning(ins...) == expected_paths
    end
end

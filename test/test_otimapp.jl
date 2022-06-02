@testset verbose = true "libotimapp" begin
    @testset "prioritized_planning" begin
        ins = (generate_sample_graph3(), [6, 9], [10, 2])
        paths = MAPPFD.OTIMAPP.prioritized_planning(ins...)
        @test paths == [[6, 7, 8, 9, 10], [9, 3, 8, 2]]
    end
end

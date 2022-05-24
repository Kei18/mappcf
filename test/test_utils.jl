@testset verbose = true "utils" begin
    @testset "get_in_range" begin
        import MAPPFD: get_in_range

        A = [1, 2, 3, 4]
        @test get_in_range(A, 2) == 2
        @test get_in_range(A, 0) == 1
        @test get_in_range(A, 10) == 4
    end
end

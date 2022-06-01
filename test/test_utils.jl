@testset verbose = true "utils" begin
    @testset "get_in_range" begin
        import MAPPFD: get_in_range

        A = [1, 2, 3, 4]
        @test get_in_range(A, 2) == 2
        @test get_in_range(A, 0) == 1
        @test get_in_range(A, 10) == 4
    end

    @testset "find_first_element" begin
        import MAPPFD: find_first_element

        A = [1, 2, 3, 4]
        @test find_first_element(iseven, A) == 2
        @test isnothing(find_first_element(e -> e > 10, A))
    end
end

@testset verbose = true "scripts" begin
    @testset "eval" begin
        include("../scripts/eval.jl")
        @test main("./config/test_eval.yaml") == :success
    end
end

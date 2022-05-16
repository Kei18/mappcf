@testset verbose = true "scripts" begin

    @testset "eval" begin
        include("../scripts/eval.jl")
        @test main("./config/test_config.yaml") == :success
    end
end

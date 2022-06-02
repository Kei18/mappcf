@testset verbose = true "scripts" begin
    @testset "benchmark_gen" begin
        include("../scripts/benchmark_gen.jl")
        dirname = create_benchmark("./config/test_benchmark_gen.yaml")
        instances = load_benchmark(dirname)
        @test !isnothing(instances)
    end

    @testset "eval" begin
        include("../scripts/eval.jl")
        @test main("./config/test_eval.yaml") == :success
    end
end

@testset verbose = true "solver" begin
    using MAPPFD: identify_critical_sections

    @testset "identify critical sections" begin
        paths = [[1, 2, 3], [4, 1, 5]]
        expected_res = Vector{Vector{@NamedTuple {when::Int, who::Int, loc::Int}}}([
            [],
            [(when = 2, who = 1, loc = 1)],
        ])
        @test identify_critical_sections(paths) == expected_res
    end
end

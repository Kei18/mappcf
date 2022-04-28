@testset verbose = true "solver" begin
    using MAPPFD: identify_critical_sections, simple_solver2, CriticalSection

    G = generate_sample_graph1()
    starts = Config([1, 4])
    goals = Config([3, 5])

    @testset "identify critical sections" begin
        paths = [[1, 2, 3], [4, 1, 5]]
        expected_res = Vector{Vector{@NamedTuple {when::Int, who::Int, loc::Int}}}([
            [],
            [(when = 2, who = 1, loc = 1)],
        ])
        @test identify_critical_sections(paths) == expected_res
    end

    @testset "solver" begin
        solution = [
            [(path = [1, 2, 3], backup = Dict{CriticalSection,Int}(), time_offset = 1)],
            [
                (
                    path = [4, 1, 5],
                    backup = Dict((when = 1, who = 1, loc = 1) => 2),
                    time_offset = 1,
                ),
                (path = [4, 2, 5], backup = Dict{CriticalSection,Int}(), time_offset = 1),
            ],
        ]
        @test simple_solver2(G, starts, goals) == solution
    end
end

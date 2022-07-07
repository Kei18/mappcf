include(joinpath(@__DIR__, "eval.jl"))
yamldir = joinpath(@__DIR__, "config", "exp")
instance_files = [
    "empty-8-8",
    "random-32-32-10",
    "random-32-32-20",
    "random-64-64-10",
    "random-64-64-20",
    "Paris_1_256",
]
config_files =
    map(x -> joinpath(yamldir, "$(x).yaml"), ["commons", "verify_sync", "solvers_sync"])
for basefile in instance_files
    main(vcat(config_files, joinpath(@__DIR__, "config", "exp", "$(basefile).yaml")))
end

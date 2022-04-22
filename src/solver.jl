function identify_critical_sections(
    paths::Vector{Vector{Int}},  # [agent] -> [time] -> location
    time_offset::Int = 1,
)::Vector{Vector{@NamedTuple{when::Int, who::Int, loc::Int}}}
    N = length(paths)
    critical_sections = map(i -> [], 1:N)
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = time_offset:length(path)
            v_i = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, v_i, [])
                j != i &&
                    t_j < t_i &&
                    push!(critical_sections[i], (when = t_i, who = j, loc = v_i))
            end
            # register new entry
            push!(table[v_i], (i, t_i))
        end
    end
    return critical_sections
end

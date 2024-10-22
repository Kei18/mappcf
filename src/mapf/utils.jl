"""
utility functions
"""

# check validity of MAPF solutions
function is_valid_mapf_solution(
    G::Graph,
    starts::Config,
    goals::Config,
    solution::Union{Nothing,Paths};
    VERBOSE::Int = 0,
)::Bool

    isnothing(solution) && return true
    N = length(starts)

    # starts
    if any(i -> first(solution[i]) != starts[i], 1:N)
        VERBOSE > 0 && @warn("inconsistent starts")
        return false
    end
    # goals
    if any(i -> last(solution[i]) != goals[i], 1:N)
        VERBOSE > 0 && @warn("inconsistent goals")
        return false
    end

    # check for each timestep
    T = maximum(i -> length(solution[i]), 1:N)
    for t = 1:T
        C_from = map(i -> get_in_range(solution[i], t - 1), 1:N)
        C_to = map(i -> get_in_range(solution[i], t), 1:N)
        try
            check_valid_transition(G, C_from, C_to, t - 1)
        catch e
            @info(e)
            return false
        end
    end

    return true
end

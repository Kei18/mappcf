module MultiAgentPathfinding

import Base: @kwdef
import DataStructures: PriorityQueue, enqueue!, dequeue!
import MAPPFD:
    Graph,
    get_neighbors,
    Path,
    Paths,
    Config,
    get_distance_table,
    get_in_range,
    timed_pathfinding,
    search,
    SearchNode


function is_valid_mapf_solution(
    G::Graph,
    starts::Config,
    goals::Config,
    solution::Union{Nothing,Paths};
    VERBOSE::Int = 0,
)::Bool

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
        for i = 1:N
            v_i_now = solution[i][t]
            v_i_pre = solution[i][max(1, t - 1)]
            # check continuity
            if !(v_i_now in vcat(get_neighbors(G, v_i_pre), v_i_pre))
                VERBOSE > 0 && @warn("$agent-(i)'s path is invalid at timestep $(t)")
                return false
            end
            # check collisions
            for j = i+1:N
                v_j_now = solution[j][t]
                v_j_pre = solution[j][max(1, t - 1)]
                if v_i_now == v_j_now || (v_i_now == v_j_pre && v_i_pre == v_j_now)
                    VERBOSE > 0 &&
                        @warn("collisions between $(i) and $(j) at timestep $(t)")
                    return false
                end
            end
        end
    end

    return true
end

function get_distance_tables(G::Graph, goals::Config)::Vector{Vector{Int}}
    return map(g -> get_distance_table(G, g), goals)
end

include("./prioritized_planning.jl")
include("./astar_operator_decomposition.jl")

end

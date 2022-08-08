"""
solution definition
"""

@kwdef mutable struct Plan
    id::Int = 1
    who::Int
    path::Path    # from timestep of one
    offset::Int   # offset for path
    backup::Dict{Crash,Int} = Dict()  # detecting crash -> next plan id
    crashes::Vector{Crash} = []
end
Solution = Vector{Vector{Plan}}

Base.show(io::IO, plan::Plan) = begin
    s = "Plan("
    s *= "id = $(plan.id), who = $(plan.who), path = $(plan.path), "
    s *= "offset = $(plan.offset), "
    s *= "backup = ["
    for (i, (key, val)) in enumerate(plan.backup)
        s *= "$key => $val"
        if i != length(plan.backup)
            s *= ", "
        end
    end
    s *= "], crashes = ["
    for (i, c) in enumerate(plan.crashes)
        s *= "$c"
        if i != length(plan.crashes)
            s *= ", "
        end
    end
    s *= "])"
    print(io, s)
end

Base.show(io::IO, solution::Solution) = begin
    for (i, plans) in enumerate(solution)
        print(io, "agent-$i\n")
        for plan in plans
            print(io, "- ", plan, "\n")
        end
    end
end

# solution metrics

function get_path_length(plan::Plan)::Int
    return get_path_length(plan.path)
end

function get_traveling_time(plan::Plan)::Int
    return get_traveling_time(plan.path)
end

function get_scores(solution)::Dict{Symbol,Int}

    primary_sum_of_path_length = 0
    primary_max_path_length = 0
    primary_sum_of_traveling_time = 0
    primary_max_traveling_time = 0

    worst_sum_of_path_length = 0
    worst_max_path_length = 0
    worst_sum_of_traveling_time = 0
    worst_max_traveling_time = 0

    if isa(solution, Solution)
        for plans in solution
            # primary path
            primary_plan = first(plans)
            path_length = get_path_length(primary_plan)
            traveling_time = get_traveling_time(primary_plan)
            primary_sum_of_path_length += path_length
            primary_max_path_length = max(primary_max_path_length, path_length)
            primary_sum_of_traveling_time += traveling_time
            primary_max_traveling_time = max(primary_max_traveling_time, traveling_time)

            # worst case
            arr_path_length = map(get_path_length, plans)
            arr_traveling_time = map(get_traveling_time, plans)
            path_length = maximum(arr_path_length)
            traveling_time = maximum(arr_traveling_time)
            worst_sum_of_path_length += path_length
            worst_max_path_length = max(worst_max_path_length, path_length)
            worst_sum_of_traveling_time += traveling_time
            worst_max_traveling_time = max(worst_max_traveling_time, traveling_time)
        end
    end

    return Dict(
        :worst_max_path_length => worst_max_path_length,
        :worst_sum_of_path_length => worst_sum_of_path_length,
        :worst_max_traveling_time => worst_max_traveling_time,
        :worst_sum_of_traveling_time => worst_sum_of_traveling_time,
        #
        :primary_max_path_length => primary_max_path_length,
        :primary_sum_of_path_length => primary_sum_of_path_length,
        :primary_max_traveling_time => primary_max_traveling_time,
        :primary_sum_of_traveling_time => primary_sum_of_traveling_time,
    )
end

function get_scores(ins::Instance, solution)::Dict{Symbol,Int}
    N = length(ins.starts)
    tables = get_distance_tables(ins.G, ins.goals)
    arr_shortest_path_length = map(i -> tables[i][ins.starts[i]], 1:N)

    return merge(
        Dict(
            :num_vertices => get_num_vertices(ins.G),
            :sum_of_shortest_path_lengths => sum(arr_shortest_path_length),
            :max_shortest_path_lengths => maximum(arr_shortest_path_length),
        ),
        get_scores(solution),
    )
end

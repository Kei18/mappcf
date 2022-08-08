"""
utility functions
"""

# time management
@kwdef struct Deadline
    time_limit_sec::Real
    start::UInt64 = Base.time_ns()
end

function generate_deadline(s::Real)::Deadline
    return Deadline(time_limit_sec = s)
end

function elapsed_sec(d::Deadline)::Float64
    return (Base.time_ns() - d.start) / 1.0e9
end

function is_expired(d::Deadline)::Bool
    return elapsed_sec(d) > d.time_limit_sec
end

function is_expired(d::Nothing)::Bool
    return false
end

function get_in_range(A::Vector{T}, index::Int)::T where {T<:Any}
    index < 1 && return first(A)
    return (index > length(A)) ? last(A) : A[index]
end

function find_first_element(fn::Function, A::Vector{T})::Union{Nothing,T} where {T<:Any}
    index = findfirst(fn, A)
    return isnothing(index) ? nothing : A[index]
end

# print information
function verbose(
    VERBOSE::Int,
    level::Int,
    deadline::Union{Nothing,Deadline},
    msg::String;
    CR::Bool = false,
    LF::Bool = true,
)::Nothing
    VERBOSE < level && return nothing
    CR && Core.print("\r")
    !isnothing(deadline) &&
        Core.print("elapased: ", round(elapsed_sec(deadline), digits = 3), " sec\t")
    print(msg)
    LF && Core.print("\n")
    nothing
end

abstract type SearchNode end

# general search function, see pathfinding
function search(;
    initial_node::T where {T<:SearchNode},  # initial search node
    invalid::Function,             # (T, T) -> Bool, transition checker
    check_goal::Function,          # (T) -> Bool, goal checker
    get_node_neighbors::Function,  # (T) -> Vector{T}, successor generator
    get_node_id::Function,         # (T) -> Any, node id generator
    backtrack::Function,           # (T) -> Any, backtracking
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    NameDataType::DataType = Any,  # type of id
    VERBOSE::Int = 0,
    kwargs...,
)
    OPEN = FastBinaryHeap{SearchNode}()
    CLOSED = Dict{NameDataType,Bool}()

    # insert initial node
    push!(OPEN, initial_node)

    # main loop
    loop_cnt = 0
    expanded_cnt = 1
    while !isempty(OPEN) && !is_expired(deadline)
        loop_cnt += 1
        # pop
        S = pop!(OPEN)
        S_id = get_node_id(S)
        haskey(CLOSED, S_id) && continue
        CLOSED[S_id] = true

        # check goal condition
        if check_goal(S)
            verbose(VERBOSE, 1, deadline, "explored: $loop_cnt\texpanded: $expanded_cnt")
            return backtrack(S)
        end

        # expand
        for S_new in get_node_neighbors(S)
            haskey(CLOSED, get_node_id(S_new)) && continue
            invalid(S, S_new) && continue
            push!(OPEN, S_new)
            expanded_cnt += 1
        end
    end

    verbose(VERBOSE, 1, deadline, "explored: $loop_cnt\texpanded: $expanded_cnt")

    # failure
    return nothing
end

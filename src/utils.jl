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

function is_expired(d::Union{Nothing,Deadline})::Bool
    isnothing(d) && return false
    return elapsed_sec(d) > d.time_limit_sec
end

function get_in_range(A::Vector{T}, index::Int)::T where {T<:Any}
    index < 1 && return first(A)
    return (index > length(A)) ? last(A) : A[index]
end

function find_first_element(fn::Function, A::Vector{T})::Union{Nothing,T} where {T<:Any}
    index = findfirst(fn, A)
    return isnothing(index) ? nothing : A[index]
end

abstract type SearchNode end

function search(;
    initial_node::T where {T<:SearchNode},
    invalid::Function,             # (T) -> Bool
    check_goal::Function,          # (T, T) -> Bool
    get_node_neighbors::Function,  # (T) -> Vector{T}
    get_node_id::Function,         # (T) -> Any
    get_node_score::Function,      # (T) -> Real
    backtrack::Function,           # (T) -> Any
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
)

    OPEN = PriorityQueue{SearchNode,Real}()
    CLOSED = Dict{Any,Bool}()

    # insert initial node
    enqueue!(OPEN, initial_node, get_node_score(initial_node))

    # main loop
    while !isempty(OPEN) && !is_expired(deadline)

        # pop
        S = dequeue!(OPEN)
        S_id = get_node_id(S)
        haskey(CLOSED, S_id) && continue
        CLOSED[S_id] = true

        # check goal condition
        check_goal(S) && return backtrack(S)

        # expand
        for S_new in get_node_neighbors(S)
            S_new_id = get_node_id(S_new)
            (haskey(CLOSED, S_new_id) || invalid(S, S_new)) && continue
            !haskey(OPEN, S_new) && enqueue!(OPEN, S_new, get_node_score(S_new))
        end
    end

    # failure
    return nothing
end

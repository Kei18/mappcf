function now()
    return Base.time_ns()
end

function elapsed_sec(t_s::UInt64)
    return (now() - t_s) / 1.0e9
end

function get_in_range(A::Vector{T}, index::Int)::T where {T<:Any}
    index < 1 && return first(A)
    return (index > length(A)) ? last(A) : A[index]
end

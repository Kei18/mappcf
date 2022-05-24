module MAPPFD

import Random: seed!, randperm
import Printf: @printf, @sprintf
import Base: @kwdef
import DataStructures: PriorityQueue, enqueue!, dequeue!
using Plots
import ColorSchemes
import Base.Iterators: product

function get_in_range(A::Vector{T}, index::Int)::T where {T<:Any}
    index < 1 && return first(A)
    return (index > length(A)) ? last(A) : A[index]
end

include("graph.jl")
include("libmapf.jl")
include("libotimapp.jl")
include("libsolver.jl")
include("libsolver_seq.jl")
include("exec.jl")
include("utils.jl")
include("viz.jl")
include("complete_algo.jl")

export Config, Crash, Crashes, History
export is_occupied, is_crashed, non_anonymous_failure_detector

end # module

@kwdef mutable struct Plan
    id::Int = 1
    who::Int
    path::Path
    offset::Int
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

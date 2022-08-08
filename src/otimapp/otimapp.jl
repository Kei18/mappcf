"""
OTIMAPP module

ref:
- Okumura, K., Bonnet, F., Tamura, Y., & Défago, X. (2022).
  Offline Time-Independent Multi-Agent Path Planning. IJCAI.
"""

module OTIMAPP

export Fragment, FragmentTable, register!, potential_deadlock_exists

import Base: @kwdef
import Random: randperm, seed!
import ..MAPPFD:
    Graph,
    get_neighbors,
    Path,
    Paths,
    Config,
    get_in_range,
    search,
    SearchNode,
    basic_pathfinding,
    Deadline,
    generate_deadline,
    is_expired,
    gen_h_func,
    elapsed_sec,
    verbose

include("./fragment.jl")
include("./prioritized_planning.jl")

end

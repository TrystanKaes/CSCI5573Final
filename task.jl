# CSCI5573Final/task.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

"""
_Task

Represents Stuff

# Fields
- `ID::Int64`: The unique ID of this Task.
- `work::Array{Pair(Symbol,Int64)}`: The (resource, work) pairs that makes up this tasks needs.
- `alpha::Float64`: The alpha parameter for Amdahl law calculation
- `complexity::Symbol`: The complexity of this Task (e.g :LOG_N, :N, :N_2)
- `comm::Symbol`: Direction of communication :send, :recieve, or :none
- `comm_target::Int64`: Identity of the process that needs to h
- `communication_cost::Float64`: The cost of communicating
- `data::Int64`: The amount of data this task needs to transfer

# Methods
- `val::Type{Any}`: words
"""
mutable struct _Task
    ID::Int64
    Children::Vector{Int64}
    Type::Symbol
    Cost::Int64
    Complexity::Float64

    Dependencies::Vector{Int64}

    _Task(ID::Int64, Children::Vector{Int64}, Type::Symbol, Cost::Int64=0, Complexity::Float64=0.0) =
        new(ID, Children, Type, Cost, Complexity, Vector{Int64}())


end

withComplexity(task::_Task, n::Int64) = n + Int64(round(n*task.Complexity))
working!(task::_Task, n::Int64) = (task.Cost - n) < 0 ? task.Cost=0 : task.Cost -= n
isDone(task::_Task) = task.Cost === 0

add_dependency!(task::_Task, ID::Int64) = push!(task.Dependencies, ID)
remove_dependency!(task::_Task, ID::Int64) = deleteat!(task.Dependencies, task.Dependencies .== ID)


function ParseTask(cfg::String, final=false)
    config = split(cfg, " ")

    ID = parse(Int, config[2])
    Children = Vector{Int64}()
    Type = Symbol(config[4])
    Cost = parse(Float64, config[5])/1_000_000_000 |> round |> Int64
    Complexity = parse(Float64, config[6]) |> n -> n > 0.0 ? n : 0.1

    if !final
        Children = split(config[3], ",") |> s->String.(s) |> i->parse.(Int, i)
    end

    return _Task(ID, Children, Type, Cost, Complexity)
end

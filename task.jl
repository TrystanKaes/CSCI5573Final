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
    Cost::Float64
    Alpha::Float64

    _Task(ID::Int64, Children::Vector{Int64}, Type::Symbol, Cost::Float64=0.0, Alpha::Float64=0.0) =
        new(ID, Children, Type, Cost, Alpha)
end

worked(task::_Task, n::Int64) = (task.work - n) < 0 ? 0 : task.work -= n
isDone(task::_Task) = task.work === 0


function ParseTask(cfg::String, final=false)
    config = split(cfg, " ")

    ID = parse(Int, config[2])
    Children = Vector{Int64}()
    Type = Symbol(config[4])
    Cost = parse(Float64, config[5])
    Alpha = parse(Float64, config[6])

    if !final
        Children = split(config[3], ",") |> s->String.(s) |> i->parse.(Int, i)
    end

    return _Task(ID, Children, Type, Cost, Alpha)
end

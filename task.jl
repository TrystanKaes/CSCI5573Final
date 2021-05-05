# CSCI5573Final/task.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

"""
Task

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
mutable struct Task
    ID::Int64
    alpha::Float64
    complexity::Symbol
    work::Dict{Symbol,Int64}

    data::Int64

    function Task(
        ID::Int64,
        alpha::Float64,
        complexity::Symbol,
        work::Dict{Symbol,Int64},
        data::Int64=0,
        comm::Symbol=:none,
        target::Int64=-1,
        cost::Float64=0.0,
    ) begin
        return new(ID, alpha, complexity, work, data, comm, target, cost)
    end
end

work(task::Task, n::Int64) = (task.work - n) < 0 ? 0 : task.work -= n
workRemaining(task::Task) = sum(x->x.second, task)
isDone(task::Task) = task.work.first === 0

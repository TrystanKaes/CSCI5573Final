# CSCI5573Final/task.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

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

function working!(task::_Task, n::Int64)
    if task.Cost - n <= 0
        task.Cost = 0
    else
        task.Cost = task.Cost - n
    end
    return task.Cost
end

isDone(task::_Task) = task.Cost === 0

add_dependency!(task::_Task, ID::Int64) = push!(task.Dependencies, ID)
remove_dependency!(task::_Task, ID::Int64) = deleteat!(task.Dependencies, task.Dependencies .== ID)


function ParseTask(cfg::String, final=false)
    config = split(cfg, " ")

    ID = parse(Int, config[2])
    Children = Vector{Int64}()
    Type = Symbol(config[4])

    Cost = Symbol(config[5]) === :nan ? 100 : parse(Float64, config[5])/1_000_000_000 |> round |> Int64
    Cost = Cost > 0 ? Cost : 1

    Complexity = parse(Float64, config[6])

    if !final
        Children = split(config[3], ",") |> s->String.(s) |> i->parse.(Int, i)
    end

    return _Task(ID, Children, Type, Cost, Complexity)
end

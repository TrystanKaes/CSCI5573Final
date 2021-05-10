# CSCI5573Final/components.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

# ----------------------------- Begin Processor -----------------------------
mutable struct Processor
    task::Union{_Task, Nothing}
    Multiplier::Float64
    resource::Resource
    queue::Vector{Any}
    Processor(Multiplier, resource) = new(nothing, Multiplier, resource, Vector{Int64}())
end

busy(processor::Processor) = length(processor.queue) == 0

function TotalWork(processor::Processor)
    total = 0
    for task in processor.queue
        total = total + tasks[task].Cost
    end
    return total * processor.Multiplier |> round |> Int64
end

function SendToProcessor(processor::Processor, ID::Int64, time::Int64)
    push!(processor.queue, ID)
    @with_resource processor.resource begin
        if !(ID in processor.queue)
            return
        end

        filter!(e->e!==ID, processor.queue)

        processor.task = tasks[ID]

        for i in 1:time
            task_work = Int64(round(1/processor.Multiplier))
            working!(processor.task, task_work)

            work(CLOCK_CYCLE)

            if isDone(processor.task)
                break
            end
        end

        if isDone(processor.task)
            push!(Terminated, processor.task.ID)
        else
            enqueue!(ReadyQueue, processor.task.ID)
        end
    end
    processor.task = nothing
end

# ----------------------------- End Processor -----------------------------

# ----------------------------- Begin Routing -----------------------------

@process Enqueuer() begin
    local Incoming::Vector{Int64} = []

    for i in unique(collect(keys(tasks)))
        push!(Incoming, i)
    end

    active_tasks = []

    push!(Terminated, 0)
    filter!(e->e!==0, Incoming)

    while(true)
        launch = []

        # Clean up finished tasks and enqueue newly ready tasks
        for ID in copy(Terminated)
            for child in copy(tasks[ID].Children)
                remove_dependency!(tasks[child], ID)

                if length(tasks[child].Dependencies) === 0 && child in Incoming
                    push!(launch, child)
                end
            end

            if verbose
                println("Killing $ID")
            end

            filter!(e->e!==ID, active_tasks)
            filter!(e->e!==ID, Terminated)
            filter!(e->e!==ID, Incoming)
        end

        wait(CLOCK_CYCLE)

        filter!(e->e in Incoming, launch)

        if verbose
            if !isempty(launch)
                println("launching:", launch)
            end
        end


        for task in copy(launch)
            if verbose
                println("Enqueuing $task")
            end
            enqueue!(ReadyQueue, task)
            filter!(e->e!==task, Incoming)
            push!(active_tasks, task)
        end

        if verbose
            println("Active Tasks", active_tasks)
            println("Ready Queue", ReadyQueue.data)
        end

        if length(Incoming) === 0 & length(active_tasks) === 1 & length(Terminated) === 0
            global COMPLETE = true
        end

        wait(CLOCK_CYCLE)
    end
end

@process Dispatcher(ID::Int64, processor::Int64, comm_time::Int64, process_time::Int64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    if this_task.Type === :END
        if verbose
            println("End Queued at $(current_time())")
        end
        global COMPLETE
        while(!COMPLETE)
            wait(1)
        end

        global FINISH_TIME = "$(current_time())"
        println("Simulation finished in $(FINISH_TIME)")
        stop_simulation()
    end

    if this_task.Type === :COMPUTATION
        SendToProcessor(PROCESSORS[processor], ID, process_time+comm_time)
    end
end
# ----------------------------- End Routing -----------------------------

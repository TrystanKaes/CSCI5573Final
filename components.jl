# ----------------------------- Begin Processor -----------------------------
mutable struct Processor
    working::_Task
    Multiplier::Float64
    resource::Resource
    queue::Vector{Any}
    Processor(Multiplier, resource) = new(0, nothing, Multiplier, resource, Vector{Any}())
end

busy(processor::Processor) = length(processor.queue) == 0

function TotalWork(processor::Processor)
    total = 0
    for task in processor.queue
        total = total + tasks[task].Cost
    end
    return total
end

function SendToProcessor(processor::Processor, ID::Int64, time::Int64)
    push!(processor.queue, ID)
    @with_resource processor::Processor.resource begin
        if !(ID in processor.queue)
            return
        end

        filter!(e->e!==ID, processor.queue)

        processor.working = tasks[ID]

        for i in 1:time
            work = Int64(round(1/processor.Multiplier))
            working!(this_task, work)

            work(CLOCK_CYCLE)

            if isDone(this_task)
                break
            end
        end

        if isDone(this_task)
            push!(Terminated, this_task.ID)
        else
            enqueue!(ReadyQueue, this_task.ID)
        end
    end
    processor.working = nothing
end

# ----------------------------- End Processor -----------------------------

# ----------------------------- Begin Comms -----------------------------
@process IOHandler() begin
    while(true)
        if !isempty(IOQueue)
            ID = dequeue!(IOQueue)
            @schedule now Sender(ID, COMM_TIMEOUT)
        end

        work(CLOCK_CYCLE)
    end
end

@process Sender(ID::Int64, timeout::Int64) begin
    process_store!(current_process(), :process_task, ID)
    process_store!(current_process(), :connected, false)

    local this_task = tasks[ID]

    if isDone(this_task)
        push!(Terminated, this_task.ID)
        return nothing
    else
        io_request(current_process(), IOBuses)
        for _ in 1:timeout
            if process_store(current_process(), :connected)
                if verbose
                    println("I am sending...", this_task)
                end
                working!(this_task, this_task.Cost)
                work(this_task.Cost)
                break
            end

            wait(CLOCK_CYCLE)
        end
        io_release(current_process(), IOBuses)
    end

    enqueue!(ReadyQueue, this_task.ID)
    return nothing
end

@process Reciever(ID::Int64, time::Int64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    if verbose
        println("I am recieving...", this_task)
    end

    working!(this_task, time)
    work(time)
    enqueue!(ReadyQueue, this_task.ID)
end

function IncomingCommunication(receiver::Int64)

    for process in IOBusesQueue
        io_task = tasks[process_store(process, :process_task)]

        for child in io_task.Children
            if child === receiver
                return process
            end
        end
    end

    return nothing
end
# ----------------------------- End Comms -----------------------------

# ----------------------------- Begin Routing -----------------------------

@process Enqueuer() begin
    local Incoming::Vector{Int64} = []

    for i in 1:length(unique(collect(keys(tasks))))
        push!(Incoming, i-1)
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

        for ID in copy(active_tasks)
            for child in tasks[ID].Children
                only_comms = true
                for dep in copy(tasks[child].Dependencies)
                    if tasks[dep].Type !== :TRANSFER
                        only_comms = false
                    end
                end

                if only_comms
                    push!(launch, child)
                end
            end
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
            println("IO Bus", IOBusesQueue)
        end

        if length(Incoming) === 0 & length(active_tasks) === 1 & length(Terminated) === 0
            global COMPLETE = true
        end

        wait(CLOCK_CYCLE)
    end
end

@process Dispatcher(ID::Int64, processor::Int64, time::Int64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    if this_task.Type === :END
        if verbose
            println("End Queued at $current_time()")
        end
        global COMPLETE
        while(!COMPLETE)
            wait(1)
        end
        stop_simulation()
    end

    if this_task.Type === :TRANSFER
        SendToProcessor(processor, ID, COMM_INTERRUPT_CYCLES)
        if isDone(this_task)
            push!(Terminated, this_task.ID)
        else
            enqueue!(IOQueue, this_task.ID)
        end
    end

    if this_task.Type === :COMPUTATION
        io_process = IncomingCommunication(this_task.ID)

        if io_process !== nothing
            comm_task = tasks[process_store(io_process, :process_task)]
            comm_time = comm_task.Cost
            notice = interrupt(io_process)

            remove_dependency!(this_task, comm_task.ID)

            process_store!(io_process, :connected, true)
            resume(io_process, Notice(current_time(), io_process))

            @schedule now Reciever(ID, Int64(round(comm_time)))
            return
        end

        if length(this_task.Dependencies) > 0
            enqueue!(ReadyQueue, this_task.ID)
            return
        end

        SendToProcessor(processor, ID, time)
    end
end
# ----------------------------- End Routing -----------------------------

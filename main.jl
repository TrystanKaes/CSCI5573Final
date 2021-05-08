using SimLynx
include("daggen.jl")

RUN_NAME="Cody"

MAX_TASKS=40
N_BUSSES = 10 # Number of communication buffers
N_PROCESSORS = 5
CLOCK_CYCLE = 1
QUANTUM = -1 # -1 is "until done"
COMM_TIMEOUT = 10
COMM_INTERRUPT_CYCLES = 10 # How many clock cycles to handle IO queueing

tasks      = nothing
IOBuses    = nothing
PROCESSORS = nothing
ReadyQueue = nothing
Terminated = nothing
IOQueue    = nothing

function IncomingCommunication(receiver::Int64)
    if IOBuses.queue === nothing
        return nothing
    end
    for allocation in IOBuses.queue
        io_task = tasks[process_store(allocation.process, :process_task)]

        if io_task.Children[begin].ID === receiver
            return allocation.process
        end
    end
    return nothing
end

@process Enqueuer() begin
    local Incoming = deepcopy(sort(collect(keys(tasks))))
    active_tasks = []

    push!(Terminated, 0)

    while(length(tasks) > 2)
        local finished = Terminated

        for ID in  finished # Clean up finished tasks and enqueue newly ready tasks
            for child in tasks[ID].Children
                remove_dependency!(tasks[child], ID)

                println("Enqueuing $child")
                if length(tasks[child].Dependencies) == 0 && child in Incoming
                    enqueue!(ReadyQueue, child)

                    push!(active_tasks, child)
                    deleteat!(Incoming, Incoming .== child)
                end
            end
            println("Killing $ID")
            deleteat!(Terminated, Terminated .== ID) # Remove finished processes
            delete!(tasks, ID) # Remove this task

            deleteat!(active_tasks, active_tasks .== ID)
        end

        # println(Terminated)

        # println(filter(x->tasks[x].Type === :TRANSFER, active_tasks), active_tasks)
        for ID in filter(x->tasks[x].Type === :TRANSFER, active_tasks)
            for child in tasks[ID].Children
                remove_dependency!(tasks[child], ID)

                println("Enqueuing $child")
                if length(tasks[child].Dependencies) == 0 && child in Incoming
                    enqueue!(ReadyQueue, child)
                    push!(active_tasks, child)

                    deleteat!(Incoming, Incoming .== child)
                end
            end
            deleteat!(active_tasks, active_tasks .== ID)
        end

        wait(CLOCK_CYCLE)
    end
end

@process Scheduler() begin
    while(length(tasks) > 2)
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            @schedule now Dispatcher(ID, QUANTUM)
        end

        work(CLOCK_CYCLE)
    end
end

@process IOHandler() begin
    while(length(tasks) > 2)
        if !isempty(IOQueue)
            ID = dequeue!(IOQueue)
            @schedule now Sender(ID, COMM_TIMEOUT)
        end

        work(CLOCK_CYCLE)
    end
end


@process Dispatcher(ID::Int64, time::Int64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    io_process = IncomingCommunication(this_task.ID)

    if io_process !== nothing
        comm_cost = tasks[process_store(io_process, :process_task)].Cost
        notice = interrupt(io_process)

        process_store!(io_process, :connected, true)
        resume(io_process, Notice(current_time(), io_process))

        @schedule now Reciever(ID, Int64(round(comm_cost)))
        return
    end

    if this_task.Type === :TRANSFER
        @with_resource PROCESSORS begin
            if isDone(this_task)
                push!(Terminated, this_task.ID)
            else
                enqueue!(IOQueue, this_task.ID)
            end
            work(COMM_INTERRUPT_CYCLES*CLOCK_CYCLE)
        end
    end

    if this_task.Type === :COMPUTATION
        @with_resource PROCESSORS begin
            if time === -1
                time = withComplexity(this_task, this_task.Cost)
            end

            println("$(this_task.ID) working for $time")
            working!(this_task, time)
            work(time)

            if isDone(this_task)
                push!(Terminated, this_task.ID)
            else
                enqueue!(ReadyQueue, this_task.ID)
            end
        end
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
        request(IOBuses)

        for _ in 1:timeout
            if process_store(current_process(), :connected)
                working!(this_task, this_task.Cost)
                work(this_task.Cost)
                break
            end

            wait(CLOCK_CYCLE)
        end
        release(IOBuses)
    end

    enqueue!(ReadyQueue, this_task.ID)
    return nothing
end

@process Reciever(ID::Int64, time::Int64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    working!(this_task, time)
    work(time)
    enqueue!(ReadyQueue, this_task.ID)
end

@process Sherlock() begin
    while(true)
        println(length(ReadyQueue), length(IOQueue))
        sleep(2)
    end
end


function main()
    tasklist, num_tasks = daggen(num_tasks=MAX_TASKS)

    @simulation begin
        # current_trace!(true)
        global tasks = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")

        global IOBuses = Resource(N_BUSSES, "IOBus")
        global PROCESSORS = Resource(N_PROCESSORS, "PROCESSORS")

        global IOQueue = FifoQueue{Int64}()
        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []

        # sleep(1) # Sync

        @schedule now Enqueuer()

        @schedule at 0 Scheduler()

        @schedule at 1 IOHandler()

        # @schedule at 3 Sherlock()

        start_simulation()

        println()
        print_stats(IOBuses.available, title="IO Bus Availability Statistics")
        plot_history(IOBuses.wait, file="$RUN_NAME/IOQueueWait.png", title="IO Bus Wait History")
        plot_history(IOBuses.allocated, file="$RUN_NAME/IOQueueAllocation.png", title="IO Bus Allocation History")

        println()
        print_stats(PROCESSORS.available, title="Processor Availability Statistics")
        plot_history(PROCESSORS.wait, file="$RUN_NAME/ProcessorWait.png", title="Processor Wait History")
        plot_history(PROCESSORS.allocated, file="$RUN_NAME/ProcessorAllocation.png", title="Processor Allocation History")

        println()
        print_stats(IOQueue.n, title="IO Queue Statistics")
        plot_history(IOQueue.n, file="$RUN_NAME/IOQueue.png", title="IO Queue History")

        println()
        print_stats(ReadyQueue.n, title="Ready Queue Statistics")
        plot_history(ReadyQueue.n, file="$RUN_NAME/ReadyQueue.png", title="Ready Queue History")

    end
end

if !isdir(RUN_NAME)
    mkdir(RUN_NAME)
end

main()

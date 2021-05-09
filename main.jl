using SimLynx
include("daggen.jl")
include("algorithms.jl")

verbose = false

RUN_NAME="Cody"

MAX_TASKS=1000
N_BUSSES = 10 # Number of communication buffers
CLOCK_CYCLE = 1
QUANTUM = -1 # -1 is "until done"
COMM_TIMEOUT = 100
COMM_INTERRUPT_CYCLES = 10 # How many clock cycles to handle IO queueing
COMPLETE = false

tasks        = nothing
IOBuses      = nothing
IOBusesQueue = nothing
PROCESSORS   = nothing
ReadyQueue   = nothing
Terminated   = nothing
IOQueue      = nothing


N_PROCESSORS = 5
heterogeneous = false
AVAILABLE_PROCESSORS = [
    0.9,
    0.7,
    0.3,
    0.6,
    0.2,
]

function io_request(process, resource)
    request(resource)
    push!(IOBusesQueue, process) # XXX: This might run when it isn't supposed to.
end

function io_release(process, resource)
    release(resource)
    filter!(e->e!==process, IOBusesQueue)
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

            if heterogeneous
                push!(AVAILABLE_PROCESSORS, tasks[ID].ProcessorMultiplier)
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

@process IOHandler() begin
    while(true)
        if !isempty(IOQueue)
            ID = dequeue!(IOQueue)
            @schedule now Sender(ID, COMM_TIMEOUT)
        end

        work(CLOCK_CYCLE)
    end
end


@process Dispatcher(ID::Int64, time::Int64, proccesor::Float64) begin
    process_store!(current_process(), :process_task, ID)
    local this_task = tasks[ID]

    if this_task.Type === :END
        if verbose
            println("End Queued")
        end
        global COMPLETE
        while(!COMPLETE)
            println(COMPLETE)
            wait(1)
        end
        stop_simulation()
    end

    @with_resource PROCESSORS begin
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
    end

    if length(this_task.Dependencies) > 0
        enqueue!(ReadyQueue, this_task.ID)
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

@process Sherlock() begin
    while(true)
        println(length(ReadyQueue), length(IOQueue))
        sleep(2)
    end
end


function main()
    tasklist, num_tasks = daggen(num_tasks=MAX_TASKS)

    @simulation begin
        if verbose
            current_trace!(true)
        end
        global tasks = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")

        global IOBuses = Resource(N_BUSSES, "IOBus")
        global IOBusesQueue = []
        global PROCESSORS = Resource(N_PROCESSORS, "PROCESSORS")

        global IOQueue = FifoQueue{Int64}()
        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []


        @schedule now Enqueuer()

        @schedule at 0 FCFSScheduler()

        @schedule at 0 IOHandler()

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

# main()

tasklist, num_tasks = daggen(num_tasks=MAX_TASKS)
dag = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")
println(dag[length(dag)-1])

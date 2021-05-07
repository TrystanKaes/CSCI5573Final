using SimLynx
include("daggen.jl")

MAX_TASKS=100
N_BUSSES = 10 # Number of communication buffers
N_PROCESSORS = 5
CLOCK_CYCLE = 1//10
QUANTUM = -1.0 # -1 is "until done"
COMM_TIMEOUT = 100
COMM_INTERRUPT_CYCLES = 10 # How many clock cycles to handle IO queueing

tasks = nothing

IOBuses = nothing
PROCESSORS = nothing

ReadyQueue = nothing
Terminated = nothing
IOQueue = nothing

function IncomingCommunication(receiver::Int64)
    for allocation in IOBuses.queue
        io_task = tasks[process_store(allocation.process, :process_task)]

        if io_task.Children[begin].ID === receiver
            return allocation.process
        end
    end
    return nothing
end

@process Enqueuer() begin
    enqueue!(ReadyQueue, 0)
    while(length(tasks) > 2)
        local finished = Terminated

        for ID in finished # Check whether new processes are ready
            for child in tasks[ID].Children
                remove_dependency!(tasks[child], ID)
                if length(tasks[child].Dependencies) == 0
                    enqueue!(ReadyQueue, child)
                end
            end
            deleteat!(Terminated, Terminated .== ID) # Remove finished processes
            delete!(tasks, ID) # Remove this task
        end
        work(CLOCK_CYCLE)
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

@process Dispatcher(i::Int64, work_time::Float64) begin
    process_store!(current_process(), :process_task, i)
    local this_task = tasks[i]

    incoming, io_process = IncomingCommunication(this_task.ID)

    if incoming
        io_task = tasks[process_store(io_process, :process_task)]
        notice = interrupt(io_process)

        io_time = notice.time + io_task.Cost

        @schedule now SendRecieve(io_time)
        @schedule in io_time IOProcess(io_task.ID, :SENDER)
        @schedule in io_time IOProcess(this_task.ID, :RECIEVER)
        return
    end

    if this_task.Type === :TRANSFER
        @with_resource PROCESSORS begin
            enqueue!(IOQueue, this_task.ID)
            work(COMM_INTERRUPT_CYCLES*CLOCK_CYCLE)
        end
    end

    if this_task.Type === :COMPUTATION
        @with_resource PROCESSORS begin
            if work_time === -1.0
                work_time = this_task.Cost*this_task.Complexity
            end

            working!(this_task, work_time)
            work(work_time)

            if isDone(this_task)
                push!(Terminated, this_task.ID)
            else
                enqueue!(ReadyQueue, this_task.ID)
            end
        end
    end
end

@process IOHandler() begin
    while(length(tasks) > 2)
        if !isempty(IOQueue)
            ID = dequeue!(IOQueue)
            local io_task = tasks[ID]
            @schedule now Sender(COMM_TIMEOUT)
        end

        work(CLOCK_CYCLE)
    end
end


@process Sender(time::Int64) begin
    process_store!(current_process(), :process_task, i)
    process_store!(current_process(), :connected, false)

    local this_task = tasks[i]

    if isDone(this_task)
        push!(Terminated, this_task.ID)
        return nothing
    else
        request(IOBuses)

        for _ in 1:time
            if process_store(current_process(), :connected)
                working!(this_task, work_time)
                work(this_task.Cost)
                release(IOBuses)
                break
            end

            wait(CLOCK_CYCLE)
        end
        release(IOBuses)
    end
    return nothing
end

@process Reciever(time::Float64) begin
    process_store!(current_process(), :process_task, i)
    local task = tasks[i]

    if isDone(task)
        push!(Terminated, task.ID)
    else
        enqueue!(ReadyQueue, task.ID)
    end

    work(CLOCK_CYCLE)
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
        global tasks = ListToDictDAG(tasklist, "dagGraph.dot")

        global IOBuses = Resource(N_BUSSES, "IOBus")
        global PROCESSORS = Resource(N_PROCESSORS, "CPU")

        global IOQueue = FifoQueue{Int64}()
        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []

        # current_trace!(true)

        @schedule at 0 Enqueuer()
        @schedule at 0 IOHandler()
        @schedule at 0 Sherlock()
        @schedule at 0 Scheduler()

        start_simulation()

        println()
        print_stats(IOBuses.queue_length, title="Queue Length Statistics")
        plot_history(IOBuses.queue_length, file="graphs/IOQueuelength.png", title="IO Queue Length History")

        println()
        print_stats(ReadyQueue.n, title="Ready Queue Length Statistics")
        plot_history(PROCESSORS.n, file="graphs/ReadyQueuelength.png", title="Processor Queue Length History")

        println()
        print_stats(PROCESSORS.allocated, title="Processor Allocation Statistics")
        plot_history(PROCESSORS.allocated, file="graphs/ReadyQueueAllocation.png", title="Processor Allocation History")

        println()
        print_stats(PROCESSORS.queue_length, title="Processor Queue Length Statistics")
        plot_history(PROCESSORS.queue_length, file="graphs/ProcessorQueuelength.png", title="Processor Queue Length History")

        println()
        print_stats(PROCESSORS.wait, title="Processor Queue Wait Time Statistics")
        plot_history(PROCESSORS.wait, file="graphs/ProcessorQueueWait.png", title="Processor Queue Wait Time History")

    end
end

main()

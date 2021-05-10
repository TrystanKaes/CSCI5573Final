using SimLynx

include("config.jl")
include("task.jl")
include("daggen.jl")
include("utilities.jl")
include("components.jl")
include("schedulers.jl")

verbose       = true
print         = false
stochasticish = false

tasks        = nothing
IOBuses      = nothing
IOBusesQueue = nothing
PROCESSORS   = nothing
ReadyQueue   = nothing
Terminated   = nothing
IOQueue      = nothing

COMPLETE     = false

function main(dagfile="")
    tasklist, num_tasks = nothing, nothing

    if stochasticish
        tasklist, num_tasks = daggen(num_tasks = MAX_TASKS)
    else
        tasklist, num_tasks = read_daggen(dagfile)
    end

    @simulation begin
        # current_trace!(true)
        global tasks = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")

        global IOBuses = Resource(N_BUSSES, "IOBus")
        global IOBusesQueue = []
        global IOQueue = FifoQueue{Int64}()

        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []

        global PROCESSORS = []

        for i = 1:length(PROCESSOR_POWERS)
            r = Resource(1, "PROCESSOR $i")
            m = PROCESSOR_POWERS[i]
            push!(PROCESSORS, Processor(m, r))
        end


        @schedule now Enqueuer()

        @schedule at 0 FCFSScheduler()

        @schedule at 0 IOHandler()

        start_simulation()

        if !print
            return
        end

        println()
        print_stats(IOBuses.available, title = "IO Bus Availability Statistics")
        plot_history(
            IOBuses.wait,
            file = "$RUN_NAME/IOQueueWait.png",
            title = "IO Bus Wait History",
        )
        plot_history(
            IOBuses.allocated,
            file = "$RUN_NAME/IOQueueAllocation.png",
            title = "IO Bus Allocation History",
        )

        for i = 1:length(PROCESSORS)
            println()
            print_stats(
                PROCESSORS[i].resource.available,
                title = "Processor $i Availability Statistics",
            )
            plot_history(
                PROCESSORS[i].resource.wait,
                file = "$RUN_NAME/Processor$(i)Wait.png",
                title = "Processor $i Wait History",
            )
            plot_history(
                PROCESSORS[i].resource.allocated,
                file = "$RUN_NAME/Processor$(i)Allocation.png",
                title = "Processor $i Allocation History",
            )
        end

        println()
        print_stats(IOQueue.n, title = "IO Queue Statistics")
        plot_history(IOQueue.n, file = "$RUN_NAME/IOQueue.png", title = "IO Queue History")

        println()
        print_stats(ReadyQueue.n, title = "Ready Queue Statistics")
        plot_history(
            ReadyQueue.n,
            file = "$RUN_NAME/ReadyQueue.png",
            title = "Ready Queue History",
        )

    end
end

if !isdir(RUN_NAME)
    mkdir(RUN_NAME)
end

main("z_input_dag")

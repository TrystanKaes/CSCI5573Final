using SimLynx

include("components.jl")
include("config.jl")
include("daggen.jl")
include("schedulers.jl")
include("utilities.jl")


verbose = false
COMPLETE = false

tasks        = nothing
IOBuses      = nothing
IOBusesQueue = nothing
PROCESSORS   = nothing
ReadyQueue   = nothing
Terminated   = nothing
IOQueue      = nothing

function main()
    tasklist, num_tasks = daggen(num_tasks=MAX_TASKS)

    @simulation begin
        if verbose
            current_trace!(true)
        end
        global tasks = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")

        global IOBuses = Resource(N_BUSSES, "IOBus")
        global IOBusesQueue = []
        global IOQueue = FifoQueue{Int64}()

        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []

        global PROCESSORS = []

        for i in 1:length(PROCESSOR_POWERS)
            r = Resource(1, "PROCESSOR $i")
            m = PROCESSOR_POWERS[i]
            append!(PROCESSORS, Processor(m, r))
        end


        @schedule now Enqueuer()

        @schedule at 0 FCFSScheduler()

        @schedule at 0 IOHandler()

        start_simulation()

        println()
        print_stats(IOBuses.available, title="IO Bus Availability Statistics")
        plot_history(IOBuses.wait, file="$RUN_NAME/IOQueueWait.png", title="IO Bus Wait History")
        plot_history(IOBuses.allocated, file="$RUN_NAME/IOQueueAllocation.png", title="IO Bus Allocation History")

        for i in 1:N_PROCESSORS
            println()
            print_stats(PROCESSORS[i].available, title="Processor Availability Statistics")
            plot_history(PROCESSORS[i].wait, file="$RUN_NAME/ProcessorWait.png", title="Processor Wait History")
            plot_history(PROCESSORS[i].allocated, file="$RUN_NAME/ProcessorAllocation.png", title="Processor Allocation History")
        end

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

tasklist, num_tasks = daggen(num_tasks=30)
dag = ListToDictDAG(tasklist, "$RUN_NAME/dagGraph.dot")
ranks = RankHeft(dag)

for rank in sort(ranks)
    println(rank)
end

afts = AFTHeft(ranks, PROCESSOR_POWERS)

for aft in sort(afts)
    println(aft)
end

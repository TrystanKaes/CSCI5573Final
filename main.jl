using SimLynx

include("config.jl")
include("task.jl")
include("daggen.jl")
include("utilities.jl")
include("components.jl")
include("schedulers.jl")

verbose       = false
print_results = false
stochasticish = true

tasks        = nothing
comms        = nothing
PROCESSORS   = nothing
ReadyQueue   = nothing
Terminated   = nothing

COMPLETE     = false

function main(dag_file="")
    RUN_NAME = ""
    tasklist, num_tasks = nothing, nothing

    if stochasticish
        RUN_NAME = "RandomDag$(rand(0:10000))"
        tasklist, num_tasks = daggen(num_tasks = MAX_TASKS)
    else
        RUN_NAME = dag_file
        tasklist, num_tasks = read_daggen(dag_file)
    end

    RUN_PATH = SIM_RUN * "/" * RUN_NAME

    if !isdir(RUN_PATH)
        mkdir(RUN_PATH)
    end

    @simulation begin
        # current_trace!(true)
        global tasks, comms = ListToDictDAG(tasklist, "$RUN_PATH/dagGraph.dot")

        global ReadyQueue = FifoQueue{Int64}()

        global Terminated = []

        global PROCESSORS = []

        for i = 1:length(PROCESSOR_POWERS)
            r = Resource(1, "PROCESSOR $i")
            m = PROCESSOR_POWERS[i]
            push!(PROCESSORS, Processor(m, r))
        end


        @schedule now Enqueuer()

        # @schedule at 0 FCFSScheduler()
        @schedule at 0 HEFTScheduler()

        start_simulation()

        if !print_results
            return
        end

        for i = 1:length(PROCESSORS)
            if !isdir("$(RUN_PATH)/Processor$(i)")
                mkdir("$(RUN_PATH)/Processor$(i)")
            end
            write_to_CSV(
                PROCESSORS[i].resource.wait,
                "$(RUN_PATH)/Processor$(i)/waitStatistics.csv",
            )
            write_to_CSV(
                PROCESSORS[i].resource.queue_length,
                "$(RUN_PATH)/Processor$(i)/QueueLengthStatistics.csv",
            )
            plot_history(
                PROCESSORS[i].resource.wait,
                file = "$(RUN_PATH)/Processor$(i)/WaitHistory.png",
                title = "Processor $i Wait History",
            )
            plot_history(
                PROCESSORS[i].resource.allocated,
                file = "$(RUN_PATH)/Processor$(i)/AllocationHistory.png",
                title = "Processor $i Allocation History",
            )
        end

        write_to_CSV(
            ReadyQueue.n,
            "$(RUN_PATH)/ReadyQueueStatistics.csv",
        )
        plot_history(
            ReadyQueue.n,
            file = "$(RUN_PATH)/ReadyQueue.png",
            title = "Ready Queue History",
        )
    end
end

if !isdir(SIM_RUN)
    mkdir(SIM_RUN)
end

println("Starting simulation")
main()

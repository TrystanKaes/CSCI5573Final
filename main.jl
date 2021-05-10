using SimLynx

include("config.jl")
include("task.jl")
include("daggen.jl")
include("utilities.jl")
include("components.jl")
include("schedulers.jl")

verbose        = false
output_results = true
stochasticish  = true

tasks        = nothing
comms        = nothing
PROCESSORS   = nothing
ReadyQueue   = nothing
Terminated   = nothing

COMPLETE     = false
FINISH_TIME  = ""

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
        # @schedule at 0 HEFTScheduler()
        # @schedule at 0 PEFTScheduler()
        @schedule at 0 List_Scheduler()

        start_simulation()

        if output_results
            print_results(RUN_PATH)
        end
    end
    return RUN_PATH
end

if !isdir(SIM_RUN)
    mkdir(SIM_RUN)
end

println("Starting simulation")
run_path = main("test.dag")

open("$(run_path)/runtimes.txt", "a") do file
    write(file, "$(FINISH_TIME)\n")
end

return

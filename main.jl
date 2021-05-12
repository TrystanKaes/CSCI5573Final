# CSCI5573Final/main.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

using SimLynx

include("config.jl")
include("task.jl")
include("daggen.jl")
include("utilities.jl")
include("components.jl")
include("schedulers.jl")

debug          = false
verbose        = false
output_results = false
stochasticish  = false

COMMS        = nothing
TASKS        = nothing
PROCESSORS   = nothing
READY_QUEUE  = nothing
TERMINATED   = nothing

COMPLETE     = false
FINISH_TIME  = ""

function run_sim(dag_file="")
    RUN_NAME = ""
    tasklist, num_tasks = nothing, nothing

    if stochasticish
        RUN_NAME = "RandomDag$(rand(0:10000))"
        tasklist, num_tasks = daggen(num_tasks = MAX_TASKS)
    else
        RUN_NAME = replace(dag_file, "."=>"")
        tasklist, num_tasks = read_daggen("SampleDAGS/"*dag_file)
    end

    RUN_PATH = SIM_RUN * "/" * RUN_NAME

    if !isdir(RUN_PATH)
        mkdir(RUN_PATH)
    end

    @simulation begin
        if debug
            current_trace!(true)
        end

        global TASKS, COMMS = ListToDictDAG(tasklist, "$RUN_PATH/dagGraph.dot")

        global READY_QUEUE = FifoQueue{Int64}()

        global TERMINATED = []

        global PROCESSORS = []

        for i = 1:length(PROCESSOR_POWERS)
            r = Resource(1, "PROCESSOR $i")
            m = PROCESSOR_POWERS[i]
            push!(PROCESSORS, Processor(m, r))
        end


        @schedule now Enqueuer()

        @schedule at 0 FCFSScheduler()
        # @schedule at 0 HEFTScheduler()
        # @schedule at 0 PEFTScheduler()
        # @schedule at 0 ProposedScheduler()

        start_simulation()

        if output_results
            print_results(RUN_PATH)
        end
    end
    return RUN_PATH
end



function main()
    if !isdir(SIM_RUN)
        mkdir(SIM_RUN)
    end

    println("Starting simulation")
    for dagfile in DAGS
        for i in 1:TRIALS
            if i === TRIALS
                global output_results = true
            end
            run_path = run_sim(dagfile)
            open("$(run_path)/runtimes.txt", "a") do file
                write(file, "$(FINISH_TIME)\n")
            end
        end
        global output_results = false
    end

    return
end

main()

# CSCI5573Final/utilities.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

function parentsof(ID, tasks)
    parents = []
    for task in collect(Int64, keys(tasks))
        if ID in tasks[task].Children
            push!(parents, task)
        end
    end
    return parents
end

function write_to_CSV(var::SimLynx.Variable, file="Statistics.csv")
    stats = var.stats
    open(file, "w") do f
        write(f, "min, max, n, mean, variance, stddev\n")
        write(f, "$(stats.min), $(stats.max), $(stats.n), $(stats.mean), $(stats.variance), $(stats.stddev)\n")
    end
end

function print_results(RUN_PATH)
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

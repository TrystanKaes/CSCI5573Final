# CSCI5573Final/schedulers.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

# ----------------------------- Begin FCFS -----------------------------
@process FCFSScheduler() begin
    processor = 0
    while(true)
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            work_time = tasks[ID].Cost
            @schedule now Dispatcher(ID, processor, work_time)
        end

        processor = processor === length(PROCESSORS) ? 1 : processor + 1

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End FCFS -----------------------------

# ----------------------------- Begin HEFT -----------------------------
function RankHeft(task_graph)
    ranks = Dict{Int64,Float64}()

    RecursiveRankTask(ID, ranks) = begin
        task = task_graph[ID]

        rank = 0.0
        for child in task.Children
            new_rank = RecursiveRankTask(child, ranks)
            rank = max(new_rank, rank)
        end
        ranks[ID] = task.Cost + rank
        return ranks[ID]
    end

    RecursiveRankTask(0, ranks)

    return ranks
end

function AFTHeft(ranks, _processors)
    AFT = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        ranks[ID] = max((_processors .* rank)...) |> round
    end

    return ranks
end

@process HEFTScheduler(_processors) begin
    rank = RankHeft(tasks)
    aft = AFTHeft(rank, _processors)

    global PROCESSORS

    while(true)
        readyList = []
        while(!isempty(ReadyQueue)) # Empty the queue to start scheduling
            ID = dequeue!(ReadyQueue)
            push!(readyList, ID)
        end

        max_rank = 0.0
        ni = -1
        for task in readyList
            if rank[task] > max_rank
                ni = task
            end
        end

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End HEFT -----------------------------


# ----------------------------- Begin PEFT -----------------------------
@process PEFTScheduler() begin
    while(true)
        readyList = []
        while(!isempty(ReadyQueue)) # Empty the queue to start scheduling
            ID = dequeue!(ReadyQueue)
            push!(readyList, ID)
        end

        # Schedule Stuff with readyList

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End PEFT -----------------------------

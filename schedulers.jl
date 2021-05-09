
# ----------------------------- Begin FCFS -----------------------------
@process FCFSScheduler() begin
    while(true)
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            @schedule now Dispatcher(ID, PROCESSOR, QUANTUM)
        end

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

function AFTHeft(ranks, processors)
    AFT = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        ranks[ID] = max((processors .* rank)...) |> round
    end

    return ranks
end

@process HEFTScheduler(processors) begin
    rank = RankHeft(tasks)
    aft = AFTHeft(rank, processors)

    global AVAILABLE_PROCESSORS

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

        min(TotalWork.(PROCESSORS))



        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End HEFT -----------------------------


# ----------------------------- Begin PEFT -----------------------------
@process PEFTScheduler() begin
    available_processors = copy(AVAILABLE_PROCESSORS)
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

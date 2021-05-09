
# ----------------------------- Begin FCFS -----------------------------
@process FCFSScheduler() begin
    while(true)
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            @schedule now Dispatcher(ID, QUANTUM)
        end

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End FCFS -----------------------------


# ----------------------------- Begin HEFT -----------------------------
function RankHeft(task_graph)
    ranks::Dict{Int64,Float64}()
    exit_node = task_graph[length(task_graph)-1]

    function RecursiveRankTask(ID, ranks)
        task = task_graph[ID]

        ranks[ID] = task.Cost
    end

end


@process HEFTScheduler() begin
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

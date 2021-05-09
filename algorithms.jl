
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

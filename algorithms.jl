
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
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            @schedule now Dispatcher(ID, QUANTUM)
        end

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End HEFT -----------------------------


# ----------------------------- Begin PEFT -----------------------------
@process PEFTScheduler() begin
    while(true)
        if !isempty(ReadyQueue)
            ID = dequeue!(ReadyQueue)
            @schedule now Dispatcher(ID, QUANTUM)
        end

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End PEFT -----------------------------

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
function Rank_HEFT(task_graph)
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

function AFT_HEFT(ranks, processors)
    AFT = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        ranks[ID] = max(((p->p.Multiplier*rank).(processors))...) |> round
    end

    return ranks
end

function EST_HEFT(task, processor, aft)
    available = current_time() + TotalWork(PROCESSORS[processor])

    # Sorry for this line here. It does:
    # max{Tavailable(pj), max{AFT(nm)+cost_m,i} for nm in parents(ni)}
    # Not sure if that makes it better but... Bam
    MaxParentAFTPlusCost = max(0, map(p->max(aft[p] + tasks[p].Cost, task), parentsof(task, tasks))...)

    return max(available, MaxParentAFTPlusCost)
end

function WIJ_HEFT(task, processor)
    if tasks[task].Type === :TRANSFER
        return tasks[task].Cost
    else
        return PROCESSORS[processor].Multiplier * tasks[task].Cost
    end
end

@process HEFTScheduler() begin
    rank = Rank_HEFT(tasks)
    aft = AFT_HEFT(rank, PROCESSORS)
    makespan = max(collect(Int64, keys(aft))...)

    global PROCESSORS

    while(true)
        readyList = []

        max_rank = 0.0
        min_EFT = Inf
        pj = -1
        ni = -1

        if isempty(ReadyQueue)
            wait(CLOCK_CYCLE)
            continue
        end

        while(!isempty(ReadyQueue)) # Empty the queue to start scheduling
            ID = dequeue!(ReadyQueue)
            push!(readyList, ID)
        end

        while(length(readyList) > 0)
            # Max Rank Task
            for task in readyList
                if rank[task] > max_rank
                    ni = task
                end
            end

            # Minimum EFT
            for j in 1:length(PROCESSORS)
                if EST_HEFT(ni, j, aft) + WIJ_HEFT(ni, j) < min_EFT
                    pj = j
                end
            end

            wik = min(map(k->WIJ_HEFT(ni, k), 1:length(PROCESSORS))...)

            if WIJ_HEFT(ni, pj) <= wik
                # Schedule this task to start on that processor
                @schedule now Dispatcher(ni, pj, tasks[ni].Cost)
            else
                pk = filter(k->WIJ_HEFT(ni, k) === wik, 1:length(PROCESSORS))[begin]
                EFT(t, p) = EST_HEFT(t, p, aft) + WIJ_HEFT(t, p)

                wa_numerator = EFT(ni, pj) - EFT(ni, pk)
                wa_denominator = EFT(ni, pj) / EFT(ni, pk)

                weight_abstract = abs(wa_numerator/wa_denominator)
                weight_ni = WIJ_HEFT(ni, pj) / tasks[ni].Cost

                cross_threshold = abs(weight_ni/weight_abstract)

                if cross_threshold <= 1-rand()
                    @schedule now Dispatcher(ni, pj, tasks[ni].Cost)
                else
                    @schedule now Dispatcher(ni, pk, tasks[ni].Cost)
                end
            end
            filter!(i->i!==ni, readyList)
            work(CLOCK_CYCLE)
        end
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

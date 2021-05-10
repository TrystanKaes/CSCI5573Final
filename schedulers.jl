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
            parents   = parentsof(ID, tasks)
            comm_cost     = sum(map(p->comms[Edge(p, ID)], parents))
            @schedule now Dispatcher(ID, processor, work_time, comm_cost)
        end

        processor = processor === length(PROCESSORS) ? 1 : processor + 1

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End FCFS -----------------------------

# ----------------------------- Begin List Scheduler -----------------------------

# ----------------------------- End List Scheduler -----------------------------

# ----------------------------- Begin HEFT -----------------------------
function UpwardRank(task, communication)
    ranks = Dict{Int64, Int64}()

    RecursiveRankTask(ID, ranks) = begin

        rank = 0.0
        for child in task[ID].Children
            new_rank = communication[Edge(ID, child)] + RecursiveRankTask(child, ranks)
            if new_rank > rank
                rank = new_rank
            end
        end
        ranks[ID] = task[ID].Cost + rank
    end
    RecursiveRankTask(0, ranks)
    return ranks
end

function DownwardRank(task, communication)
    ranks = Dict{Int64, Int64}()

    RecursiveRankTask(ID, ranks) = begin

        rank = 0.0
        for parent in parentsof(ID, task)
            new_rank = RecursiveRankTask(parent, ranks) + task[parent].Cost + communication[Edge(parent, ID)]
            if new_rank > rank
                rank = new_rank
            end
        end
        ranks[ID] = task[ID].Cost + rank
    end
    exit_node = max(unique(collect(keys(task)))...)
    RecursiveRankTask(exit_node, ranks)
    return ranks
end


function AFT_heft(ranks, processors)
    AFT = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        ranks[ID] = max(((p->p.Multiplier*rank).(processors))...) |> round
    end

    return ranks
end

function EST_heft(ni, pj, aft)
    available = current_time() + TotalWork(PROCESSORS[pj])
    max_pred = max(map(n->aft[n] + comms[Edge(ni, n)], parentsof(ni, tasks))...)

    return max(available, max_pred)
end

function WIJ_heft(ni, pj)
    return PROCESSORS[pj].Multiplier * tasks[ni].Cost
end

@process HEFTScheduler() begin
    rankU = UpwardRank(tasks, comms)
    aft = AFT_heft(rankU, PROCESSORS)


    while(true)
        if isempty(ReadyQueue)
            wait(CLOCK_CYCLE)
            continue
        end

        readyList = []
        min_EFT = Inf
        pj = -1

        while(!isempty(ReadyQueue)) # Empty the queue to start scheduling
            ID = dequeue!(ReadyQueue)
            push!(readyList, ID)
        end

        while(length(readyList) > 0)
            readyList = sort(readyList, lt=(a, b) -> rankU[a] > rankU[b])
            ni = readyList[1]
            deleteat!(readyList, 1)

            EFT(n, p) = WIJ_heft(n, p) + EST_heft(n, p, aft)


            for j in 1:length(PROCESSORS)
                if EFT(ni, j) < min_EFT
                    min_EFT = EFT(ni, j)
                    pj = j
                end
            end

            comm_cost = 0
            if !isempty(tasks[ni].Children)
                comm_cost = sum(l->comms[Edge(ni,l)], tasks[ni].Children)
            end

            @schedule now Dispatcher(ni, pj, comm_cost, tasks[ni].Cost)
        end

        # Schedule

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End HEFT -----------------------------


# ----------------------------- Begin PEFT -----------------------------

# ----------------------------- End PEFT -----------------------------

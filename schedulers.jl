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
    aft = Dict{Int64,Float64}()

    for (ID, rank) in ranks # This might be wrong
        aft[ID] = max(((p->p.Multiplier*rank).(processors))...) |> round
    end

    return aft
end

function EST_heft(ni, pj, aft)
    available = current_time() + TotalWork(PROCESSORS[pj])
    max_pred = 0

    for parent in parentsof(ni, tasks)
        cij = comms[Edge(ni, parent)]
        if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
            cij = 0
        end
        new_pred = aft[parent] + cij
        if new_pred > max_pred
            max_pred = new_pred
        end
    end

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
            if !isempty(parentsof(ni, tasks))
                for parent in parentsof(ni, tasks)
                    if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
                        cij = 0
                    else
                        comm_cost += comms[Edge(ni, parent)]
                    end
                end
            end

            @schedule now Dispatcher(ni, pj, comm_cost, tasks[ni].Cost)
        end

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End HEFT -----------------------------

# ----------------------- Begin List Scheduler -----------------------
function Rank_List_Scheduler(task_graph)
    ranks = Dict{Int64,Float64}()

    RecursiveRankTask(ID, ranks) = begin
        task = task_graph[ID]

        rank = 0.0
        for child in task.Children
            new_rank = RecursiveRankTask(child, ranks) + comms[Edge(ID, child)]
            rank = max(new_rank, rank)
        end
        # println("Giving rank ", task.Cost + rank, " to task ", ID)
        ranks[ID] = task.Cost + rank
        return ranks[ID]
    end

    RecursiveRankTask(0, ranks)

    return ranks
end

function AFT_List_Scheduler(ranks, processors)
    AFT = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        ranks[ID] = max(((p->p.Multiplier*rank).(processors))...) |> round
    end

    return ranks
end

function EST_List_Scheduler(task, processor, aft)
    available = current_time() + TotalWork(PROCESSORS[processor])

    # Sorry for this line here. It does:
    # max{Tavailable(pj), max{AFT(nm)+cost_m,i} for nm in parents(ni)}
    # Not sure if that makes it better but... Bam
    MaxParentAFTPlusCost = max(0, map(p->max(aft[p] + tasks[p].Cost, task), parentsof(task, tasks))...)

    return max(available, MaxParentAFTPlusCost)
end

function WIJ_List_Scheduler(task, processor)
    if tasks[task].Type === :TRANSFER
        return tasks[task].Cost
    else
        # Check whether this process takes advantage of the speedup
        return PROCESSORS[processor].Multiplier * tasks[task].Cost
    end
end

@process List_Scheduler() begin
    rank = Rank_List_Scheduler(tasks)
    aft = AFT_List_Scheduler(rank, PROCESSORS)
    makespan = max(collect(Int64, keys(aft))...)

    global PROCESSORS

    while(true)
        readyList = []

        max_rank = -Inf
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
                ij_EFT = EST_List_Scheduler(ni, j, aft) + WIJ_List_Scheduler(ni, j)
                println("EFT of Task ", ni, " on processor ", j, " is ", ij_EFT)
                if ij_EFT < min_EFT
                    min_EFT = ij_EFT
                    pj = j
                end
            end

            wik = min(map(k->WIJ_List_Scheduler(ni, k), 1:length(PROCESSORS))...)

            comm_cost = 0
            if !isempty(tasks[ni].Children)
                comm_cost = sum(l->comms[Edge(ni,l)], tasks[ni].Children)
            end

            if WIJ_List_Scheduler(ni, pj) <= wik
                # println("Wij less than wik for task ", ni, " dispatching task ", ni, " to processor ", pj)
                # Schedule this task to start on that processor
                @schedule now Dispatcher(ni, pj, comm_cost, tasks[ni].Cost)
            else
                # println("Wij NOT less than wik for task ", ni)
                pk = filter(k->WIJ_List_Scheduler(ni, k) === wik, 1:length(PROCESSORS))[begin]
                EFT(t, p) = EST_List_Scheduler(t, p, aft) + WIJ_List_Scheduler(t, p)

                wa_numerator = EFT(ni, pj) - EFT(ni, pk)
                wa_denominator = EFT(ni, pj) / EFT(ni, pk)

                weight_abstract = abs(wa_numerator/wa_denominator)
                weight_ni = WIJ_List_Scheduler(ni, pj) / tasks[ni].Cost
                # println("Abstract weight: ", weight_abstract, " and real weight: ", weight_ni)
                cross_threshold = abs(weight_ni/weight_abstract)

                if cross_threshold <= 1-rand()
                    # println("Dispatching task ", ni, " to processor ", pj)
                    @schedule now Dispatcher(ni, pj, comm_cost, tasks[ni].Cost)
                else
                    # println("Dispatching task ", ni, " to processor ", pk)
                    @schedule now Dispatcher(ni, pk, comm_cost, tasks[ni].Cost)
                end
            end
            filter!(i->i!==ni, readyList)
            work(CLOCK_CYCLE)
        end
    end
end
# ----------------------- End List Scheduler -------------------------

# ----------------------------- Begin PEFT -----------------------------
function W_peft(tj, pw)
    return PROCESSORS[pw].Multiplier * tasks[tj].Cost
end

function OCT(tasks) # Paper used recursion but... it blows the stack.
    exit_task = max(unique(collect(keys(tasks)))...)
    oct = Dict{Int64, Array{Int64, 1}}()

    oct[exit_task] = repeat([0], length(PROCESSORS)) # Set Exit

    predecessors = parentsof(exit_task, tasks)
    while length(predecessors) > 0
        ni = pop!(predecessors)

        while !all(map(s->haskey(oct, s), tasks[ni].Children))
            nj = -1
            try
                nj = pop!(predecessors)
            catch
                println("An error occured during OCT calculation")
                sleep(5)
                return
            end
            insert!(predecessors, 1, ni)
            ni = nj
        end

        oct[ni] = repeat([0], length(PROCESSORS))

        for pj in 1:length(PROCESSORS)
            my_oct = -Inf
            for child in tasks[ni].Children
                min_child_oct = Inf
                for pw in 1:length(PROCESSORS)
                    child_oct = oct[child][pw]
                    child_cost = tasks[child].Cost
                    child_comm_cost = pw === pj ? 0 : comms[Edge(ni, child)]
                    new_min_oct = child_oct + child_cost + child_comm_cost
                    if new_min_oct < min_child_oct
                        min_child_oct = new_min_oct
                    end
                end
                if min_child_oct > my_oct
                    my_oct = min_child_oct
                end
            end
            oct[ni][pj] = my_oct
        end
        predecessors = append!(filter(f->!(f in predecessors), parentsof(ni, tasks)), predecessors)
    end

    return oct
end

function RankOct(oct, tasks)
    ranks = Dict{Int64, Int64}()
    for (ti, _) in tasks
        ranks[ti] = sum(map(pj->oct[ti][pj], 1:length(PROCESSORS)))
    end
    return ranks
end

function WIJ_peft(ni, pj)
    return PROCESSORS[pj].Multiplier * tasks[ni].Cost
end

function AFT_peft(ranks, processors)
    aft = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        aft[ID] = max(((p->p.Multiplier*rank).(processors))...) |> round
    end

    return aft
end

function EST_peft(ni, pj, aft)
    available = current_time() + TotalWork(PROCESSORS[pj])
    max_pred = 0

    for parent in parentsof(ni, tasks)
        cij = comms[Edge(ni, parent)]
        if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
            cij = 0
        end
        new_pred = aft[parent] + cij
        if new_pred > max_pred
            max_pred = new_pred
        end
    end

    return max(available, max_pred)
end


@process PEFTScheduler() begin
    oct = OCT(tasks)
    rank_oct = RankOct(oct, tasks)
    aft = AFT_peft(rank_oct, PROCESSORS)

    while(true)
        if isempty(ReadyQueue)
            wait(CLOCK_CYCLE)
            continue
        end

        readyList = []
        min_oEFT = Inf
        pj = -1

        while(!isempty(ReadyQueue)) # Empty the queue to start scheduling
            ID = dequeue!(ReadyQueue)
            push!(readyList, ID)
        end

        while(length(readyList) > 0)
            readyList = sort(readyList, lt=(a, b) -> rank_oct[a] > rank_oct[b])
            ni = readyList[1]
            deleteat!(readyList, 1)


            EFT(n, p) = WIJ_peft(n, p) + EST_peft(n, p, aft)
            Oeft(n, p) = EFT(n, p) + oct[n][p]

            for j in 1:length(PROCESSORS)
                if Oeft(ni, j) < min_oEFT
                    min_oEFT = Oeft(ni, j)
                    pj = j
                end
            end

            comm_cost = 0
            if !isempty(parentsof(ni, tasks))
                for parent in parentsof(ni, tasks)
                    if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
                        cij = 0
                    else
                        comm_cost += comms[Edge(ni, parent)]
                    end
                end
            end

            @schedule now Dispatcher(ni, pj, comm_cost, tasks[ni].Cost)
        end
        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End PEFT -----------------------------

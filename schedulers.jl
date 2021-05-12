# CSCI5573Final/schedulers.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

# -------------------- Begin Shared Functions -----------------------------
function EST(ni, pj, aft)
    available = current_time() + TotalWork(PROCESSORS[pj])
    max_pred = 0

    for parent in parentsof(ni, TASKS)
        cij = COMMS[Edge(ni, parent)]
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

function AFT(ranks, processors)
    aft = Dict{Int64,Float64}()

    for (ID, rank) in ranks
        comm_cost = 0
        if !isempty(TASKS[ID].Children)
            comm_cost = sum(l->COMMS[Edge(ID,l)], TASKS[ID].Children)
        end

        aft[ID] = max(((p->p.Multiplier*rank).(processors))...) + comm_cost |> round
    end

    return aft
end

EFT(t, p, aft) = EST(t, p, aft) + WIJ(t, p)

function WIJ(task, processor)
    return PROCESSORS[processor].Multiplier * TASKS[task].Cost
end

function CommCost(ni, pj)
    comm_cost = 0
    if !isempty(parentsof(ni, TASKS))
        for parent in parentsof(ni, TASKS)
            if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
                cij = 0
            else
                comm_cost += COMMS[Edge(ni, parent)]
            end
        end
    end
    return comm_cost
end

Cost(ID) = TASKS[ID].Cost
# ------------------------- End Functions ---------------------------------

# ----------------------- Begin List Scheduler -----------------------
@process ProposedScheduler() begin
    global PROCESSORS
    global SCHEDULER = "ProposedScheduler"

    rank = ProposedRank(TASKS)
    aft = AFT(rank, PROCESSORS)

    while(true)
        if isempty(READY_QUEUE)
            wait(CLOCK_CYCLE)
            continue
        end

        ready_list = []
        max_rank   = Inf * -1
        min_EFT    = Inf
        pj         = -1
        ni         = -1

        # Empty the queue to start scheduling
        while(!isempty(READY_QUEUE))
            ID = dequeue!(READY_QUEUE)
            push!(ready_list, ID)
        end

        while(length(ready_list) > 0)
            # Max Rank Task
            for task in ready_list
                if rank[task] > max_rank
                    max_rank = rank[task]
                    ni = task
                end
            end

            # Minimum EFT Processor
            for j in 1:length(PROCESSORS)
                if EFT(ni, j, aft) < min_EFT
                    min_EFT = EFT(ni, j, aft)
                    pj = j
                end
            end

            wik = min(map(k->WIJ(ni, k), 1:length(PROCESSORS))...)

            if WIJ(ni, pj) <= wik
                # Schedule this task to start on that processor
                @schedule now Dispatcher(ni, pj, Cost(ni), CommCost(ni, pj))
            else
                pk = filter(k->WIJ(ni, k) === wik, 1:length(PROCESSORS))[begin]

                wa_numerator    = EFT(ni, pj, aft) - EFT(ni, pk, aft)
                wa_denominator  = EFT(ni, pj, aft) / EFT(ni, pk, aft)

                weight_ni       = WIJ(ni, pj) / TASKS[ni].Cost

                weight_abstract = abs(wa_numerator/wa_denominator)
                cross_threshold = abs(weight_ni/weight_abstract)

                if cross_threshold <= 1-rand()
                    @schedule now Dispatcher(ni, pj, Cost(ni), CommCost(ni, pj))
                else
                    @schedule now Dispatcher(ni, pk, Cost(ni), CommCost(ni, pj))
                end
            end
            filter!(nj->nj!==ni, ready_list)
            work(CLOCK_CYCLE)
        end
    end
end

function ProposedRank(task_graph)
    ranks = Dict{Int64,Float64}()

    RecursiveRankTask(ID, ranks) = begin
        task = task_graph[ID]

        rank = 0.0
        for child in task.Children
            new_rank = RecursiveRankTask(child, ranks) + COMMS[Edge(ID, child)]
            rank = max(new_rank, rank)
        end

        ranks[ID] = task.Cost + rank
        return ranks[ID]
    end

    RecursiveRankTask(0, ranks)

    return ranks
end


# ----------------------- End Proposed -------------------------

# ----------------------------- Begin HEFT -----------------------------
@process HEFTScheduler() begin
    global SCHEDULER = "HEFTScheduler"
    rank = UpwardRank(TASKS, COMMS)
    aft = AFT(rank, PROCESSORS)

    while(true)
        if isempty(READY_QUEUE)
            wait(CLOCK_CYCLE)
            continue
        end

        ready_list = []
        min_EFT    = Inf
        pj         = -1
        ni         = -1

        while(!isempty(READY_QUEUE)) # Empty the queue to start scheduling
            ID = dequeue!(READY_QUEUE)
            push!(ready_list, ID)
        end

        while(length(ready_list) > 0)
            ready_list = sort(ready_list, lt=(a, b) -> rank[a] > rank[b])
            ni = ready_list[1]
            deleteat!(ready_list, 1)

            for j in 1:length(PROCESSORS)
                if EFT(ni, j, aft) < min_EFT
                    min_EFT = EFT(ni, j, aft)
                    pj = j
                end
            end

            comm_cost = 0
            if !isempty(parentsof(ni, TASKS))
                for parent in parentsof(ni, TASKS)
                    if parent in PROCESSORS[pj].queue || parent === PROCESSORS[pj].task
                        cij = 0
                    else
                        comm_cost += COMMS[Edge(ni, parent)]
                    end
                end
            end

            @schedule now Dispatcher(ni, pj, Cost(ni), CommCost(ni, pj))
        end

        work(CLOCK_CYCLE)
    end
end

function UpwardRank(task, communication)
    ranks = Dict{Int64, Int64}()

    RecursiveRankTask(ID, ranks) = begin

        rank = 0.0
        for child in task[ID].Children
            new_rank = communication[Edge(ID, child)] + RecursiveRankTask(child, ranks)

            rank = max(new_rank, rank)
        end
        ranks[ID] = task[ID].Cost + rank
    end

    RecursiveRankTask(0, ranks)

    return ranks
end

# ----------------------------- End HEFT -----------------------------

# ----------------------------- Begin PEFT -----------------------------
@process PEFTScheduler() begin
    global SCHEDULER = "PEFTScheduler"
    oct = OCT(TASKS)
    rank_oct = RankOCT(oct, TASKS)
    aft = AFT(rank_oct, PROCESSORS)

    while(true)
        if isempty(READY_QUEUE)
            wait(CLOCK_CYCLE)
            continue
        end

        ready_list  = []
        min_OEFT    = Inf
        pj          = -1
        ni          = -1

        # Empty the queue to start scheduling
        while(!isempty(READY_QUEUE))
            ID = dequeue!(READY_QUEUE)
            push!(ready_list, ID)
        end

        while(length(ready_list) > 0)
            ready_list = sort(ready_list, lt=(a, b) -> rank_oct[a] > rank_oct[b])
            ni = ready_list[1]
            deleteat!(ready_list, 1)

            OEFT(n, p) = EFT(n, p, aft) + oct[n][p]

            for j in 1:length(PROCESSORS)
                if OEFT(ni, j) < min_OEFT
                    min_OEFT = OEFT(ni, j)
                    pj = j
                end
            end

            @schedule now Dispatcher(ni, pj, Cost(ni), CommCost(ni, pj))
        end
        work(CLOCK_CYCLE)
    end
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
                    child_comm_cost = pw === pj ? 0 : COMMS[Edge(ni, child)]
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

function RankOCT(oct, tasks)
    ranks = Dict{Int64, Int64}()
    for (ti, _) in tasks
        ranks[ti] = sum(map(pj->oct[ti][pj], 1:length(PROCESSORS))) / length(PROCESSORS)
    end
    return ranks
end


# ----------------------------- End PEFT -----------------------------

# ----------------------------- Begin FCFS -----------------------------
@process FCFSScheduler() begin
    global SCHEDULER = "FCFSScheduler"
    processor = 0
    while(true)
        if !isempty(READY_QUEUE)
            ID            = dequeue!(READY_QUEUE)
            parents       = parentsof(ID, TASKS)
            comm_cost     = sum(map(p->COMMS[Edge(p, ID)], parents))

            @schedule now Dispatcher(ID, processor, Cost(ID), CommCost(ID, processor))
        end

        processor = processor === length(PROCESSORS) ? 1 : processor + 1

        work(CLOCK_CYCLE)
    end
end
# ----------------------------- End FCFS -----------------------------

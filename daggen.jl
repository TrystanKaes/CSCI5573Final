# CSCI5573Final/daggen.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

# This is all a bit ugly. Lets just not talk about it.
struct Edge
    ID1::Int64
    ID2::Int64
end

function ListToDictDAG(tasklist, dot_file="")
    dag = Dict{Int64,_Task}()
    comm_cost = Dict{Edge, Int64}()

    for task in tasklist[1:end-1]
        new_task = ParseTask(task)
        dag[new_task.ID] = new_task
    end

    new_task = ParseTask(tasklist[end], true)
    dag[new_task.ID] = new_task

    for (ID, _task) in dag
        for child in _task.Children
            add_dependency!(dag[child], ID)
        end
    end

    # writeDOT("pre", dag)

    # Extract edges
    for (ID, _task) in copy(dag)
        if _task.Type === :TRANSFER

            parent = _task.Dependencies[begin]
            child = _task.Children[begin]

            # Add edges. Just for giggles we do both directions
            comm_cost[Edge(parent, child)] = _task.Cost
            comm_cost[Edge(child, parent)] = _task.Cost

            # Remove edge from the parent child relationship
            filter!(e->e!==ID, dag[parent].Children)
            filter!(e->e!==ID, dag[child].Dependencies)

            # Reconnect the parent and child without edge
            push!(dag[parent].Children, child)
            push!(dag[child].Dependencies, parent)

            # Delete Edge from dag
            delete!(dag, ID)
        end
    end

    # Finally add in all of the non-comm edges
    for (ID, _task) in copy(dag)
        for child in _task.Children
            if !haskey(comm_cost, Edge(ID, child))
                comm_cost[Edge(ID, child)] = 0
                comm_cost[Edge(child, ID)] = 0
            end
        end
    end

    # writeDOT("post", dag)

    if length(dot_file) > 0
        writeDOT(dot_file, dag)
    end

    return dag, comm_cost
end


function daggen_init()
    name = "daggen"
    dir = "daggen"
    touch("daggen_init")

    init_script = """
                #!/bin/bash
                pushd $dir
                make
                mv $(name) ../dag_generator
                rm *.o
                popd"""

    open("daggen_init", "w") do file
        write(file, init_script)
    end

    chmod("daggen_init", 2000)
    run(`./daggen_init`)
    rm("daggen_init")
end

"""
- `outfile`: output file
- `n`: number of tasks
- `mindata`: minimum data size
- `maxdata`: maximum data size
- `minalpha`: minimum Amdahl's law parameter value
- `maxalpha`: maximum Amdahl's law parameter value
- `fat`: dag shape - 1.0=max parallel, 0.0=min parallel
- `density`: number of dependencies
- `regular`: regularity for num tasks per level
- `ccr`: communication(MBytes) to computation(sec) ratio
- `jump`: number of levels spanned by communications
- `dot`: output generated DAG in the DOT format
"""
function daggen(;
    outfile="", num_tasks=-1, mindata=-1, maxdata=-1, minalpha=-1, maxalpha=-1,
    fat=-1, density=-1, regular=-1, ccr=-1, jump=-1, dot=false, verbose=false)

    err = verbose ? "daggen_err.txt" : nothing

    base = `./dag_generator`
    out = (outfile == "") ? `` : ` -o $outfile`
    num = (num_tasks == -1) ? `` : ` -n $(Int64(round(num_tasks/2-sqrt(num_tasks+1))))` # Weird Stuff here
    mind = (mindata == -1) ? `` : ` --mindata $mindata`
    maxd = (maxdata == -1) ? `` : ` --maxdata $maxdata`
    mina = (minalpha == -1) ? `` : ` --minalpha $minalpha`
    maxa = (maxalpha == -1) ? `` : ` --maxalpha $maxalpha`
    fat = (fat == -1) ? `` : ` --fat $fat`
    cr = (ccr == -1) ? `` : ` --ccr $ccr`
    jmp = (jump == -1) ? `` : ` --jump $jump`
    dt = !dot ? `` : ` --dot`

    command = `$base $out $num $mind $maxd $mina $maxa $fat $cr $jmp $dt`
    daggen_init()

    buffer = IOBuffer()
    ps = run(pipeline(`$(command)`, stdout=buffer, stderr=err), wait=true)

    daggen_clean()

    # This processes the IOBuffer as a String array
    tasklist = buffer |> take! |> String |> l->split(l,"\n") |> l->deleteat!(l,[1,2,length(l)])

    num_task = tasklist[1] |> c->split(c, " ") |> n->n[2] |> i->parse(Int, i)

    deleteat!(tasklist, 1) # delete count from tasklist

    return String.(tasklist), num_task
end

function read_daggen(file)
    config = readlines(file)

    # This processes the IOBuffer as a String array
    tasklist = config |> l->deleteat!(l,[1,2])

    num_task = tasklist[1] |> c->split(c, " ") |> n->n[2] |> i->parse(Int, i)

    deleteat!(tasklist, 1) # delete count from tasklist

    return String.(tasklist), num_task
end

function daggen_clean()
    return run(`rm dag_generator`)
end

function writeDOT(Filename, dag)
    open(Filename, "w") do file
        write(file, "digraph DAG_Schedule {\n")

        for (_, task) in sort(dag) # Write self
            color = task.Type == :TRANSFER ? "grey" : "black"

            node = "  T$(task.ID) [size=\"$(task.Cost)\", "
            node *= "overhead=\"$(task.Complexity)\", "
            node *= "color=\"$(color)\"]\n"
            write(file, node)

            for ID in task.Children
                child = dag[ID]
                edge = "  T$(task.ID) -> T$(child.ID) "
                edge *= "[size=\"$(task.Cost)\", "
                edge *= "color=\"$(color)\"]\n"
                write(file, edge)
            end
        end

        write(file, "}\n")
    end
end

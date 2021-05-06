# This is all a bit ugly. Lets just not talk about it.
include("task.jl")

function ListToDictDAG(tasklist)
    dag = Dict{Int64,_Task}()
    for task in tasklist[1:end-1]
        new_task = ParseTask(task)
        dag[new_task.ID] = new_task
    end

    new_task = ParseTask(tasklist[end], true)
    dag[new_task.ID] = new_task
    dag[-1] = new_task # For Ease of peaking

    return dag
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
    run(`daggen_init`)
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
    num = (num_tasks == -1) ? `` : ` -n $num_tasks`
    mind = (mindata == -1) ? `` : ` --mindata $mindata`
    maxd = (maxdata == -1) ? `` : ` --maxdata $maxdata`
    mina = (minalpha == -1) ? `` : ` --minalpha $minalpha`
    maxa = (maxalpha == -1) ? `` : ` --maxalpha $maxalpha`
    fat = (fat == -1) ? `` : ` --fat $fat`
    cr = (ccr == -1) ? `` : ` --ccr $ccr`
    jmp = (jump == -1) ? `` : ` --jump $jump`
    dt = !dot ? `` : ` --dot`

    command = `$base $out $mind $maxd $mina $maxa $fat $cr $jmp $dt`

    daggen_init()

    buffer = IOBuffer()
    ps = run(pipeline(`$(command)`, stdout=buffer, stderr=err); wait=true)

    daggen_clean()

    # This processes the IOBuffer as a String array
    tasklist = buffer |> take! |> String |> l->split(l,"\n") |> l->deleteat!(l,[1,2,length(l)])

    num_task = tasklist[1] |> c->split(c, " ") |> n->n[2] |> i->parse(Int, i)

    deleteat!(tasklist, 1) # delete count from tasklist

    return String.(tasklist), num_task
end

function daggen_clean()
    return run(`rm dag_generator`)
end
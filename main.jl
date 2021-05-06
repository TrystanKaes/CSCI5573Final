using SimLynx
include("daggen.jl")

verbose = false
tasks = nothing


Resource()

function main()
    tasklist, num_tasks = daggen()
    tasks = ListToDictDAG(tasklist)



    return
end

main()

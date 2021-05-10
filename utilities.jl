# CSCI5573Final/utilities.jl
# Licensed under the MIT License. See LICENSE.md file in the project root for
# full license information.

function io_request(process, resource)
    request(resource)
    push!(IOBusesQueue, process) # XXX: This might run when it isn't supposed to.
end

function io_release(process, resource)
    release(resource)
    filter!(e->e!==process, IOBusesQueue)
end

function parentsof(ID, tasks)
    parents = []
    for task in collect(Int64, keys(tasks))
        if ID in tasks[task].Children
            push!(parents, task)
        end
    end
    return parents
end

function write_to_CSV(var::SimLynx.Variable, file="Statistics.csv")
    stats = var.stats
    open(file, "w") do f
        write(f, "min, max, n, mean, variance, stddev\n")
        write(f, "$(stats.min), $(stats.max), $(stats.n), $(stats.mean), $(stats.variance), $(stats.stddev)\n")
    end
end

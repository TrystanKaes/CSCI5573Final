using JSON

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

    run(`chmod +x daggen_init`)
    run(`daggen_init`)
    run(`rm daggen_init`)
end

function daggen_clean()
    return run(`rm dag_generator`)
end


function ffmpeg_subprocess(num, filename, type, width, height, contrast, brightness)
    err = verbose ? "ffmpeg_stderr[$(num)].txt" : nothing
    out = Pipe()
    ps = run(pipeline(`ffmpeg -i $(filename) -f image2pipe -vcodec rawvideo -s $(width)x$(height) -vf eq=contrast=$(contrast):brightness=$(brightness) -pix_fmt $(type) -`,
                      stdout=out, stderr=err),
             wait=false)
    json = JSON.parse(out)
    close(out)
    return json
end

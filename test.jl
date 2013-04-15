using UCB1


function test()
    arr = [ucb1record{Float64}(x) for x = 0:0.05:1.0]
    n = 0
    for i=1:10000
        r = pick1(arr,n)
        pushscore!(r,min(1.0,rand()*r.data))
        n+=1
    end
    sort((>),arr)[1:10]
end

function test2()
    np = nprocs()
    n=0
    f() = (i=n;n+=1;i)
    q = 0
    g(x)=q+=x
    @sync begin
        for p=1:np
            @async begin
                while true
                    println("begin:",p)
                    println("end:",p)
                    break
                end
            end
        end
    end
    q
end

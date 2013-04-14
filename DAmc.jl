module DAmc
using DAsimulate
using DAbase
using DAalgorithm
using UCB1

export montecarlo,montecarloP

function pickrandom(info)
    hs = validHands(playercards(info),info)
    hs==[]?PASS:hs[rand(1:end)]
end

function playout!(info::SimulateInfo,hand::Hand)
    const targetseat = info.turn
    const targetflag = 0x1 << (targetseat-1)
    #まず一手
    simulate!(info,hand)
    while info.goal&targetflag == 0
        simulate!(info,pickrandom(info))
    end
    count(info.goal)
end

function montecarlo(info::FieldInfo,mycards,rest,num)
    sinfo = SimulateInfo(info,mycards,rest)
    montecarlo(sinfo,num)
end

function montecarlo(info::SimulateInfo,num)
    arr = [ucb1record{Hand}(x) for x=[validHands(playercards(info),info),(isonset(info)?[]:PASS)]]
    targetseat = info.turn
    n = 0
    for i=1:num
        copy = deepcopy(info)
        r = pick1(arr,n)
        rank = playout!(copy,r.data)
        pushscore!(r,[0.98,0.88,0.5,0.11,0.017][rank])
        n+=1
    end
    pick1(arr,n).data
end

function montecarloP(info::FieldInfo,mycards,rest,num)
    sinfo = SimulateInfo(info,mycards,rest)
    montecarloP(sinfo,num)
end
function montecarloP(info::SimulateInfo,num)
    const N = 4

    arr = [ucb1record{Hand}(x) for x=[validHands(playercards(info),info),(isonset(info)?[]:PASS)]]
    const np = nprocs()
    targetseat = info.turn
    n=0
    next() = pick1(arr,n)
    cpy()  = deepcopy(info)
    put(r,v) = (n+=1;pushscore!(r,v))
    get() = (n,next())
    f(x) = playout!(deepcopy(info),x)
    function fN(x)
        ret = cell(N)
        for i=1:N
            rank = f(x)
            ret[i] = rank
        end
        ret
    end

    @sync begin
        for p=1:np
            if p!=myid() || np==1
                @async begin
                    #println("spawn:",p)
                    while true
                        #r = next()
                        i,r = get()
                        if i>num break end
                        #rank = remote_call_fetch(p,f,r.data)
                        ranks = remote_call_fetch(p,fN,r.data)
                        #println("consume playout at ",p," ",time())
                        #put(r,[0.98,0.88,0.5,0.11,0.017][rank])
                        #pushscore!(r,[0.98,0.88,0.5,0.11,0.017][rank])
                        for k=1:N
                            put(r,[1.0,0.88,0.5,0.11,0.0][ranks[k]])
                        end
                    end
                end
            end
        end
    end
    #d = 0
    #for r in arr d+=r.n end
    #println(d)
    pick1(arr,n).data
end

end

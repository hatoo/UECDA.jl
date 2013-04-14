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
    arr = [ucb1record{Hand}(x) for x=[validHands(playercards(info),info),(isonset(info)?[]:PASS)]]
    const np = nprocs()
    targetseat = info.turn
    n=0
    next() = pick1(arr,n)
    cpy()  = deepcopy(info)
    put(r,v) = pushscore!(r,v)
    inc() = (i=n;n+=1;i)
    @sync begin
        for p=1:np
            if p!=myid() || np==1
                @spawnat myid() begin
                    while true
                        r = next()
                        c = cpy()
                        rank = remote_call_fetch(p,(x)->playout!(c,x),r.data)
                        put(r,[0.98,0.88,0.5,0.11,0.017][rank])
                        i = inc()
                        if i>num break end
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

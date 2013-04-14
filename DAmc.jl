module DAmc
using DAsimulate
using DAbase
using DAalgorithm
using UCB1

export montecarlo

function pickrandom(info)
    hs = validHands(playercards(info),info)
    hs==[]?PASS:hs[rand(1:end)]
end

function playout!(info::SimulateInfo)
    const targetseat = info.turn
    const targetflag = 0x1 << (targetseat-1)
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
        simulate!(copy,r.data)
        rank = playout!(copy)
        pushscore!(r,[0.98,0.88,0.5,0.11,0.017][rank])
        n+=1
    end
    pick1(arr,n).data
end

end

using Daihinmin
using DAmc

randCards() = rand(Uint64)&(((JOKER<<1)-1)&(~(0xfu)))

bench()     = bench(validHands)
bench(f)    = bench(f,20000)
bench(f,t)  = @time for i=1:t f(randCards()) end

bench2() = bench2(10000)
function bench2(n)
    function takerandom(info)
        hs = validHands(playercards(info),info)
        hs==[]?PASS:hs[rand(1:end)]
    end

    @time begin
        for i=1:n
        info = rand(SimulateInfo)
        while !(simulate!(info,takerandom(info))) end
        end
    end
end

bench3()=bench3(5000)
function bench3(n)
    @time begin
        info = rand(SimulateInfo)
        montecarlo(info,n)
    end
end

bench4()=bench4(5000)
function bench4(n)
    @time begin
        info = rand(SimulateInfo)
        montecarloP(info,n)
    end
end


function test(n)
    function takerandom(info)
        hs = validHands(playercards(info),info)
        hs==[]?PASS:hs[rand(1:end)]
    end

    info = rand(SimulateInfo)
    for i=1:n
        simulate!(info,takerandom(info))
    end
    info
end


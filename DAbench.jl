require("Daihinmin")
using Daihinmin

randCards() = rand(Uint64)&((JOKER<<1)-1)

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

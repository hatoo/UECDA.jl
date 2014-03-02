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


function testFieldInfo()
    info = FieldInfo()
    info.mypos = 1
    info.turn = 1
    info.seat = [0:4]
    info.rest = [11,11,11,10,10]
    info.rank = [0:4]
    info
end

function randmycards()
    yama = shuffle!([0:52])
    t = 0u
    p = 1
    for i=1:11
        t |= 1u<<yama[i]<<4
    end
    (t,(JOKER<<1-1)&(~t)&(~(0xfu)))
end


bench3()=bench3(5000)
function bench3(n)
    info = testFieldInfo()
    mycards,rest = randmycards()
    @time begin
    montecarlo(info,mycards,rest,n)
end
end

bench4()=bench4(5000)
function bench4(n)
    info = testFieldInfo()
    mycards,rest = randmycards()
    @time begin
    montecarloP(info,mycards,rest,n)
end
end

bench5()=bench5(5000)
function bench5(n)
    info = testFieldInfo()
    mycards,rest = randmycards()
    @time begin
    for i=1:n
        sinfo = SimulateInfo(info,mycards,rest)
    end
end
end

function randtefuda()
    rand(Cards)&(1u<<56-1)&(~15)
end

function bench6(N=1000,M=1000)
    tefuda = randtefuda()
    hands = validHands(tefuda)
    algo1 = 0.0
    algo2 = 0.0
    for i=1000
        while tefuda != 0u
            hh = validHands(tefuda)
            h = hh[rand(1:end)]
            
            tefuda $= cards(h)
            j = tefuda&JOKER

            algo1 += @elapsed for i=1:M validHands(tefuda) end
            algo2 += @elapsed for i=1:M filterHands(hands,h,j!=0) end
            hands = filterHands(hands,h,j!=0)
        end
    end
    println("algo1:",algo1," ","algo2:",algo2)
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


#require("Daihinmin")
using Daihinmin
using Base.Test

function randtefuda()
    rand(Cards)&(1u<<56-1)&(~15)|JOKER
end

function check(h1,h2)
    (filter((h)->!in(h,h2),h1),filter((h)->!in(h,h1),h2))
end

function test()
    tefuda = randtefuda()
    hands = validHands(tefuda)
    while tefuda != 0u
        hh = validHands(tefuda)
        h = hh[rand(1:end)]
        #j = tefuda&JOKER
        tefuda $= cards(h)
        j = tefuda&JOKER
        
        h1 = validHands(tefuda)
        hands = filterHands(hands,h,j!=0)

        dh1,dhands = check(h1,hands)
        if !isempty(dhands) || !isempty(dh1)
            dumpCards(tefuda)
            println(h)
            println("h1")
            println(length(h1))
            println(dh1)
            println("hands")
            println(length(hands))
            println(dhands)
            break
        end
    end
end
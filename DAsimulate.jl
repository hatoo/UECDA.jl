module DAsimulate
    require("DAbase")
    require("DAalgorithm")
    using DAbase
    using DAalgorithm

    import DAalgorithm.validHands,Base.rand
    export simulate!,SimulateInfo,isonset,playercards

    type SimulateInfo
        hand::Hand
      #  onset::Bool
        lock::Bool
        rev::Bool
        turn::Uint8
        pass::Uint8
        goal::Uint8
        tefuda::Vector{Cards}
        #SimulateInfo(info::Fieldinfo) = new
        #SimulateInfo() =
    end

    macro nextturn_memo()
        #passから次のターンの人を探すための2次元配列
        inc(x) = x%5+1
        arr = zeros(Uint8,0x1f+1,5)
        for i = 0:0x1f
            for t = 1:5
                if i==0x1f
                    arr[i+1,t] = t
                else
                    x = inc(t)
                    while(i&(0x1<<(x-1)) != 0)
                        x = inc(x)
                    end
                    arr[i+1,t] = x
                end
            end
        end
        :($arr)
    end
    nextturn(pass,turn) = (@nextturn_memo)[pass+1,turn]
    isonset(info) = info.hand == PASS
    playercards(info)=info.tefuda[info.turn]

    function simulate!(info::SimulateInfo,hand::Hand)
        function renew(info)
            info.hand = PASS
            info.lock = false
            info.pass = info.goal
        end

        if hand == PASS
            info.pass |= (0x1<<(info.turn-1))
            if info.pass==0x1f
                #println("renew")
                #info.onset = true
                renew(info)
            else
                info.turn = nextturn(info.pass,info.turn)
            end
            false
        else
            #info.onset = false
            info.lock = info.lock|(suit(info.hand)==suit(hand))
            info.rev = info.rev$isrev(hand)

            t = info.tefuda[info.turn]$cards(hand)
            info.tefuda[info.turn]=t
            info.goal |= (t==0u)*(0x1<<(info.turn-1))
            if info.goal==0x1f
                #おわり
                true
            else
                cs = cards(hand)
                #ジョーカーに対してのスペ3もしくは8切りの場合強制的に流れる
                if (cs==S3&&cards(info.hand)==JOKER)|| cs&(uint64(0xf)<<(4*5))!=0
                    renew(info)
                else
                    info.hand = hand
                    info.turn = nextturn(info.pass,info.turn)
                end
                false
            end
        end
    end

    function validHands(cards::Cards,info::SimulateInfo)
        if isonset(info)
            validHands(cards)
        else
            const hand = info.hand
            if isa(hand,Stair)
                getStair(cards,qty(hand),info.lock?suit(hand):0x0,info.rev?(0:max(0,ord(hand)-1)):(min(ord(hand)+qty(hand),13):13))
            else
                if isjoker(hand)
                    if(cards&S3!=0)
                        [Group(1,0)]
                    else
                        []
                    end
                else
                   getGroup(cards,qty(hand),info.lock?suit(hand):0x0,info.rev?(0:ord(hand)-1):(ord(hand)+1:13))
                end
            end
        end
    end

    function randtefuda()
        ret = zeros(Cards,5)
        yama = shuffle!([0:52])
        p = 1
        for t in yama
            ret[p]|=(1u<<t)
            p=p%5+1
        end
        ret
    end

    function rand(::Type{SimulateInfo})
        SimulateInfo(PASS,false,false,0x1,0x0,0x0,randtefuda())
    end
end

#using DAsimulate

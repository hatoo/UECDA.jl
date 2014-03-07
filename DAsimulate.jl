module DAsimulate
    using DAbase
    using DAalgorithm

    import DAalgorithm.validHands,Base.rand
    export simulate!,SimulateInfo,isonset,playercards

    type SimulateInfo
        hand::Hand
        lock::Bool
        rev::Bool
        turn::Uint8
        pass::Uint8
        goal::Uint8
        tefuda::Vector{Cards}
        #SimulateInfo() =
    end

    function SimulateInfo(info::FieldInfo,mycards::Cards,rest::Cards)
        tefuda = Cards[]
        cs = Int[]
        rest&= ~mycards
        for i=0:60
            if (rest>>i)&0x1 != 0
                push!(cs,i)
            end
        end
        shuffle!(cs)
        for i=1:5
            t=0u
            if i==info.turn
                push!(tefuda,0u)
                continue
            end
            for k=1:info.rest[i]
                t|=1u<<pop!(cs)
            end
            push!(tefuda,t)
        end
        tefuda[info.turn] = mycards
        SimulateInfo(info.onset?PASS:info.hand,info.lock,info.rev,info.turn,info.pass,info.goal,tefuda)
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
        function renew(i::SimulateInfo)
            i.hand = PASS
            i.lock = false
            i.pass = i.goal
        end

        if hand == PASS
            info.pass |= (0x1<<(info.turn-1))
            if info.pass==0x1f
                renew(info)
            else
                info.turn = nextturn(info.pass,info.turn)
            end
            false
        else
            info.lock |= (suit(info.hand)==suit(hand))#info.lock|(suit(info.hand)==suit(hand))
            info.rev = info.rev$isrev(hand)

            t = info.tefuda[info.turn]$cards(hand)
            info.tefuda[info.turn]=t
            if t==0u
                info.goal |= (0x1<<(info.turn-1))
            end
            #info.goal |= (t==0u)*(0x1<<(info.turn-1))
            info.pass |= info.goal
            if info.goal==0x1f
                #おわり
                true
            else
                cs = cards(hand)
                #ジョーカーに対してのスペ3もしくは8切りの場合強制的に流れる
                if (cs==S3&&cards(info.hand)==JOKER)|| cs&(da"s8 d8 h8 c8")!=0
                    renew(info)
                    if t == 0u
                        info.turn = nextturn(info.pass,info.turn)
                    end
                else
                    if info.pass == 0x1f
                        renew(info)
                    else
                        info.hand = hand
                    end
                    info.turn = nextturn(info.pass,info.turn)
                end
                false
            end
        end
    end

    function validHands(cards::Cards,info::SimulateInfo,ret::Vector{Hand}=Hand[])
        validHands(cards,info.hand,info.lock,info.rev,ret)
    end

    function randtefuda()
        ret = zeros(Cards,5)
        yama = shuffle!([0:52])
        p = 1
        for t in yama
            ret[p]|=(1u<<t<<4)
            p=p%5+1
        end
        ret
    end

    function rand(::Type{SimulateInfo})
        SimulateInfo(PASS,false,false,0x1,0x0,0x0,randtefuda())
    end
end

#using DAsimulate

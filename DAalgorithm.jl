module DAalgorithm
    require("DAbase")
    using DAbase
    export getGroup,getStair,validHands


    cardsMask(range) = ((1u<<range.len*4)-1)<<(4*range.start)

    isjoker(h)=cards(h)==JOKER
    validHands(cards::Cards) = [getGroup(cards),getStair(cards)]
    function validHands(cards::Cards,info::FieldInfo)
        if info.onset
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

    #ジョーカー無しで構築可能な手にジョーカーを入れ込むような手は生成しない
    getGroup(cards::Cards) = getGroup(cards,0x0,0x0,0:13)
    function getGroup(cards::Cards,num,locksuit::Uint8,ordrange)
        ret = Hand[]
        const hasJoker = cards&JOKER != 0
        const mask=0xfu
        const isExist = cardsMask(ordrange)|cards != 0
        if !isExist
            return ret
        end
        const numMemo = Vector{Uint8}[[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
                [1,2,4,8],
                [3,5,9,6,10,12],
                [14,13,11,7],
                [15]]

        ordrange2 = contains(ordrange,13)?(ordrange.start:12):ordrange
        for ord=ordrange2
            const ordcards = mask&(cards>>(4*ord))
            if locksuit==0
                for suit=numMemo[num+1]
                    if ((ordcards&suit==suit)||((ord!=13)&&hasJoker&&(count(suit$(ordcards&suit))==1))&&count(suit)>1 )
                        hand = Group(suit,ord,suit$(ordcards&suit))#Hand(uint64(ordcards&suit)<<(4*ord),count(suit),false,ord,suit)
                        push!(ret,hand)
                    end
                end
            else
                if (locksuit&ordcards==locksuit)||(hasJoker&&count(locksuit$(locksuit&ordcards))==1&&num>1)
                    hand = Group(locksuit,ord,locksuit$(ordcards&locksuit))#Hand(uint64(ordcards&locksuit)<<(4*ord),num,false,ord,locksuit)
                    push!(ret,hand)
                end
            end
        end
        if hasJoker&&contains(ordrange,13)&&(num==1||num==0)
            push!(ret,Group(1,13,1))#Hand(0,1,false,13,0))
        end
        ret
    end

    getStair(cards::Cards) = getStair(cards,0,0x0,0:12)
    function getStair(cards::Cards,num,locksuit::Uint8,ordrange)
        ret = Hand[]
        const hasJoker = cards & JOKER != 0
        cards &= ~JOKER
        const isExist = cardsMask(ordrange)|cards != 0
        const mask = 0xfu
        if !isExist return ret end
        for suit = locksuit==0?[0x1<<x for x=0:3]:locksuit
            for low = ordrange
                Jused = false
                jo = nojokerord

                for high = low:(ordrange.start+ordrange.len-1)
                    const len = high-low+1
                    if num!=0 && len>num
                        break
                    end
                    if (cards>>(high*4))&suit == 0
                        if hasJoker&&(!Jused)
                            Jused=true
                            jo=high
                        else
                            break
                        end
                    end

                    if len >= 3&&(num==0||len==num)
                        push!(ret,Stair(suit,low,high,jo))
                    end
                end
            end
        end
        ret
    end
end

#for repl
#require("DAbase")
#using DAalgorithm
#using DAbase

require("DAbench")

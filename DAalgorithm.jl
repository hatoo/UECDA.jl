module DAalgorithm
    require("DAbase")
    using DAbase
    export getGroup,getStair,validHands


    cardsMask(range) = ((1u<<range.len*4)-1)<<(4*range.start)

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

    macro groupmemo()
                                  #mysuit locksuit num joker
        memo = Array(Vector{Uint8},16,16,5,2)
        for s = 0:15
            for lock = 0:15
                for num = 0:4
                    #no joker
                    arr = Uint8[]
                    for i=1:15
                        if (i&lock==lock)&&(i&s==i)&&(count(i)==num||num==0)&&(s!=0)
                            push!(arr,i)
                        end
                    end
                    memo[s+1,lock+1,num+1,1] = arr
                    arrj = Uint8[]
                    for i=1:15
                        if (i&lock==lock)&&((i&s==i)||(count(i)>1&&count(i&s$i)<=1))&&(count(i)==num||num==0)&&(s!=0)
                            push!(arrj,i)
                        end
                    end
                    memo[s+1,lock+1,num+1,2] = arrj
                end
            end
        end
        :($memo)
    end

    function getGroup(cards::Cards,num,locksuit::Uint8,ordrange)
        ret = Hand[]
        const hasJoker = cards&JOKER != 0
        const mask=0xfu
        const isExist = cardsMask(ordrange)|cards != 0
        const memo = @groupmemo
        if !isExist
            return ret
        end

        ordrange2 = contains(ordrange,13)?(ordrange.start:12):ordrange
        for ord=ordrange2
            mysuit = uint8(cards>>(4*ord))&0x0f
            for ss = memo[mysuit+1,locksuit+1,num+1,1+hasJoker]
                push!(ret,Group(ss,ord,ss$(mysuit&ss)))
            end
        end
        #singleJoker
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
using DAalgorithm
#using DAbase

#require("DAbench")

module DAalgorithm
    using DAbase
    export getGroup,getStair,validHands,onsetHands,filterHands


    cardsMask(range) = ((1u<<range.len*4)-1)<<(4*range.start)

    validHands(cards::Cards) = append!(getGroup(cards),getStair(cards))
    validHands(cards::Cards,hand::Pass,lock::Bool,rev::Bool) = validHands(cards)
    function validHands(cards::Cards,hand::Group,lock::Bool,rev::Bool)
        if isjoker(hand)
            if(cards&S3!=0)
                [Group(1,1)]
            else
                []
            end
        else
            getGroup(cards,hand,lock,rev)
        end
    end

    function validHands(cards::Cards,hand::Stair,lock::Bool,rev::Bool)
        getStair(cards,hand,lock,rev)
    end

    function validHands(cards::Cards,info::FieldInfo)
        if info.onset
            validHands(cards)
        else
            validHands(cards,info.hand,info.lock,info.rev)
        end
    end

    #ジョーカー無しで構築可能な手にジョーカーを入れ込むような手は生成しない

    macro groupmemo()
                                  #mysuit locksuit num joker
        const memo = Array(Vector{Uint8},16,16,5,2)
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

    macro groupmemo_onset()
        const memo = Array(Vector{Uint8},16)
        for s = 0:15
            arr = Uint[]
            if s == 0
                memo[s+1]=arr
                continue
            end
            for i = 1:15
                if (s==i)||(count(i)>1&&count(i&s$i)<=1)
                    push!(arr,i)
                end
            end
            memo[s+1]=arr
        end
        :($memo)
    end

    function getGroup(cards::Cards)
        ret = Hand[]
        const hasJoker = cards&JOKER != 0
        const memo = @groupmemo
        for ord = 1:13
            const mysuit = uint8(cards>>(4*ord))&0x0f
            for ss = memo[mysuit+1,1,1,1+hasJoker]
                push!(ret,Group(ss,ord,ss$(mysuit&ss)))
            end
        end
        if hasJoker push!(ret,SingleJoker) end
        ret
    end

    function getGroup(cards::Cards,hand::Group,lock::Bool,rev::Bool)
        ret = Hand[]
        const hasJoker = cards&JOKER == JOKER
        const ordrange = rev?(1:hand.ord-1):((hand.ord+1):13)
        const num = qty(hand)

        #場に出ている枚数が1枚のときは常にジョーカーが出せる
        if hasJoker&&num==1
            push!(ret,SingleJoker)
        end

        const isExist = cardsMask(ordrange)&cards != 0
        if !isExist
            return ret
        end

        const locksuit = lock?suit(hand):0

        const memo = @groupmemo
        for ord = ordrange
            mysuit = uint8(cards>>(4*ord))&0x0f
            for ss = memo[mysuit+1,locksuit+1,num+1,1+hasJoker]
                push!(ret,Group(ss,ord,ss$(mysuit&ss)))
            end
        end
        ret
    end

    function getGroup(cards::Cards,num,locksuit::Uint8,ordrange)
        ret = Hand[]
        const hasJoker = cards&JOKER != 0
        const isExist = cardsMask(ordrange)&cards != 0

        #singleJoker
        if hasJoker&&contains(ordrange,13)&&(num==1||num==0)
            push!(ret,Group(1,14,1))
        end

        const memo = @groupmemo
        if !isExist
            return ret
        end

        ordrange2 = contains(ordrange,14)?(ordrange.start:13):ordrange
        for ord=ordrange2
            mysuit = uint8(cards>>(4*ord))&0x0f
            for ss = memo[mysuit+1,locksuit+1,num+1,1+hasJoker]
                push!(ret,Group(ss,ord,ss$(mysuit&ss)))
            end
        end

        ret
    end

    function getGroup_onset(cards::Cards)
        ret = Hand[]
        memo = @groupmemo_onset
        const hasJoker = cards & JOKER != 0
        if hasJoker
            for ord = 1:13
                s = (cards>>4ord)&0xf
                for ss = memo[s+1]
                    push!(ret,Group(ss,ord,ss$(s&ss)))
                end
            end
            push!(ret,SingleJoker)
        else
            for ord = 1:13
                s = (cards>>4ord)&0xf
                if s!=0
                    push!(ret,Group(s,ord))
                end
            end
        end
        ret
    end

    function getStair(cards::Cards)
        ret = Hand[]
        const hasJoker = cards & JOKER != 0
        cards &= ~JOKER

        for low = 0:14
            Jused = !hasJoker
            jo = nojokerord
            for suit = [0x1<<x for x=0:3]
                for high = low:14
                    const len = high-low+1
                    if (cards>>(4high))&suit == 0
                        if !Jused
                            Jused=true
                            jo = high
                        else
                            break
                        end
                    end
                    if len >= 3
                        push!(ret,Stair(suit,low,high,jo))
                    end
                end
            end
        end
        ret
    end

    function getStair(cards::Cards,hand::Stair,lock::Bool,rev::Bool)
        ret = Stair[]
        const hasJoker = cards & JOKER != 0
        cards &= ~JOKER
        const ordrange = rev?(0:hand.low-1):(hand.high+1:14)
        const isExist = cardsMask(ordrange)&cards != 0
        if !isExist return ret end
        const num = qty(hand)
        for suit=lock?hand.suit:[0x1<<x for x=0:3]
            for low = ordrange
                Jused = !hasJoker
                jo = nojokerord
                for high = low:last(ordrange)
                    const len = high-low+1
                    if (cards>>(4high))&suit == 0
                        if !Jused
                            Jused = true
                            jo = high
                        else
                            break
                        end
                    end
                    if len == num
                        push!(ret,Stair(suit,low,high,jo))
                        break
                    end
                end
            end
        end
        ret
    end

    function onsetHands(cards::Cards)
        [getGroup_onset(cards),getStair(cards)]
    end

    function filterHands(hands::Vector{Hand},h::Hand,hasJoker::Bool)
        const c1 = cards(h)
        if hasJoker && (c1&JOKER==0)
            ret = Hand[]
            for x = hands
                c2 = cards(x)
                t = c1 & c2
                if t==0
                    push!(ret,x)
                elseif c2&JOKER==0 && count(t)==1
                    n = lowestcard(t)
                    f(g::Group)=Group(g.suit,g.ord,0x1<<(n%4))
                    f(s::Stair)=Stair(s.suit,s.low,s.high,div(n,4))
                    push!(ret,f(x))
                end
            end
            ret
        else
            p(x)=c1&cards(x)==0
            filter(p,hands)
        end
    end

    function validHands(hands::Vector{Hand},h::Hand,lock::Bool,rev::Bool)
        p(x) = (typeof(x)==typeof(h) && (!lock||suit(x)==suit(h)) && qty(x)==qty(h) && (rev$(x>h)))||(h==SingleJoker&&x==Group(1,1))
        filter(p,hands)
    end
end

#for repl
#require("DAbase")
#using DAalgorithm
#using DAbase

#require("DAbench")

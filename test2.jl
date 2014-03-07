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
function showcarray(h=STDOUT)
    #16,16,5,2
    print(h,"{")
    for i1=1:16
        print(h,"{")
        for i2=1:16
            print(h,"{")
            for i3 = 1:5
                print(h,"{")
                for i4 = 1:2
                    #print(h,(@groupmemo)[i1,i2,i3,i4],",");
                    #print(h,(@groupmemo)[i1,i2,i3,i4],",");
                    #show(h,(@groupmemo)[i1,i2,i3,i4])
                    print(h,"{")
                    for x = (@groupmemo)[i1,i2,i3,i4]
                        print(h,x,",")
                    end
                    print(h,0)
                    print(h,"},")
                end
                print(h,"},")
            end
            print(h,"},")
        end
        print(h,"},")
    end
    print(h,"}")
end
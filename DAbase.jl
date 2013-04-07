module DAbase

import Base.show , Base.isequal , Base.isless

export Cards,card,u,JOKER,S3,Hand,count,FieldInfo,singlesuit,dumpCards,useJoker

#下のビットからS3,H3,D3,C3,S4...
Cards = Uint64

const u = convert(Cards,1)
const JOKER = 1u <<(13*4)
const S3 = 1u

singlesuit(suit)=filter((x)->suit&(0x1<<x)!=0,[0:3])[1]
card(ord,suitnum)=1u<<(ord*4+suitnum)

#TODO immutable
type Hand
    cards::Cards    #ジョーカー以外のカードの集合
    qty::Uint8  #カードの枚数
    seq::Bool   #階段かどうか
    ord::Uint8  #強さ（通常時で一番弱い 3456789..2） 0から始まる ジョーカー単体は13
    suit::Uint8 #マーク 1248<->SHDCのビットフラグ
    Hand(cards,qty,seq,ord,suit)=new(cards,qty,seq,ord,suit)
    Hand() = new(0u,0,false,0,0)
    Hand(seq::Bool,ord,qty) = begin
        #for debug
        @assert qty<=4
        this=Hand()
        this.seq = seq
        this.ord = ord
        this.qty = qty
        if seq
            this.suit=0x1
            for i=1:qty
                this.cards|=card(ord+i-1,0)
            end
        else
            for i=1:qty
                this.cards|=card(ord,i-1)
                this.suit |=0x1<<(i-1)
            end
        end
        this
    end
end
useJoker(h::Hand)=h.qty!=count(h.cards)
isequal(x::Hand,y::Hand)=x.seq==y.seq&&x.ord==y.ord&&x.suit==y.suit&&x.qty==y.qty
isless(x::Hand,y::Hand)=x.seq==y.seq&&x.qty==y.qty&&x.suit==y.suit&&
    (x.seq?x.ord+x.qty-1<y.ord:x.ord<y.ord)

type FieldInfo
    onset::Bool #場にカードがない場合true
    hand::Hand  #場に出ている役
    lock::Bool  #しばり
    rev::Bool   #革命しているかどうか
    pass::Uint8    #パスしている席の集合 1==席1
    goal::Uint8    #上がった席の集合
    mynumber::Uint8 #自分のプレイヤー番号
    mypos::Uint8    #自分の席
    turn::Uint8 #どの席のターンか
    seat::Vector{Uint8} #席(1-5)->プレイヤー番号(0-4)
    rest::Vector{Uint8} #席->残り枚数
    rank::Vector{Uint8} #席->階級 0->4 小さいほど偉い
    FieldInfo()=new(true,Hand(),false,false,0,0,0,0,0,zeros(Uint8,5),zeros(Uint8,5),zeros(Uint8,5))
end

function show(io::IO,hand::Hand)
    dumpCards(io,hand.cards)
    if useJoker(hand)
        print(io,"*JOKER*")
    end
    println(io,"")
    println(io,hand.cards)
    println(io,"qty=",hand.qty)
    print(io,hand.seq?"seq ":"pair ",hand.ord," ",hand.suit)
end

function show(io::IO,info::FieldInfo)
    if info.onset
        println(io,"onset")
    else
        println(io,info.hand)
    end
    println(io,"lock=",info.lock)
    println(io,"rev=",info.rev)
    println(io,"pass=",info.pass)
    println(io,"goal=",info.goal)
end

#カードの枚数 原理不明
function count(x::Uint64)
    popcnt32(x)= begin
        x = x - (( x >> 1 ) & 0x55555555)
        x = (x & 0x33333333) + (( x >> 2) & 0x33333333)
        x = ( x + ( x >> 4 )) & 0x0F0F0F0F
        x = x + ( x >> 8 )
        x = x + ( x >> 16 )
        return x & 0x0000003F ###
    end
    popcnt32(x)+popcnt32(x>>32)
end

count(x)=count(uint64(x))

dumpCards(cards)=dumpCards(STDOUT,cards)

function dumpCards(io::IO,cards)
    strength = [3,4,5,6,7,8,9,10,11,12,13,1,2]
    for i=0:51
        if (cards&(1u<<i)) !=0
            print(io,"SHDC"[i%4+1])
            print(io,strength[1+div(i,4)]," ")
        end
    end
    if cards&JOKER != 0
        print(io,"JOKER ")
    end
end

end

module DAbase

import Base.show , Base.isequal , Base.isless

export Cards,card,u,JOKER,S3,Hand,count,FieldInfo,singlesuit,dumpCards,qty,jokerused,jokeras,cards,Group,Stair,suit,ord,numj,PASS,nojokerord,isrev,isjoker,@da_str,Pass,SingleJoker,lowestcard

#0x10のビットからS3,H3,D3,C3,S4...
#0x0~0xfは革命時のジョーカーを表現するのに使う
const Cards = Uint64

const u = convert(Cards,1)
const JOKER = 1u <<(14*4)
const S3 = u<<4

singlesuit(suit::Uint8)=count((~suit) & (suit-1))
lowestcard(card::Cards)=count((~card) & (card-1))
card(ord,suitnum)=1u<<(ord*4+suitnum)

#TODO immutable
immutable Group
    suit::Uint8
    ord::Uint8 #0=革命時のジョーカー 1=3 3456... 通常時のジョーカー=14
    jokersuit::Uint8
    Group(s,o)=new(s,o,0x00)
    Group(s,o,j)=new(s,o,j)
end
const nojokerord=0xff
immutable Stair
    suit::Uint8
    low::Uint8
    high::Uint8
    jokerord::Uint8 #0xffの時だけ特別にジョーカー不使用
    Stair(s,l,h)=new(s,l,h,nojokerord)
    Stair(s,l,h,j)=new(s,l,h,j)
end

immutable Pass
end

typealias Hand Union(Group,Stair,Pass)

const PASS = Pass()
const SingleJoker = Group(1,14,1)

isjoker(h::Hand)=cards(h)==JOKER

suit(g::Group)=g.suit
suit(s::Stair)=s.suit
suit(p::Pass) =0x00

ord(g::Group)=g.ord
ord(s::Stair)=s.low

qty(g::Group) = count(g.suit)
qty(s::Stair) = s.high-s.low+1

isrev(g::Group) = qty(g)>=4
isrev(s::Stair) = qty(s)>=5

jokerused(g::Group) = g.jokersuit!=0
jokerused(s::Stair) = s.jokerord!=nojokerord

jokeras(g::Group) = uint64(g.jokersuit)<<(4*g.ord)
jokeras(s::Stair) = (uint64(s.suit)<<(4*s.jokerord))*(s.jokerord!=nojokerord)

cards(g::Group) = (JOKER*(g.jokersuit!=0))|(uint64(g.suit$g.jokersuit)<<(g.ord*4))
cards(s::Stair) = (JOKER*(s.jokerord!=nojokerord))|((0x1111111111111111>>(4*s.low)<<(4*s.low)<<(4*(15-s.high))>>(4*(15-s.high)))*s.suit)$
                    ((s.jokerord!=nojokerord)*(uint64(s.suit)<<(s.jokerord*4)))
cards(p::Pass)   = 0u

isequal(g1::Group,g2::Group) = g1.suit==g2.suit&&g1.ord==g2.ord
isequal(s1::Stair,s2::Stair) = s1.suit==s2.suit&&s1.low==s2.low&&s1.high==s2.high

isless(g1::Group,g2::Group) = g1.ord<g2.ord
isless(s1::Stair,s2::Stair) = s1.high<s2.low&&qty(s1)==qty(s2)

function numj(g::Group)
    ret::Vector{Tuple} = []
    for i=0:3
        s = 0x1<<i;
        if g.suit&s != 0
            push!(ret,(g.ord*4+i,g.jokersuit&s!=0))
        end
    end
    ret
end

function numj(s::Stair)
    ret::Vector{Tuple} = []
    for o = s.low:s.high
        push!(ret,(o*4+singlesuit(s.suit),s.jokerord==o))
    end
    ret
end

numj(p::Pass) = []

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
    FieldInfo()=new(true,PASS,false,false,0,0,0,0,0,zeros(Uint8,5),zeros(Uint8,5),zeros(Uint8,5))
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

function popcnt32(x)
    x = x - (( x >> 1 ) & 0x55555555)
    x = (x & 0x33333333) + (( x >> 2) & 0x33333333)
    x = ( x + ( x >> 4 )) & 0x0F0F0F0F
    x = x + ( x >> 8 )
    x = x + ( x >> 16 )
    x & 0x0000003F
end

function count(x)
    count_ones(x)
end

macro memo()
    const arr = [count_ones(x) for x=0:typemax(Uint8)]
    :($arr)
end
count(x::Uint8) = (@memo)[x+1]

dumpCards(cards)=dumpCards(STDOUT,cards)

function dumpCards(io::IO,cards)
    strength = [3,4,5,6,7,8,9,10,11,12,13,1,2]
    for i=0:51
        if (cards&(1u<<(i+4))) !=0
            print(io,"SHDC"[i%4+1])
            print(io,strength[1+div(i,4)]," ")
        end
    end
    if cards&JOKER != 0
        print(io,"JOKER ")
    end
    print(io,"\n")
end

macro da_str(str)
    ret = 0u
    function f(sstr,nstr)
        s   = {"S"=>0,"H"=>1,"D"=>2,"C"=>3}[uppercase(sstr)]
        num = isdigit(nstr[1])?[12,13,1,2,3,4,5,6,7,8,9,10,11][int(nstr)]:{"J"=>9,"Q"=>10,"K"=>11,"A"=>12}[nstr]
        u<<(num*4+s)
    end
    for m in eachmatch(r"(JOKER)|([SHDC])(10|11|12|13|[0-9JQKA])",uppercase(str))
        ret |= m.match=="JOKER"?JOKER:f(m.captures[2],m.captures[3])
    end
    ret
end

end


module DAmc
using DAsimulate
using DAbase
using DAalgorithm
using UCB1

export montecarlo,montecarloP,montecarloP_alpha,montecarlo_uniform

function pickrandom(info,reserved::Vector{Hand}=Hand[])
    hs = validHands(playercards(info),info,reserved)
    #hs = isonset(info)?cache[info.turn]:validHands(cache[info.turn],info.hand,info.lock,info.rev)
    hs==[]?PASS:hs[rand(1:end)]
end

function playout!(info::SimulateInfo,hand::Hand,reserved::Vector{Hand}=Hand[])
    const targetseat = info.turn
    const targetflag = 0x1 << (targetseat-1)

    #まず一手
    simulate!(info,hand)
    #cache = [validHands(t) for t=info.tefuda]
    while info.goal&targetflag == 0
        resize!(reserved,0)
        h = pickrandom(info,reserved)#,cache)
        #if h!=PASS
        #    cache[info.turn] = filterHands(cache[info.turn],h,info.tefuda[info.turn]&JOKER!=0)
        #end
        simulate!(info,h)
    end
    count(info.goal)
end


function montecarlo(info::FieldInfo,mycards,rest,num)
    reserved = Hand[]
    sizehint(reserved,512)
    arr = [ucb1record{Hand}(x) for x=[validHands(mycards,info),(info.onset?[]:PASS)]]
    targetseat = info.turn
    n = 0
    for i=1:num
        r = pick1(arr,n)
        sinfo = SimulateInfo(info,mycards,rest)
        rank = playout!(sinfo,r.data,reserved)
        pushscore!(r,[0.98,0.88,0.5,0.11,0.017][rank])
        n+=1
    end
    pick1(arr,n).data
end

macro para(f,ps)
    :(map(fetch,map((p)->@spawnat(p,$f),$ps)))
end

function montecarloP(finfo::FieldInfo,mycards,rest,num,N=4)

    arr = [ucb1record{Hand}(x) for x=[validHands(mycards,finfo),finfo.onset?[]:PASS]]
    const np = nprocs()
    targetseat = finfo.turn
    n=0
    next() = pick1(arr,n)
    put(r,v) = (n+=1;pushscore!(r,v))
    get() = (n,next())
    f(x,m) = playout!(SimulateInfo(finfo,mycards,rest),x,m)
    function fN(x)
        ret = cell(N)
         m = Hand[]
         resize!(m,256)
        for i=1:N
            rank = f(x,m)
            ret[i] = rank
        end
        ret
    end

    @sync begin
        for p=1:np
            if p!=myid() || np==1
                @async begin
                    #println("spawn:",p)
                    while true
                        #r = next()
                        i,r = get()
                        if i>num break end
                        #rank = remote_call_fetch(p,f,r.data)
                        ranks = remotecall_fetch(p,fN,r.data)
                        #println("consume playout at ",p," ",time())
                        #put(r,[0.98,0.88,0.5,0.11,0.017][rank])
                        #pushscore!(r,[0.98,0.88,0.5,0.11,0.017][rank])
                        for k=1:N
                            put(r,[1.0,0.88,0.5,0.11,0.0][ranks[k]])
                        end
                    end
                end
            end
        end
    end
    #d = 0
    #for r in arr d+=r.n end
    #println(d)
    pick1(arr,n).data
end

function montecarloP_alpha(finfo::FieldInfo,mycards,rest,num)
    const N = nprocs()
    arr = [ucb1record{Hand}(x) for x=[validHands(mycards,finfo),finfo.onset?[]:PASS]]
end

function Chand(h::Pass)
    uint64(0)
end

function Chand(h::Group)
    ret = uint64(1)
    ret|=uint64(h.suit)<<8;
    ret|=uint64(h.ord)<<16;
    ret|=uint64(h.ord)<<24;
    ret|=uint64(h.jokersuit)<<32;
    ret
end

function Chand(h::Stair)
    ret = uint64(2)
    ret|=uint64(h.suit)<<8;
    ret|=uint64(h.low)<<16;
    ret|=uint64(h.high)<<24;
    ret|=uint64(h.jokerord)<<32;
    ret
end

function fromChand(bin::Uint64)
    const t = bin&0xff;
    if t==0 
        return PASS
    else
        suit = (bin>>8)&0xff
        low = (bin>>16)&0xff
        high = (bin>>24)&0xff
        joker = (bin>>32)&0xff
        if t == 1
            Group(suit,low,joker)
        else
            Stair(suit,low,high,joker)
        end
    end
end

#uint64_t montecarlo_uniform_foreign(uint64_t mytefuda,uint64_t rest,int32_t mypos,uint64_t ontable_bin
#            ,int32_t *tefudanums,uint8_t passflag,uint8_t goalflag,bool lock,bool rev,int32_t playoutnum);
function montecarlo_uniform(info::FieldInfo,mycards,rest,num)
    tefuda = uint64(mycards)
    restcards = uint64(rest)
    mypos = int32(info.turn-1)
    ontable_bin = info.onset?Chand(PASS) : Chand(info.hand)
    tefudanums = [int32(x) for x = info.rest]
    passflag = uint8(info.pass)
    goalflag = uint8(info.goal)
    playoutnum = int32(num)
    lock = uint8(info.lock)
    rev = uint8(info.rev)
    bin = ccall((:montecarlo_uniform_foreign,"libDA"),Uint64, (Uint64,Uint64,Int32,Uint64,Ptr{Int32},Uint8,Uint8,Uint8,Uint8,Int32)
        ,tefuda,restcards,mypos,ontable_bin,tefudanums,passflag,goalflag,lock,rev,playoutnum)
    h = fromChand(bin)
    h
end

end
module UCB1

export ucb1record,pick1,pushscore!

import Base.isless

type ucb1record{T}
    data::T
    s::Float64
    s2::Float64
    n::Uint
    cache::Float64
    ucb1record(t::T)=new(t,0.0,0.0,0,0.0)
end

function pushscore!(x,s)
    x.s += s
    x.s2+= s*s
    x.n+=1
end

var2(x::ucb1record) = if x.n==0 Inf else x.s2/x.n-(x.s*x.s)/(x.n*x.n) end

function ucb1tuned!(x,nf)
    if x.n==0
        x.cache = Inf
        return x
    end
    c1 = min(0.25,var2(x)+sqrt(2.0*log(nf)/x.n))
    v = x.s/x.n + sqrt(c1*log(nf)/x.n)
    x.cache = v
    x
end

isless(x::ucb1record,y::ucb1record) = x.cache < y.cache

function pick1(arr,n)
    map!((x)->ucb1tuned!(x,n),arr)
    max(arr)
end

end

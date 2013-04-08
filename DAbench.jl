require("Daihinmin")
using Daihinmin

randCards() = rand(Uint64)&((JOKER<<1)-1)

bench(f)    = bench(f,20000)
bench(f,t)  = @time for i=1:t f(randCards()) end

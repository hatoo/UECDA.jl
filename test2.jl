require("Daihinmin")

using Daihinmin

    macro groupmemo()
    numMemo = Vector{Uint8}[[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
                [1,2,4,8],
                [3,5,9,6,10,12],
                [14,13,11,7],
                [15]]
    memo = Vector{Vector{Uint8}}[Vector{Uint8}[filter((x)->x&s==x,numMemo[n+1]) for n = 0:4] for s = 0:0xf]
    :($memo)
    end

function popcnt32(x)
        x = x - (( x >> 1 ) & 0x55555555)
        x = (x & 0x33333333) + (( x >> 2) & 0x33333333)
        x = ( x + ( x >> 4 )) & 0x0F0F0F0F
        x = x + ( x >> 8 )
        x = x + ( x >> 16 )
        x & 0x0000003F ###
    end
function cnt(x::Uint64)

    popcnt32(x)+popcnt32(x>>32)
end

macro memo()
    arr = [popcnt32(uint32(x)) for x=0:typemax(Uint8)]
    :($arr)
end

f(x::Uint8) = (@memo)[x+1]
g(x::Uint8) = popcnt32(uint32(x))

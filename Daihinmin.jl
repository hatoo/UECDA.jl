module Daihinmin
    using DAbase
    using DAalgorithm
    using DAsimulate
    export getGroup,getStair,validHands,onsetHands,filterHands,count
    export Cards,card,u,JOKER,S3,Hand,count,FieldInfo,singlesuit,dumpCards,qty,jokerused,jokeras,cards,Group,Stair,suit,ord,numj,PASS,nojokerord,isrev,isjoker,@da_str,SingleJoker,lowestcard
    export simulate!,SimulateInfo,isonset,playercards
end

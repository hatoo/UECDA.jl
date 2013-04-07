module Daihinmin
    require("DAbase")
    require("DAalgorithm")
    using DAbase
    using DAalgorithm
    export Cards,card,u,JOKER,Hand,count,FieldInfo,singlesuit,dumpCards,useJoker,getGroup,getSeq,validHands
end

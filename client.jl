require("UECDA")
require("Daihinmin")

using UECDA
using Daihinmin

function main()
    #クライアント名,アドレス,[ポート]
    game = entryToGame("allpass","localhost")
    #game.infoに場の情報が入っています 詳しくはソース

    whole_endflag = false
    while !whole_endflag
        #交換前の手札と交換する枚数(富豪、大富豪のみ)
        cards,num = StartGame(game)
        if num != 0
            ex = 0u
            x=0
            for i=1:num
                while (cards & (1u<<x)) == 0 x+=1 end
                ex |= 1u<<x
                x+=1
            end
            SendExchangeCards(game,ex)
        end
        #println(cards," ",num)
        endflag = false
        while !endflag
            tefuda,ismyturn = ReceiveTefuda(game)

            #自分のターンの場合、手を提出する
            if ismyturn
                #println(tefuda)
                try
                hands = validHands(tefuda,game.info)
                hand  = length(hands)==0?Hand():hands[rand(1:end)]
                ret = SendHand(game,hand)
                if !ret&&hand!=Hand()
                    println(tefuda)
                    println(hand)
                    println(game.info)
                    println(UECDA.HandToTable(game,hand))
                    return
                end
                #println(ret," ",game.info.onset)
                catch x
                    print(x)
                    return
                end
            end
            status = BeGameEnd(game)
            #statuc==0 ゲーム中 ==1ゲーム一回終わり ==2全部のゲーム終わり
            endflag = status>0
            whole_endflag = status>1
        end
    end
    EndGame(game)
end

#0x0000000182040412

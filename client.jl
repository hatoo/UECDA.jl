require("UECDA")
require("Daihinmin")

using UECDA
using Daihinmin

function main()
    #クライアント名,アドレス,[ポート]
    game = entryToGame("random","localhost")
    #game.infoに場の情報が入っています 詳しくはソース

    whole_endflag = false
    while !whole_endflag
        #交換前の手札と交換する枚数(自分が富豪大富豪の場合1,2)
        cards,num = StartGame(game)
        if num != 0
            #とりあえず手札の中から弱い順に選ぶ
            #カードの集合はUint64で管理する。詳細はDAbase.jl
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
                #有効な手の中からランダムで提出する
                hands = validHands(tefuda,game.info)
                hand  = length(hands)==0?PASS:hands[rand(1:end)]
                #ret::Bool 受理したかどうか。能動的にパスした場合も不受理判定の模様
                ret = SendHand(game,hand)
                if !ret&&hand!=PASS
                    #デバッグ用 公式のJavaのサーバーは縛りがかかった状態でジョーカーを含んだグループを出すと不受理になる模様
                    #Cのサーバーは革命返しすると不受理になる模様
                    #現在詳しく調査中
                    println(tefuda)
                    println(hand)
                    println(game.info)
                    println("直前に送ったテーブル")
                    println(lastsend)
                    println("直前に受信したテーブル")
                    println(lasttable)
                    println("直前の場")
                    println(lastfield)
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

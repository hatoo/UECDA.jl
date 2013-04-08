module UECDA

export entryToGame,StartGame,SendExchangeCards,ReceiveTefuda,SendHand,BeGameEnd,EndGame,Raw

require("Daihinmin")

using Daihinmin

const protocol_ver = 20070
const DEFAULT_PORT = 42485
const Hand_Success = 9

#JuliaではCと2次元配列のメモリ配置の見かけが違うが通信時に変換することで普段は公式のドキュメントと違和感なく使えるようにしている
Table() = zeros(Int32,8,15)

type GameConnection
    socket::TcpSocket
    info::FieldInfo
end

function entryToGame(myname,addr)
    entryToGame(myname,addr,DEFAULT_PORT)
end

#return playernum
function entryToGame(myname,addr,port)
    socket = connect(TcpSocket(),addr,port)[1]
    mynumber = SendProfile(socket,myname)
    info = FieldInfo()
    info.mynumber = mynumber
    GameConnection(socket,info)
end

function StartGame(game::GameConnection)
    table = ReceiveTable(game.socket)
    (TableToCards(table),table[6,2])
end

function SendExchangeCards(game::GameConnection,cards::Cards)
    SendTable(game.socket,CardsToTable(cards))
end

function ReceiveTefuda(game::GameConnection)
    table = ReceiveTable(game.socket)
    UpdateFieldInfo(table,game.info)
    (TableToCards(table),table[6,3]==1)
end

function SendHand(game::GameConnection,hand::Hand)
    table = HandToTable(game,hand)
    SendTable(game.socket,table)
    ReceiveInt(game.socket)==Hand_Success
end

function BeGameEnd(game::GameConnection)
    table = ReceiveTable(game.socket)
    hand = TableToHand(table)
    if game.info.hand==hand
        game.info.pass |= (0x1<<(game.info.turn-1))
    end
    game.info.hand=hand
    status = ReceiveInt(game.socket)
    if status>0
        game.info.pass=0
    end
    status
end

EndGame(game::GameConnection)=close(game.socket)

function HandToTable(game::GameConnection,hand::Hand)
    table = Table()
    if hand.cards == 0
        if hand.qty==1 && hand.ord==13
            #single JOKER
            #一番いいジョーカー
            table[singlesuit(game.info.hand.suit)+1,game.info.rev?1:15 ]=2
            return  table
        else
            #pass
            return table
        end
    end
    if hand.seq
        ord = hand.ord
        const suitnum = singlesuit(hand.suit)
        for i=1:hand.qty
            table[suitnum+1,ord+2]=(hand.cards&card(ord,suitnum))==0?2:1
            ord += 1
        end
    else
        const ord = hand.ord
        const suit = hand.suit
        for i=0:3
            if (suit&(0x1<<i))!=0
                table[i+1,ord+2]=(hand.cards&card(ord,i))==0?2:1
            end
        end
    end
    table
end

function TableToHand(table)
    hand = Hand()
    #カードのある位置を探す
    s=1
    n=1
    while n<=15&&(table[s,n]==0)
        s+=1
        if s==5
            n+=1
            s=1
        end
    end
    if n==16 return hand end
    c(n,s) = card(n-2,s-1)
    hand.seq = n<15&&(table[s,n+1]!=0)
    hand.ord = n-2
    if hand.seq
        q=0
        while n<15&&(table[s,n]!=0)
            if table[s,n]==1
                hand.cards|=c(n,s)
            end
            q+=1
            n+=1
        end
        hand.qty=q
        hand.suit = 1u<<(s-1)
    else
        q=0
        for i=0:3
            if table[i+1,n]!=0
                if table[i+1,n]==1
                    hand.cards|=c(n,i+1)
                end
                q+=1
                hand.suit|=0x1<<i
            end
        end
        hand.qty=q
        if q==1&&table[s,n]==2
            hand.cards = 0
            hand.ord = 13
        end
    end
    hand
end

function SendProfile(socket,myname)
    table = Table()
    table[1,1] = protocol_ver
    count = 1
    for c in myname
        table[2,count] = c
        count+=1
    end
    #println(table)
    SendTable(socket,table)
    start_reading(socket) #これを入れるとなぜか動く
    ReceiveInt(socket)
end

#ゲーム開始のカード交換に使う
function CardsToTable(cards::Cards)
    table = Table()
    for i=0:51
        if (1u<<i)&cards != 0
            suit = i%4
            num  = div(i,4)+1
            table[suit+1,num+1] = 1
        end
    end
    #カードの交換でジョーカーを出すことはまずありえないが・・・
    if cards&JOKER != 0
        #どうやら未定義(?)のようなのでエラーを吐く
        throw("exchange JOKER is undefined")
    end
    table
end

#バイトオーダの変換 自分がリトルエンディアンだと決め打っている
function htonl(hostlong::Uint32)
    ret = convert(Uint32,0)
    const mask = 0x000000FF
    for i = 0:3
        ret += ((mask<<i*8)&hostlong)>>(i*8)<<((3-i)*8)
    end
    ret
end

ntohl = htonl

function SendTable(socket,table)
    netdata = transpose(map(htonl,convert(Array{Uint32,2},table)))
    write(socket,netdata)
end


function ReceiveTable(socket)
    #start_reading(socket)
    buf = zeros(Uint32,15,8)
    read(socket,buf)
    transpose(map((x)->convert(Int32,x),map(ntohl,buf)))
end

function ReceiveInt(socket)
    buf = zeros(Uint32,1)
    convert(Int32,ntohl(read(socket,buf)[1]))
end

function TableToCards(table)
    cards = 0u
    for suit=0:3
        for num = 0:12
            if table[suit+1,num+2]==1
                cards = cards | (1u<<(4num+suit))
            end
        end
    end
    if table[5,2]==2
        cards=cards|JOKER
    end
    cards
end

#通信6 場の情報をテーブルから得る
function UpdateFieldInfo(table,info::FieldInfo)
    info.onset  = table[6,5]
    if info.onset
        info.pass=0
    end
    info.lock   = table[6,8]
    info.rev    = table[6,7]
    #println(table)
    for i=1:5
        p=table[7,10+i]
        info.seat[i]=p
        if p == info.mynumber
            info.mypos = p
        end
    end
    #println(info.seat)
    PtoS(p)=begin
        for i=1:5 if info.seat[i]==p return i end end
        throw("error")
    end
    info.goal=0
    for i=1:5
        s = PtoS(i-1)
        info.rest[s] = table[7,i]
        info.rank[s] = table[7,i+5]
        if info.rest[s]==0
            info.goal|=(1<<(s-1))
        end
    end
    info.turn = PtoS(table[6,4])
end

end

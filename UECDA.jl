module UECDA

export entryToGame,StartGame,SendExchangeCards,ReceiveTefuda,SendHand,BeGameEnd,EndGame,lasttable,lastfield,lastsend

using Daihinmin

const protocol_ver = 20070
const DEFAULT_PORT = 42485
const Hand_Success = 9

#JuliaではCと2次元配列のメモリ配置の見かけが違うが通信時に変換することで普段は公式のドキュメントと違和感なく使えるようにしている
Table() = zeros(Int32,8,15)
#最後に受信したテーブル
global lasttable = Table()
global lastfield = Table()
global lastsend  = Table()

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
    lasttable = table
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
    global lastfield = copy(table)
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
    if cards(hand)==JOKER
        #single JOKER
        #一番いいジョーカー
        s = suit(game.info.hand)
        table[s==0?1:(singlesuit(s)+1),game.info.rev?1:15 ]=2
        return  table
    end
    if hand == PASS
       #pass
       return table
    end

    for (n,j) in numj(hand)
        table[n%4+1,div(n,4)+1]=j?2:1
    end
    table
end

function TableToHand(table)
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
    if n==16 return PASS end
    c(n,s) = card(n-2,s-1)
    isseq = n<15&&(table[s,n+1]!=0)
    if isseq
        const ss = 0x1<<(s-1)
        const low = n-1
        jokerord = nojokerord
        high = low
        while (high+1)<=15&&(table[s,high+1]!=0)
            if table[s,high+1]==2 jokerord=high end
            high+=1
        end
        high-=1
        Stair(ss,low,high,jokerord)
    else
        const o = n-1
        jokersuit = 0
        ss=0
        for i = 0:3
            if table[i+1,n]!=0
                ss|=(1<<i)
                if table[i+1,n]==2
                    jokersuit=1<<i
                end
            end
        end
        Group(ss,o,jokersuit)
    end
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
            num  = div(i,4)
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
    global lastsend = copy(table)
    netdata = transpose(map(htonl,convert(Array{Uint32,2},table)))
    write(socket,netdata)
end


function ReceiveTable(socket)
    #start_reading(socket)
    buf = zeros(Uint32,15,8)
    read(socket,buf)
    ret = transpose(map((x)->convert(Int32,x),map(ntohl,buf)))
    global lasttable = copy(ret)
    ret
end

function ReceiveInt(socket)
    buf = zeros(Uint32,1)
    convert(Int32,ntohl(read(socket,buf)[1]))
end

function TableToCards(table)
    cards = 0u
    for suit=0:3
        for num = 1:13
            if table[suit+1,num+1]==1
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

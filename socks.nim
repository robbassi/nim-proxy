from strutils import repeat
import sockets

type SocksRequest* = object
  client*: Socket
  destaddr*: string
  destport*: Port

proc toInt16(s: seq[int]): int16 =
  var port = 0'i16
  port = port or int16(s[1])
  port = port shl 8
  port = port or int16(s[0])
  return ntohs port

proc bytes(s: string): seq[int] =
  var bytes: seq[int] = @[]
  for c in s:
    bytes.add ord c
  return bytes

proc readByte(s: Socket): int =
  var
    req = ""
    len = s.recv(req, 1)
  if len == 1:
    return ord req[0]
  else:
    return -1

proc readVersion*(s: Socket): int =
  return s.readByte

proc readMethods*(s: Socket): seq[int] =
  var
    methods: seq[int] = @[]
    count = s.readByte - 1
  for i in 0..count:
    methods.add s.readByte
  return methods

proc readDestAddress*(s: Socket): string =
  var
    req = ""
    len = s.recv(req, 4)
  if len == 4:
    if (ord req[3]) == 3:
      let
        addrLen = s.readByte
      var domain = ""
      discard s.recv(domain, addrLen)
      return domain
  return ""

proc readDestPort*(s: Socket): Port =
  var
    port = ""
    len = s.recv(port, 2)
  if len == 2:
    var b = bytes port
    return Port toInt16 b
  return Port 0

proc socks5_auth*(client: Socket): bool =
  if client.readVersion != 5:
    return false

  if not 0 in client.readMethods:
    return false

  client.send ($chr(5) & $chr(0))
  return true

proc socks5_req*(client: Socket): SocksRequest =
  let
    destaddr = client.readDestAddress
    destport = client.readDestPort

  client.send ($chr(5) & $chr(0).repeat(2) & $chr(1) & $chr(0).repeat(6))
  return SocksRequest(client: client, destaddr: destaddr, destport: destport)

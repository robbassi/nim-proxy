from strutils import repeat
import sockets

type
  SocksVersion* = enum
    Socks4 = 4
    Socks5 = 5
  SocksAuthMethod* = enum
    None
    GssApi
    UserPass
    Invalid = 0xFF
  SocksCommand* = enum
    Connect
    Bind
    UdpAssociate
  SocksAddrType* = enum
    IPv4 = 0x01
    Domain = 0x03
    IPv6 = 0x04
  SocksResponseCode* = enum
    Ok
    Fail
    Forbidden
    NetworkUnreachable
    HostUnreachable
    ConnectionRefused
    TtlExpired
    BadCommand
    BadAddress
  SocksAuthRequest* = object
    client*: Socket
    version*: SocksVersion
  SocksProxyRequest* = object
    client*: Socket
    destaddr*: string
    destport*: Port
  SocksException = object of Exception
  SocksParseError* = object of SocksException

template intConverter(name: expr): expr =
  converter `to name`(i: int): `name` =
    try: return `name` i
    except: raise newException(SocksParseError, "Invalid `name`")

intConverter SocksVersion
intConverter SocksAuthMethod
intConverter SocksAddrType

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
    buff = ""
    len = s.recv(buff, 1)
  if len == 1:
    return ord buff[0]
  else:
    return -1

proc readString(s: Socket, n: int): string =
  var
    buff = ""
    len = s.recv(buff, n)
  if len == n:
    return buff
  else:
    return ""

proc readBytes(s: Socket, n: int): seq[int] = bytes s.readString n

proc readVersion(s: Socket): SocksVersion = s.readByte.toSocksVersion

proc readMethods(s: Socket): seq[SocksAuthMethod] =
  var
    methods: seq[SocksAuthMethod] = @[]
    count = s.readByte - 1
  for i in 0..count:
    methods.add s.readByte.toSocksAuthMethod
  return methods

proc readDestAddress(s: Socket): string =
  var
    buff = s.readBytes 4
    len = len buff
  if len == 4:
    let addrType = SocksAddrType ord buff[3]
    if addrType == SocksAddrType.Domain:
      let
        addrLen = s.readByte
        domain = s.readString addrLen
      return domain
  raise newException(SocksParseError, "Invalid address")

proc readDestPort(s: Socket): Port =
  var
    port = s.readBytes 2
    len = len port
  if len == 2:
    return Port toInt16 port
  raise newException(SocksParseError, "Invalid port")

proc socks5_auth*(client: Socket): bool =
  if client.readVersion != 5:
    return false
  if not (None in client.readMethods):
    return false
  client.send ($chr(5) & $chr(0))
  return true

proc socks5_req*(client: Socket): SocksProxyRequest =
  let
    destaddr = client.readDestAddress
    destport = client.readDestPort
  client.send ($chr(5) & $chr(0).repeat(2) & $chr(1) & $chr(0).repeat(6))
  return SocksProxyRequest(client: client, destaddr: destaddr, destport: destport)

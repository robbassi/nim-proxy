from os import sleep
import sockets, selectors, parseutils, socks

proc pipe(a, b: Socket): bool =
  var
    req = ""
    len = a.recvAsync(req, 20000)
  if len > 0:
    var sent = b.sendAsync req
    while sent < len:
      sent += b.sendAsync req[sent..len]
  else:
    return false
  return true

proc proxy*(req: SocksRequest) =
  var
    destsock = socket()
    selector = newSelector()
    events = {EvRead}
    sourceKey, destKey: SelectorKey
  destsock.connect req.destaddr, req.destport
  sourceKey = selector.register(req.client.getFD, events, nil)
  destKey = selector.register(destsock.getFD, events, nil)

  req.client.setBlocking false
  destsock.setBlocking false

  block pump:
    while true:
      var info = selector.select(-1)
      for ready in info:
        if ready.key == sourceKey and EvRead in ready.events:
          if not pipe(req.client, destsock):
            break pump
        elif ready.key == destKey and EvRead in ready.events:
          if not pipe(destsock, req.client):
            break pump
      sleep 1

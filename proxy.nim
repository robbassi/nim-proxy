from os import sleep
from posix import usleep
import sockets, selectors, parseutils, socks

proc pipe(a, b: Socket): bool =
  var
    buff = ""
    len = a.recvAsync(buff, 20000)
  if len > 0:
    var sent = b.sendAsync buff
    while sent < len:
      sent += b.sendAsync buff[sent..len]
  else:
    return false
  return true

proc proxy*(req: SocksRequest) =
  var
    destsock = socket()
    selector = newSelector()
    events = {EvRead}
    sourceKey: SelectorKey
  sourceKey = selector.register(req.client.getFD, events, nil)
  selector.register(destsock.getFD, events, nil)
  destsock.connect req.destaddr, req.destport

  # make sure sockets are non-blocking
  req.client.setBlocking false
  destsock.setBlocking false
  block pump:
    while true:
      var info = selector.select(-1)
      for ready in info:
        if EvRead in ready.events:
          if ready.key == sourceKey:
            if not pipe(req.client, destsock):
              break pump
          elif not pipe(destsock, req.client):
              break pump
      # sleep for a short time to avoid high cpu for streaming connections
      discard usleep 200

import sockets, socks, proxy, posix

const port = Port 1080
var s = socket()

proc handle_req(client: Socket): bool =
  if socks5_auth client:
    var req = socks5_req client
    echo "connecting to ", req.destaddr
    proxy(req)

s.setSockOpt OptReuseAddr, true
s.bindAddr port, "localhost"
s.listen

# ignore child process signals
signal SIGCHLD, SIG_IGN

while true:
  echo "listening..."
  let client = s.accept
  echo "incoming req..."
  if fork() == 0:
    discard handle_req(client)
    break
  else:
    client.close

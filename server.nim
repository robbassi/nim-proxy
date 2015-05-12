import sockets, socks, proxy, posix

const port = Port 1080
var s = socket()

# ignore child process signals
signal SIGCHLD, SIG_IGN

s.setSockOpt OptReuseAddr, true
s.bindAddr port, "localhost"
s.listen

while true:
  let client = s.accept
  if fork() == 0:
    try:
      if socks5_auth client:
        var req = socks5_req client
        echo "connecting to ", req.destaddr
        proxy(req)
        echo "closed connection to ", req.destaddr
      else:
        echo "auth failed"
    except SocksParseError:
      echo "error reading packet: ", getCurrentExceptionMsg()
    finally:
      break
  else:
    client.close

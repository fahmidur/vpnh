# vpn-helper

vpn-helper is a wrapper/daemon around openvpn.

## Commands

*  vpn-helper install [config.json]

install the vpn-helper systemctl service if it is not already installed.


* vpn-helper status

output status of vpn-helper. 
- is it installed?
- is the daemon running?
- is tun0 up?

* vpn-helper start

start the daemon.

* vpn-helper stop

stop the daemon.

* vpn-helper daemon 

run the vpn-helper as a daemon

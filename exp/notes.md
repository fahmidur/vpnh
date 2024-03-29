# Notes

The notes below are mostly scrap. Below I have collected
a number of sources and detailed frustrations on the way to
getting this script to work.

## Sources and History

This was the first useful article discovered on split-tunneling:

https://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/

Above article describes how to mark packets for the vpnuser using ip_tables and then handle those packets separately using `ip route` and `ip rule`

https://serverfault.com/questions/769673/traffic-refuses-to-go-over-vpn-interface

Above article describes how to create an independent tun0 vpn interface and create `ip route` rules to properly route the interface.
Using above answer, `curl --interface tun0 ifconfig.me` works as expected.

Most importantly we use route-nopull in the openvpn script to apply any route changes and we use our own vpnup script to do everything else described in the article.

At this point `curl --interface tun0 ifconfig.me` should work and send back a different external ip address compared to a `curl --interface eth0`

At this point we still do not have a way to create a vpnuser whose traffic always goes through tun0. 

---

https://haasn.xyz/posts/2017-05-09-jailing-specific-processes-inside-a-vpn.html

at last we have a working solution involving:
```
ip rule add uidrange 1001-1001 table vpntable
```

the only caveat is that the uidrange option requires
linux kernel 4.10 or higher.

to prevent vpnuser from accessing eth0 or some other interface when
tun0 disconnects we add the following iptable rule:
```
iptables -A OUTPUT -o eth0 -m owner --uid-owner vpnuser -j REJECT
```

this prevents vpnuser from ever accessing eth0, meaning the tun0 vpn interface must be up for vpnuser to do anything, this is exactly what we want.


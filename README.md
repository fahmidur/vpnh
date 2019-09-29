# vpn-helper

vpn-helper is a wrapper/daemon around openvpn.

## Commands

## Notes

This was the first useful article discovered on split-tunneling:

https://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/

Above article describes how to mark packets for the vpnuser using ip_tables and then handle those packets separately using `ip route` and `ip rule`

https://serverfault.com/questions/769673/traffic-refuses-to-go-over-vpn-interface

Above article describes how to create an independent tun0 vpn interface and create `ip route` rules to properly route the interface.
Using above answer, `curl --interface tun0 ifconfig.me` works as expected.

Most importantly we use route-nopull in the openvpn script to apply any route changes and we use our own vpnup script to do everything else described in the article.

At this point `curl --interface tun0 ifconfig.me` should work and send back a different external ip address compared to a `curl --interface eth0`

At this point we still do not have a way to create a vpnuser whose traffic always goes through tun0. 

# vpn-helper

vpn-helper is a wrapper/daemon around openvpn.

## Commands

## Notes

https://www.niftiestsoftware.com/2011/08/28/making-all-network-traffic-for-a-linux-user-use-a-specific-network-interface/

Above describes how to mark packets for the vpnuser using ip_tables and then handle those packets separately using `ip route` and `ip rule`

https://serverfault.com/questions/769673/traffic-refuses-to-go-over-vpn-interface

Above describes how to create an independent tun0 vpn interface and create `ip route` rules to properly route the interface.
Using above answer, `curl --interface tun0 ifconfig.me` works as expected.


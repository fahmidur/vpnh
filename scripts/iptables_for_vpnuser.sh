#! /bin/bash

export INTERFACE="tun0"
export VPNUSER="vpnuser"
export LANIP="192.168.1.0/24"
export NETIF="eth0"

iptables -F -t nat
iptables -F -t mangle
iptables -F -t filter

# mark packets from $VPNUSER
iptables -t mangle -A OUTPUT ! --dest $LANIP -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LANIP -p udp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT --dest $LANIP -p tcp --dport 53 -m owner --uid-owner $VPNUSER -j MARK --set-mark 0x1
iptables -t mangle -A OUTPUT ! --src $LANIP -j MARK --set-mark 0x1

# allow responses
iptables -A INPUT -i $INTERFACE -m conntrack --ctstate ESTABLISHED -j ACCEPT

# allow bittorrent
iptables -A INPUT -i $INTERFACE -p tcp --dport 59560 -j ACCEPT
iptables -A INPUT -i $INTERFACE -p tcp --dport 6443 -j ACCEPT

iptables -A INPUT -i $INTERFACE -p udp --dport 8881 -j ACCEPT
iptables -A INPUT -i $INTERFACE -p udp --dport 7881 -j ACCEPT

# block everything incoming on $INTERFACE
iptables -A INPUT -i $INTERFACE -j REJECT

# send DNS to google for $VPNUSER
iptables -t nat -A OUTPUT --dest $LANIP -p udp --dport 53  -m owner --uid-owner $VPNUSER  -j DNAT --to-destination 8.8.4.4
iptables -t nat -A OUTPUT --dest $LANIP -p tcp --dport 53  -m owner --uid-owner $VPNUSER  -j DNAT --to-destination 8.8.8.8

# let $VPNUSER access lo and $INTERFACE
iptables -A OUTPUT -o lo -m owner --uid-owner $VPNUSER -j ACCEPT
iptables -A OUTPUT -o $INTERFACE -m owner --uid-owner $VPNUSER -j ACCEPT

# all packets on $INTERFACE needs to be masqueraded
iptables -t nat -A POSTROUTING -o $INTERFACE -j MASQUERADE

# reject connections from predator ip going over $NETIF
iptables -A OUTPUT ! --src $LANIP -o $NETIF -j REJECT

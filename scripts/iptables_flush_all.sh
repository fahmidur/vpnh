#!/usr/bin/env sh

sudo iptables -F
sudo iptables -F -t nat
sudo iptables -F -t mangle
sudo iptables -F -t filter

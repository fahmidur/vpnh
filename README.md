# VPNH - A VPN Split-Tunnel Helper

```plaintext
                      ___________
                     / ________>>
_____   ______  ____ | |__
>>__ \ /    _ \|  _ \|  _ \
    \ V /| |_)   | |   | | |
     \_/ |  __/|_| |_|_| | |_____
         |_|             \_____>>
   

```

VPNH is a daemon to help you do VPN [**split-tunneling**](https://en.wikipedia.org/wiki/Split_tunneling) on Linux/Ubuntu. 
It uses the OpenVPN client, sets up routing rules, and keeps the connection alive.

With VPNH you can add a number of OpenVPN config files and connect to any one of them. 
The config file will be modifed to ensure that it does not put your entire machine under the VPN. 
Upon connection VPNH will create a user named `vpnh_user` and set up all of the routing rules
to ensure that only that user is under the VPN.
Once connected VPNH will ensure that you remain connected.

The name of `vpnh_user` and other settings are configurable via the `vpnh config ...` set of commands.

The `vpnh_user` is intentionally created such that when the VPN is disconnected/down, this user has no access to the real interface, 
and therefore no access to the internet.
This is to prevent any accidental leaks from programs you may be running under the vpnh user.

The idea is that you're running some program that should never access the
internet outside of the protection of the VPN.
That is what VPNH tries to ensure.

**WARNING**: This project is a work in progress, while it does work,
the documentation is incomplete, the commands are subject to change, tests need to be written, and much more. Please use at your own discretion.

## Requirements
* Linux Kernel >= [4.10](https://kernelnewbies.org/Linux_4.10)
* Ubuntu >= 18.04
* Ruby

## Installation

Installation is simple, clone this to where
you normally keep your repos. 

```
cd ~/data/repos
git clone git@github.com:fahmidur/vpnh.git
```

And run:

```
sudo make install
```

This will install VPNH to `/opt/vpnh`, create the daemon, and setup the routing rules.

## What is split-tunneling?

Split-tunneling lets you route some traffic through the vpn
and other traffic through your regular interface.
There are many cases where having some programs under the vpn
and some outside the vpn proves to be very useful.

In example, one might want their BitTorrent client to be under the
VPN while allowing some media-server program like [Plex](https://plex.tv) or [Fezly](https://fezly.co) to be on the regular network. 
This allows your torrent traffic to be hidden from the prying eyes of your ISP and 
still lets you consume the downloaded content locally within your network. 
When media-server programs like Plex or Fezly are able to connect to your local network, you are able to reach your content directly
without the involvement of proxy servers.

## Usage

The usage is broken down into a number of sections.
All commands below are expected to be run as root.

### Configuring

Show current configuration:
```
vpnh config
```

Set a configuration value:
```
vpnh config set <name> <value>
```

Get a configuration value:
```
vpnh config get <name>
```

Please ensure that `vpnh config show` has the correct *real_iface* value.
If not please set *real_iface* to the correct interface name
for your real default interface.

In example, this sets the real_iface to eth0:
```
vpnh config set real_iface eth0
```

### Manage User-Pass Pairs -- "auths"

Show all auths known to vpnh:
```
vpnh auths
```

Add an auth:
```
vpnh auths add <name> <user> <pass>
```

Delete an auth:
```
vpnh auths del <name>
```

Delete all auths:
```
vpnh auths flush
```

### Manage OpenVPN Config Files -- "ovpns"

Show all ovpns known to vpnh:
```
vpnh ovpns
```

Add an OpenVPN config file without any auth:
(variant-1)
```
vpnh ovpns add <name> <path/to/openvpn-config-file.ovpn>
```

Add an OpenVPN config file with an auth:
(variant-2)
```
vpnh ovpns add name=<name> auth=<name_of_auth> <path/to/openvpn-config-file.ovpn>
```

Delete an OpenVPN config file:
```
vpnh ovpns del <name>
```

Delete all OpenVPN config files:
```
vpnh ovpns flush
```

### Before Connecting

If your VPN provider requires you to login, you must create an auth
and add your ovpn file using variant-2 of the `vpnh ovpns add ...`
command.

Some VPN providers like AirVPN give you an ovpn file containing a key which does not require you to login, in which case
simply add the ovpn using the smaller variant-1 of the `vpnh ovpns add ...` command.

### Connecting / Disconnecting / Status

Once your ovpns and auths are properly setup.

Connect with:
```
vpnh connect <name_of_ovpn>
```

Disconnect with:
```
vpnh disconnect
```

Check the status of your connection with:
```
vpnh status
```

## Leaks

Testing for leaks is very important.

The website [ipleak.net](https://ipleak.net) is useful for testing leaks. 
You can also get some results via:
```
curl ipleak.net/json/
```
### DNS Leaks

Ensure that you are making DNS requests through the VPN interface
and not through some local server. A local DNS server running
as non-vpn-user may then make DNS requests through your real
interface, resulting in a DNS leak.

Set your DNS server to something public like Google's
8.8.8.8 / 8.8.4.4 or Cloudflare's 1.1.1.1. 
You can also use whatever DNS server is preferred by your VPN provider.

Use this to see which DNS server you are using:
```
dig <any_public_domain>
```
and
```
cat /etc/resolv.conf
```

You may use the following to see which interface your DNS request goes through.
```
ip route get <dns_server_ip>
```
and
```
traceroute <dns_server_ip>
```

### IPv6 Leaks

Many VPN providers do not properly handle IPv6 which can result in
leaks. 

In most cases it is recommended to disable IPv6 entirely with:
```
sysctl -w net.ipv6.conf.all.disable_ipv6=1
```

## Recommended VPN Providers

There are many good VPN providers. 
I have tried the following popular offerings:

* NordVPN -- Plenty of servers but no Port Forwarding option.
* ExpressVPN -- Pretty fast and reliable but no Port Forwarding option.
* AirVPN -- Good, fast, and great Port Fowarding option.

I recommend AirVPN thus far primarily because they offer Port Forwarding.

Why is Port Forwarding important? If you are for example running a BitTorrent
client, without an open port other peers cannot easily connect to you.
Not having an open port greatly limits the number of peers to which you can connect.

With Port Forwarding you can host a server, host a LAN party, and many other things.

## Debugging

The installation script creates a Systemd service named `vpnh`.

To view daemon status, run:
```
systemctl status vpnh
```

To watch the logs, run:
```
journalctl -fu vpnh
```

See systemctl and journalctl usage for more information.

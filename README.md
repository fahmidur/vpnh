# vpnh - A VPN Helper

This is a daemon to help you do vpn _split-tunneling_ on Linux/Ubuntu. 
It is primarily a wrapper around the OpenVPN client.

With vpnh you can add a number of openvpn config files and connect to any of them. 
The config file will be modifed to ensure that it does not put your entire machine under the vpn. 
Upon connection vpnh will create a user named `vpnh_user` and set up all of the routing rules
to ensure that only that user is under the VPN.
Once connected vpnh will ensure that you remain connected.

The name of vpnh_user and other settings are configurable via the `vpnh config ...` set of commands.

## Requirements
* Linux Kernel >= 4.10
* Ubuntu >= 18.04

## Installation

```
sudo make install
```

## What is split-tunneling?

Split-tunneling lets you route some traffic through the vpn
and other traffic through your regular interface.
There are many cases where having some programs under the vpn
and some outside the vpn proves to be very useful.

In example, one might want their BitTorrent client to be under the
VPN while allowing some media-server program like Plex to be on their regular network. 
This allows your torrent traffic to hidden from the prying eyes of your ISP/government and still lets you consume the download content locally within your network. 
When a media-server program like Plex is able to connect to your local network, you are able to reach your content directly. 
For video-content this often means a better viewing experience.

## Usage

### Configuring

Show current configuration:
```
vpnh config show
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
vpnh auths show
```

Add an auth:
```
vpnh auths add <name> <user> <pass>
```

Delete an auth:
```
vpnh auths del <name>
```

### Manage OpenVPN Config Files -- "ovpns"

Show all ovpns known to vpnh:
```
vpnh ovpns show
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

Some VPN providers like AirVPN give you a ovpn file containing a key which does not require
you to login, in which case, 
simply add the ovpn using the smaller variant-1 of the `vpnh ovpns add ...` command.

### Connecting / Disconnecting / Status

Once your ovpns and auths are properly setup.

Connect with:
`vpnh connect <name_of_ovpn>`

Disconnect with:
`vpnh disconnect <name_of_ovpn>`

Check the status of your connection with:
`vpnh status`

## Debugging

The install script installed a systemd service named `vpnh`.

Get daemon status:
`systemctl status vpnh`

Watch the logs:
`journalctl -fu vpnh`

See systemctl and journalctl usage for more information.

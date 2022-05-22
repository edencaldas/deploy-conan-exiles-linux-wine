# deploy-conan-exiles-linux-wine
Simple (just works) script to install Conan Exiles with wine on a Linux container / VM / Baremetal

This script can be ran as-is in:
- Virtual Machines
- LXC Containers
- Baremetal

You will end up with a functional Conan Exiles Dedicate Server running on Linux with Wine.

## Motivation for creating these scripts

I could not find a reliable Docker image for conan Exiles, or create one myself. I would always run into either the server not advertising to Funcom servers, or connections that require certificates would loop endelessly. Docker might be messing too much with the network stack for its containers, as the exact same setup works everywhere else. Regardless, LXC is a much beter fit for Conan Exiles. Whereas Dockers is made for app containerzation, LXC is made for full-blown VM-like containers. It's a perfect match for Conan Exiles.

Since the scripts work with LXC, they also do for VMs and baremetal machines.

## Usage

Download one of the ```deploy_conan_exiles_*.sh``` files appropriate to your linux distribution.
Login to your VM/Container/Machine and execute the script as root.
Alternatively, if using Cloud (eg: AWS) you can put the script in your instance's userdata.
For LXC, you can use cloud-init. Or you can just login as root ( ```lxc exec yourcontainer -- bash``` ) and execute the script.

## The script will:

- Install all required and usefl packages.
- Download mcrcon and discord.sh for server management and discord messages.
- Install steamcmd and download conan exiles with it.
- Setup a systemd unit file called ```conan``` and start it.
- Create a readme file with further instructions.

## Installation Example

```
[ec2-user@host ~]$ lxc launch images:almalinux/8 almalinux
Creating almalinux
Starting almalinux                        
[ec2-user@host ~]$ lxc exec almalinux -- bash
[root@almalinux ~]# curl -sSOJ https://raw.githubusercontent.com/edencaldas/deploy-conan-exiles-linux-wine/main/deploy_conan_exiles_enterpriselinux8_wine.sh
[root@almalinux ~]# chmod +x deploy_conan_exiles_enterpriselinux8_wine.sh
[root@almalinux ~]# ./deploy_conan_exiles_enterpriselinux8_wine.sh 
```

After the process is done. Login as ```steam``` user and wait for the ```LogServerStats: Sending report: exiles-stats?``` message to appear. That will mean the server is up and advertising to the Funcom server browser.

```
[root@almalinux ~]# sudo -iu steam
[steam@almalinux ~]$ tail -f exiles/ConanSandbox/Saved/Logs/ConanSandbox.log 
...
[2022.05.22-02.23.08:626][ 28]LogServerStats: Sending report: exiles-stats?players=0&=30.64%3A32.92%3A35.22&uptime=300&memory=11791499264%3A16653615104%3A4354953216%3A4360814592&cpu_time=6.579306%3A26.317225&npcailods=0%3A0%3A0%3A6501&buildingailods=0%3A0%3A0%3A0&placeableailods=0%3A0%3A0%3A4&ipv4=127.0.1.1&sport=7777
...
```

### Firewall settings

The script will disable firewalld/ufw. Comment those line if that's undesirable. 

If installed on host with firewall on. Open up ports:
- 7777 UDP
- 7778 UDP
- 27015 UDP
- 25575 TCP

If installed on an LXC Container, redirect ports from host to container.

```
echo 1 > /proc/sys/net/ipv4/ip_forward
	
iptables -t nat -I PREROUTING -p udp --dport 7777 -j DNAT --to yourcontainerip
iptables -t nat -I PREROUTING -p udp --dport 7778 -j DNAT --to yourcontainerip
iptables -t nat -I PREROUTING -p udp --dport 27015 -j DNAT --to yourcontainerip
iptables -t nat -I PREROUTING -p tcp --dport 25575 -j DNAT --to yourcontainerip
	
iptables -I FORWARD -d yourcontainerip -p udp --dport 7777 -j ACCEPT
iptables -I FORWARD -d yourcontainerip -p udp --dport 7778 -j ACCEPT
iptables -I FORWARD -d yourcontainerip -p udp --dport 27015 -j ACCEPT
iptables -I FORWARD -d yourcontainerip -p udp --dport 25575 -j ACCEPT
```

### Recommended Setup
Ubuntu 22.04 or Almalinux 8
Close to 3Ghz Quad Core CPU. Could get away with Dual core for small playerbase.
10GB of RAM. Could get away with 8GB with a very small playerbase.
Conan Exiles uses SQLite and writes constantly to disk. This is what I observed regarding filesystems:
- ext4 was ok up until 10 players, then started to crumble. The ```jbd2``` process was I/O waiting all the time.
- ext4 with exclusive partition for the game with journaling disable was good, crumbled with close to 20 players.
- xfs ran great, even with journaling enabled.
- for LXC you might want to have an empty partition for your storage, and use btrfs or zfs.

## Known issues

Not an issue with the script, but with Conan Exiles and Wine in general. When it gets around 7.2GB-8GB of RAM, the server crashes, no matter how much RAM you have in your system. This is a widespread issue with Linux + Wine + Conan Exiles and currently there is no fix. Meaning running Conan Exiles Server in Linux is only viable for small population servers. I'd say up to 10. The daily reboot would happen in time to save the server from a crash.

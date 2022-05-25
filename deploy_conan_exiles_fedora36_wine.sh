#!/bin/bash

# Tested on Fedora 36 in a container with LXC or directly on a server host.

# package installations
dnf -y install vim nano xorg-x11-server-Xvfb gnupg2 iproute openssl procps-ng wget curl tar gzip glibc.i686 iptables atop sysstat
dnf -y install wine

# steam user stuff
useradd -s /bin/bash -m -U steam
sudo -i -u steam bash << EOF
cd /home/steam
echo '
export WINEARCH=win64
export WINEPREFIX=/home/steam/.wine64
' >> /home/steam/.bashrc
export WINEPREFIX=/home/steam/.wine64
export WINEARCH=win64
winecfg
# utilities
test -d /home/steam/bin || mkdir -p /home/steam/bin
wget https://github.com/Tiiffi/mcrcon/releases/download/v0.7.2/mcrcon-0.7.2-linux-x86-64.tar.gz -qO- | tar --no-same-owner -xz -C /home/steam/bin 
wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -qO- | tar --no-same-owner -xz 
wget https://raw.githubusercontent.com/ChaoticWeg/discord.sh/master/discord.sh -P /home/steam/bin
chmod +x /home/steam/bin/discord.sh
printf '#!/bin/bash\nexport WINEARCH=win64\nexport WINEPREFIX=/home/steam/.wine64\nxvfb-run --auto-servernum --server-args='"'"'-screen 0 640x480x24:32'"'"' wine64 /home/steam/exiles/ConanSandboxServer.exe -log\n' > start_conan.sh
chmod +x start_conan.sh
# install the game
wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -qO- | tar --no-same-owner -xz
/home/steam/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir /home/steam/exiles +login anonymous +app_update 443030 +exit
EOF

# post installation
echo '[Unit]
Description=Conan
After=syslog.target network.target

[Service]
Environment=WINEARCH=win64
Environment=WINEPREFIX=/home/steam/.wine64
ExecStart=/usr/bin/xvfb-run --auto-servernum --server-args='"'"'-screen 0 640x480x24:32'"'"' /usr/bin/wine64 /home/steam/exiles/ConanSandboxServer.exe -log
User=steam
Type=simple
Restart=on-failure
RestartSec=60s
TimeoutStartSec=90s
TimeoutStopSec=30s

[Install]
WantedBy=multi-user.target' > /etc/systemd/system/conan.service

systemctl daemon-reload
systemctl disable firewalld --now
systemctl enable conan --now

echo 'Instructions:
	Conan service is enabled with systemd at boot of the LXC container. systemctl status conan
	/home/steam/exiles is the directory tree of the game. There you can find config files and logs in the Saved folder.
	You should manually configure:
		server name
		admin password
			Instructions here: https://www.conanexiles.com/dedicated-servers/
		rcon for server messages, list players, restart of the service, etc
			Instructions here: https://conanexiles.fandom.com/wiki/Rcon
		
		After that, restart the service: systemctl restart conan
		
		You will be able to login to the game, and become admin to change gameplay settings.
		
	On the Linux side. You should also configure a daily reboot (Conan accumulates garbage and the server just becomes unstable with time).
	You can do that with crontab on the container to restart with mrcron (recommended) or on the host with lxc restart containername (less optimal)
	
	You will need o redirect ports from your host to your container, to be executed on the host:
	check container ip with: lxc list yourcontainername
	
	echo 1 >  /proc/sys/net/ipv4/ip_forward
	
	iptables -t nat -I PREROUTING -p udp --dport 7777 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p udp --dport 7778 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p udp --dport 27015 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p tcp --dport 25575 -j DNAT --to yourcontainerip
	
	iptables -I FORWARD -d yourcontainerip -p udp --dport 7777 -j ACCEPT
	iptables -I FORWARD -d yourcontainerip -p udp --dport 7778 -j ACCEPT
	iptables -I FORWARD -d yourcontainerip -p udp --dport 27015 -j ACCEPT
	iptables -I FORWARD -d yourcontainerip -p udp --dport 25575 -j ACCEPT
	
	' > /home/steam/README_FIRST.TXT

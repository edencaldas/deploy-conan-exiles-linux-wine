#!/bin/bash

# Determine if we have a supported OS
source  /etc/os-release

SUPPORTED_PRETTY_NAMES='Ubuntu 22.04|AlmaLinux 8|Rocky Linux 8|openSUSE Leap 15|Fedora Linux 36'

if echo "$PRETTY_NAME" | grep -E -q "$SUPPORTED_PRETTY_NAMES"; then
	echo ""
	echo $PRETTY_NAME Detected. Continuing...
	echo ""
else
	echo ""
	echo $PRETTY_NAME: Unsupported OS. Please use one of these:
	echo ""
	IFS=$'|'
	for os in $SUPPORTED_PRETTY_NAMES ; do echo $os ; done
	IFS=
	exit 1
fi


# Function definitions for OS package installations

install_ubuntu () {
	# package installation
	apt update
	apt install lib32gcc-s1 software-properties-common -y && dpkg --add-architecture i386 && apt update
	apt -y install screen xvfb curl jq wget sudo gnutls-bin ca-certificates openssl gnupg
	apt -y install wine wine32 wine64 --install-recommends
}

install_enterpriselinux () {
	# package installation
	dnf -y install dnf-plugins-core yum-utils
	dnf -y install epel-release
	dnf config-manager --set-enabled powertools
	dnf -y install vim nano xorg-x11-server-Xvfb gnupg2 iproute openssl procps-ng wget curl tar gzip glibc.i686 iptables atop sysstat
	dnf -y install wine
}

install_fedora () {
	# package installations
	dnf -y install vim nano xorg-x11-server-Xvfb gnupg2 iproute openssl procps-ng wget curl tar gzip glibc.i686 iptables atop sysstat
	dnf -y install wine
}

install_opensuse () {
	# Disabling this repo, has been broken for months
	zypper mr -d repo-sle-update

	# package installations
	zypper in -y --recommends vim wine wget curl ca-certificates-mozilla xvfb-run
}

main_install () {

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
wget https://raw.githubusercontent.com/ChaoticWeg/discord.sh/master/discord.sh -P /home/steam/bin
chmod +x /home/steam/bin/discord.sh
printf '#!/bin/bash\nexport WINEARCH=win64\nexport WINEPREFIX=/home/steam/.wine64\nxvfb-run --auto-servernum --server-args='"'"'-screen 0 640x480x24:32'"'"' wine64 /home/steam/exiles/ConanSandboxServer.exe -log\n' > start_conan.sh
chmod +x start_conan.sh
# install steamcmd and the game
wget "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" -qO- | tar --no-same-owner -xz
/home/steam/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir /home/steam/exiles +login anonymous +app_update 443030 +exit
EOF
}

post_install () {

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

	Firewall Settings:

	If using LXC container, you will need to redirect ports from your host to your container, to be executed on the host:
	check container ip with: lxc list yourcontainername

	echo 1 >  /proc/sys/net/ipv4/ip_forward

	iptables -t nat -I PREROUTING -p udp --dport 7777 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p udp --dport 7778 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p udp --dport 27015 -j DNAT --to yourcontainerip
	iptables -t nat -I PREROUTING -p tcp --dport 25575 -j DNAT --to yourcontainerip

	iptables -I FORWARD -d yourcontainerip -p udp -m multiport --dports 7777,7778,27015 -j ACCEPT
	iptables -I FORWARD -d yourcontainerip -p tcp --dport 25575 -j ACCEPT

	If running on cloud, and installed on the host Instance, I recommend not using firewall on the host at all. Instead, manage the rules with your cloud firewall (eg: Security Groups in AWS)

	To disable firewall:
	systemctl disable firewalld --now
	ufw disable

	If running on a host with public IP directly configured on its NIC, then I recommend firewall. Open up ports:

	iptables -I INPUT -p udp -m multiport --dports 7777,7778,27015 -j ACCEPT
	iptables -I INPUT -p tcp --dport 25575 -j ACCEPT


	' > /home/steam/README_FIRST.TXT
}


case $ID in
	ubuntu)
		install_ubuntu
		main_install
		post_install
		;;
	almalinux|rocky)
		install_enterpriselinux
		main_install
		post_install
		;;
	opensuse-leap)
		install_opensuse
		main_install
		post_install
		;;
	fedora)
		install_fedora
		main_install
		post_install
		;;
	*)
		echo "Invalid OS"
		exit 1
esac

cat /home/steam/README_FIRST.TXT

# deploy-conan-exiles-linux-wine
Simple (just works) script to install Conan Exiles with wine on a Linux container / VM / Baremetal

This script can be ran as-is in:
        Virtual Machines
        LCX Containers
        Baremetal

You will end up with a functional Conan Exiles Dedicate Server running on Linux with Wine.

## Motivation for creating these scripts

I could not find a reliable Docker image for conan Exiles, or create one myself. I would always run into, being either the server was not advertising to Funcom servers, or connections that require certificates would loop endelessly. Docker might be messing too much with the network stack for its containers, as the exact same setup works everywhere else. Regardless, LXC is a much beter fit for Conan Exiles. Whereas Dockers is made for app containerzation, LXC is made for full-blown VM-like containers. It's a perfect match for Conan Exiles.

Since the scripts work with LXC, they also do for VMs and baremetal machines.

## Usage

Download one of the ```deploy_conan_exiles_*.sh``` files appropriate to your linux distribution.
Login to your VM/Container/Machine and execute the script as root.
Alternatively, if using Cloud (eg: AWS) you can put the script in your instance's userdata.
For LXC, you can use cloud-init. Or you can just login as root ( ```lxc exec yourcontainer -- bash``` ) and execute the script.

## What the script will do.

- Install all required and usefl packages.
- Download mcrcon and discord.sh for server management and discord messages.
- Install steamcmd and download conan exiles with it.
- Setup a systemd unit file called ```conan``` and start it.
- Create a readme file with further instructions.

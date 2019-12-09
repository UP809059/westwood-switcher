#!/bin/bash
#Should be placed at /etc/network/if-up.d/westwood-switcher
#Ensure the file is executable with chmod +x westwood-switcher

WIFI_ALGO="westwood"
WIRED_ALGO="cubic"
LOG_FILE="/var/log/westwood-switcher/connect_times.log"
WESTWOOD_KERNEL_MODULE_LOCATION="/lib/modules/$(uname -r)/kernel/net/ipv4/tcp_westwood.ko"

function CheckIsRoot(){
	if [ "$(whoami)" != "root" ]
	then echo "Non root!" && exit 1
	fi
}


function LoadWestwoodModule(){
        echo "Loading westwood module now from: $WESTWOOD_KERNEL_MODULE_LOCATION"
        insmod "$WESTWOOD_KERNEL_MODULE_LOCATION"
}

function WestwoodModuleIsLoaded(){
    if [ -z "$(lsmod | grep tcp_westwood)" ]
    then echo "Westwood not loaded" && return 0
    else echo "Westwood module is already loaded." && return 1
    fi
}

function IsConnectToWifi(){
	#nmcli gives us similar to:
	#DEVICE      TYPE      STATE        CONNECTION
	#wlp1s0      wifi      connected    eduroam    
	#virbr0      bridge    connected    virbr0     
	#enp2s0f1    ethernet  unavailable  --         
	#lo          loopback  unmanaged    --         
	#virbr0-nic  tun       unmanaged    -- 
	local wifiConnectedStr="wifi      connected"
	local connectedMatch=$(nmcli d status | grep -o "$wifiConnectedStr")

	if [ ! -z "$connectedMatch" ]
	then echo "Wifi is connected" && return 1
	else echo "NOT CONNECTED to wifi" && return 0
	fi
}

function SetTCPAlgo(){
	if [ -z "$1" ]
	then echo "0 args passed to SetTCPAlgo." && exit 1
	fi
	echo "Setting TCP algo to: $1"
	if [[ "$1" != "$WIFI_ALGO" && "$1" != "$WIRED_ALGO" ]]
	then echo "Invalid algo: $1" && exit 1
	fi

	#sysctl -w is not persistant over reboot. Write to /etc/sysctl.conf for persistance
	sysctl -w net.ipv4.tcp_congestion_control="$1"
	echo "Switched to $1 at $(date)" >> "$LOG_FILE"
}

#Main
CheckIsRoot

WestwoodModuleIsLoaded
if [ "$?" == "0" ] # "$?" is the returned value from the previous function
then LoadWestwoodModule
fi

IsConnectToWifi
if [ "$?" == "1" ] 
then
	SetTCPAlgo "$WIFI_ALGO"
else
	SetTCPAlgo "$WIRED_ALGO"
fi

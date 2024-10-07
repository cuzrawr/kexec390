#!/bin/sh


	cidr_to_netmask() {
	    local cidr=$1
	    local mask=""
	    local full_octets=$((cidr / 8))
	    local partial_octet=$((cidr % 8))

	    # Full 255 octets
	    for ((i=0; i<full_octets; i++)); do
	        mask+=255
	        [[ $i -lt 3 ]] && mask+=.
	    done

	    # Partial octet
	    if [[ $full_octets -lt 4 ]]; then
	        local octet=$((256 - 2**(8-partial_octet)))
	        mask+=$octet
	        for ((i=full_octets+1; i<4; i++)); do
	            mask+=.0
	        done
	    fi

	    echo $mask
	}

	# Get default iface
	IFNM=$(ip -c=never -o link show | grep -oP '(?<=^2:\s)\w+')

	# Get client IP
	CLNTIP=$(ip -c=never -4 addr show $IFNM | grep inet | awk '{print $2}' | cut -d'/' -f1)

	# Get CIDR notation
	IPCDR=$(ip -c=never -4 addr show $IFNM | grep inet | awk '{print $2}' | cut -d'/' -f2)

	# Convert CIDR to netmask
	NTMSK=$(cidr_to_netmask $IPCDR)

	#  GW
	GWIP=$(ip -c=never  route | grep default | grep $IFNM | awk '{print $3}')

	# DNS
	DNS1="1.1.1.1"
	DNS2="8.8.8.8"

	# see
	# https://wiki.alpinelinux.org/wiki/S390x/Installation
	# or
	# https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt
	SRVIP="none"
	hostname="alpikexec"
	AUTOCNF="none"

	# Form and return the static IP string
	#echo "ip=${CLNTIP}:${SRVIP}:${GWIP}:${netmask}:${hostname}:${IFNM}:${AUTOCNF}:${DNS1}:${DNS2}"
    echo "ip=${CLNTIP}:${SRVIP}:${GWIP}:${NTMSK}:${hostname}:eth0:${AUTOCNF}:${DNS1}:${DNS2}"



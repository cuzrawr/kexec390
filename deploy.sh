#!/bin/bash


# REWRITE NET TO SUPPORT ONLY SH

# Kexec Script for s390x using Alpine Linux
# Automatically fetches the required files and executes kexec.
# tested in qemu & real hw.


set -e

GH_REPO_URL="https://raw.githubusercontent.com/cuzrawr/kexec390/refs/heads/main/"
BASE_URL="https://dl-cdn.alpinelinux.org/alpine/"
ALPINE_VERSION="edge"
NETBOOT_PATH="/releases/s390x/netboot/"
KERNEL_KEXEC="bzImage"
INITRD_KEXEC="initramfs-lts"
KEY_FILE="randssh.key"
PUB_KEY_FILE="${KEY_FILE}.pub"
DEBUG_SW=""
# if not used --static that will be default
IPCONF=" ip=dhcp "

display_usage() {
	program=$(basename "$0")
	cat <<EOF
Usage: $program [OPTIONS]

This script automatically downloads kernel and initrd for s390x
and executes kexec for it.

Options:
	-k, --kernel <kernel>	Kernel image (default: bzImage)
	-i, --initrd <initrd>	Initrd file (default: initramfs-lts)
	-a, --alpine <version>  Alpine version (default: edge)
	-f, --fetch				Only fetch the required files
	-n, --noask				Do not ask for a reboot; execute it immediately
	-s, --static			Clone current HOST IP configuration to kexec.
	-d, --debug				Pass -d (debug) switch to kexec.
	-h, --help				Show this help message

Usage examples:

  Run kernel bzImage & initramfs-lts as initrd with alpine v3.20 and debug:
	./$program --kernel "bzImage" --initrd "initramfs-lts" --alpine "v3.20" -d

  Run with a hardcoded initrd and Alpine version (edge) but chose bzImage as kern:
	./$program -k "bzImage"

  Just fetch all required files:
	./$program --fetch

  Run interactively with guided questions yes/no:
	./$program

Note:
  The bzImage provided with all options enabled (=y).

  If you are running ~6.6 (vmlinuz-lts) in qemu-s390x with host OS x86_64 then
  , there is a bug: Alpine will not boot. ( all ver. 3.10-3.20, edge tested).
  So use only provided bzImage for such case. For real HW its not required.

EOF
}




# Check if the script is running in Bash
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script must be run in Bash."
    exit 1
fi


# check
#[ "$(id -u)" -ne 0 ] && { echo "Error: Must be run as root."; exit 1; }

# check
#command -v kexec >/dev/null || { echo "Error: kexec-tools is not installed."; exit 1; }

# Check
#[ -e /proc/sys/kernel/kexec_load_disabled ] && [ "$(cat /proc/sys/kernel/kexec_load_disabled)" -ne 0 ] && \
#	{ echo "Error: kexec is disabled."; exit 1; }



gather_ntwrk() {
	# see
	# https://wiki.alpinelinux.org/wiki/S390x/Installation
	# or
	# https://www.kernel.org/doc/Documentation/filesystems/nfs/nfsroot.txt


	#
	# TODO: pass IP addresses as arguments
	#


	cidr_to_netmask() {
		local cidr=$1
		local value=$(( 0xffffffff ^ ((1 << (32 - cidr)) - 1) ))
		echo "$(( (value >> 24) & 0xff )).$(( (value >> 16) & 0xff )).$(( (value >> 8) & 0xff )).$(( value & 0xff ))"
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


	SRVIP="none"
	hostname="alpikexec"
	AUTOCNF="none"

	# Form and return the static IP string
	#echo "ip=${CLNTIP}:${SRVIP}:${GWIP}:${netmask}:${hostname}:${IFNM}:${AUTOCNF}:${DNS1}:${DNS2}"
	echo "Net static: ip=${CLNTIP}:${SRVIP}:${GWIP}:${NTMSK}:${hostname}:eth0:${AUTOCNF}:${DNS1}:${DNS2}"
	IPCONF="ip=${CLNTIP}:${SRVIP}:${GWIP}:${NTMSK}:${hostname}:eth0:${AUTOCNF}:${DNS1}:${DNS2}"
}





fetch_files() {
	curl_cmd="curl --progress-bar"


	[ ! -f "$INITRD_KEXEC" ] && curl_cmd+=" -O ${NETBOOT_URL}${INITRD_KEXEC}"

	if [ ! -f "$KERNEL_KEXEC" ]; then
		case "$KERNEL_KEXEC" in
			"bzImage") curl_cmd+=" -O ${GH_REPO_URL}bzImage" ;;
			"vmlinuz-lts") curl_cmd+=" -O ${NETBOOT_URL}vmlinuz-lts" ;;
			*) curl_cmd+=" -O ${GH_REPO_URL}bzImage" ;;
		esac
	fi

	[ ! -f "$KEY_FILE" ] && curl_cmd+=" -O ${GH_REPO_URL}${KEY_FILE}"
	[ ! -f "$PUB_KEY_FILE" ] && curl_cmd+=" -O ${GH_REPO_URL}${PUB_KEY_FILE}"


	[ "$curl_cmd" != "curl --progress-bar" ] && eval "$curl_cmd"
	return 0
}

check_files() {
	for file in "${INITRD_KEXEC}" "${KERNEL_KEXEC}" "$KEY_FILE" "$PUB_KEY_FILE"; do
		[ ! -f "$file" ] && { echo "Error: $file not found."; exit 1; }
	done
	return 0
}





# Guided mode for user input
guided_mode() {
	echo "No arguments provided, entering guided mode..."

	userChoseAlpineVer() {
		echo "Select the Alpine Linux version:"
		echo "1) edge"
		echo "2) latest-stable"
		echo "3) v3.20"
		read -p "Enter the number: " alpine_choice

		case $alpine_choice in
			1) ALPINE_VERSION="edge" ;;
			2) ALPINE_VERSION="latest-stable" ;;
			3) ALPINE_VERSION="v3.20" ;;
			*) echo "Invalid choice. Defaulting to 'edge'." ;;
		esac
	}

	userChoseInitrdImg() {
		echo "Select the kernel to use:"
		echo "1) bzImage (default) (if unsure use this)"
		echo "2) vmlinuz-lts"
		read -p "Enter the number: " kernel_choice

		case $kernel_choice in
			1) KERNEL_KEXEC="bzImage" ;;
			2) KERNEL_KEXEC="vmlinuz-lts" ;;
			*) echo "Invalid choice. Using default bzImage." ;;
		esac
	}

	userChoseNet() {
		echo "Use static IP config? :"
		echo "1) DHCP (default)"
		echo "2) Static IP (if you working on IBM linux1 - use static)"
		read -p "Enter the number: " staticip_choice

		case $staticip_choice in
			1) IPCONF="DHCP" ;;
			2) USESTATIC="YES" ;;
			*) echo "Invalid choice. Using default DHCP." ;;
		esac
	}

	userChoseAlpineVer
	userChoseInitrdImg
	userChoseNet
}




main() {
	# Parse command-line arguments
	if [ $# -eq 0 ]; then
		guided_mode
	fi



	# Generate URLs for file fetching
	#NETBOOT_URL="${BASE_URL}${ALPINE_VERSION}${NETBOOT_PATH}"

	#echo "netboot url is: ${NETBOOT_URL}"

	fetch_files
	check_files

	clear


	# if arg static used we will try to generate ip= string
	# because some linuxONE instances somehow cant use DHCP.
	# test
	# basically we taking current host net config as well known working one.
	# see gather_ntwrk() to details
	if [ "$USESTATIC" = "YES" ]; then
		gather_ntwrk
	fi
	echo -e "\nPrivate key (save to your local machine):\n"
	cat "$KEY_FILE"

	echo -e "\nExample SSH usage: \n\nchmod 600 randssh.key && ssh -i randssh.key root@1.1.1.1 \n\n"


	#
	proceed_with_kexec() {
		# Check shutu
		if [ "$REBQUE" != "noask" ]; then
			read -p "Proceed with kexec reboot? (y/n): " choice
			if [ "$choice" != "y" ]; then
				echo "Reboot canceled."
				return
			fi
		fi

		# Proceed with kexec reboot
		echo "Proceeding with kexec reboot..."

		# warning currently dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002
		# is hardcoded
		set -x

		kexec $DEBUG_SW -l "$(pwd)/${KERNEL_KEXEC}" --initrd="$(pwd)/${INITRD_KEXEC}" \
			--append=" ${IPCONF} alpine_repo=${BASE_URL}${ALPINE_VERSION}/main modloop=${BASE_URL}${ALPINE_VERSION}${NETBOOT_PATH}modloop-lts ssh_key=${GH_REPO_URL}${PUB_KEY_FILE} dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002 "
		kexec -e $DEBUG_SW
		set +x
	}

	#
	proceed_with_kexec

}


while [ $# -gt 0 ]; do
	case "$1" in
		-k|--kernel) KERNEL_KEXEC="$2"; shift 2 ;;
		-i|--initrd) INITRD_KEXEC="$2"; shift 2 ;;
		-a|--alpine) ALPINE_VERSION="$2"; shift 2 ;;
		-n|--noask) REBQUE="noask"; shift 1 ;;
		-d|--debug) DEBUG_SW="-d"; shift 1 ;;
		-s|--static) USESTATIC="YES"; shift 1 ;;
		-f|--fetch) fetch_files; exit 0 ;;
		-h|--help) display_usage; exit 0 ;;
		*) echo "Error: Unknown option $1"; display_usage; exit 1 ;;
	esac
done



main


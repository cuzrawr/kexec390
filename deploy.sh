#!/bin/sh

# Kexec Script for s390x using Alpine Linux
# Automatically fetches the required files and executes kexec.

set -e

# Constants
GH_REPO_URL="https://raw.githubusercontent.com/cuzrawr/kexec390/refs/heads/main/"
BASE_URL="https://dl-cdn.alpinelinux.org/alpine/"
ALPINE_VERSION="edge"
NETBOOT_PATH="/releases/s390x/netboot/"
KERNEL_KEXEC="bzImage"
INITRD_KEXEC="initramfs-lts"
KEY_FILE="randssh.key"
PUB_KEY_FILE="${KEY_FILE}.pub"

display_usage() {
    program=$(basename "$0")
    cat <<EOF
Usage: $program [OPTIONS]

This script automatically downloads kernel and initrd for s390x
and executes kexec for it.

Options:
  -k, --kernel <kernel>    Kernel image (default: bzImage)
  -i, --initrd <initrd>    Initrd file (default: initramfs-lts)
  -a, --alpine <version>   Alpine version (default: edge)
  -f, --fetch              Only fetch the required files
  -n, --noask              Do not ask for a reboot; execute it immediately
  -h, --help               Show this help message

Usage examples:

  Run without prompting:
    ./$program --kernel "bzImage" --initrd "initramfs-lts" --alpine "v3.20"

  Run with a hardcoded initrd and Alpine version (edge):
    ./$program -k "bzImage"

  Just fetch the required files:
    ./$program --fetch

  Run interactively with guided questions:
    ./$program

Note:
  The bzImage provided with all options enabled (=y).

  If you are running approximately 6.6 (vmlinuz-lts) in qemu-s390x with host OS
   of x86_64, there is a bug: Alpine will not boot (ver 3.20 tested).
  Use only the provided bzImage for such case.

EOF
}

# Guided mode for user input
guided_mode() {
    echo "No arguments provided, entering guided mode..."

    select_alpine_version() {
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

    prompt_kernel_choice() {
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

    select_alpine_version
    prompt_kernel_choice
}






# check
#[ "$(id -u)" -ne 0 ] && { echo "Error: Must be run as root."; exit 1; }

# check
#command -v kexec >/dev/null || { echo "Error: kexec-tools is not installed."; exit 1; }

# Check
#[ -e /proc/sys/kernel/kexec_load_disabled ] && [ "$(cat /proc/sys/kernel/kexec_load_disabled)" -ne 0 ] && \
#    { echo "Error: kexec is disabled."; exit 1; }







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

	    kexec -l "$(pwd)/${KERNEL_KEXEC}" --initrd="$(pwd)/${INITRD_KEXEC}" \
	        --append=" ip=dhcp alpine_repo=${BASE_URL}${ALPINE_VERSION}/main modloop=${BASE_URL}${ALPINE_VERSION}${NETBOOT_PATH}modloop-lts ssh_key=${GH_REPO_URL}${PUB_KEY_FILE} dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002 "
	    kexec -e
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
	        -n|--noask) REBQUE="noask"; shift 2 ;;
	        -f|--fetch) fetch_files; exit 0 ;;
	        -h|--help) display_usage; exit 0 ;;
	        *) echo "Error: Unknown option $1"; display_usage; exit 1 ;;
	    esac
	done


main


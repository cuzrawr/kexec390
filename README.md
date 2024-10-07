# kexec390
An automated kexec tool for debugging on the s390x architecture, utilizing Alpine netboot images.

Tested kexec:
- ubuntu to alpine works.
- alpine to alpine works.



The repository provides a pre-compiled 6.12.0-rc1 kernel because qemu-system-s390x when running on an x86_64 host is NOT booting properly.

The bzImage itself has all options set to =y, so there are no missing modules and no need to repack Alpine's initrd.

The script will prompt you to choose which version to use.

The script also uses hardcoded defaults such as:
```bash
" dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002 "
```

These defaults allow for the visibility of dasd devices and proper network functionality on native s390x hosts.
If your hardware setup differs, please check the lshw utility and replace the appropriate values (this is not automated currently).

# WARNING:
  If you are running ~6.6 (vmlinuz-lts) in qemu-s390x with host OS x86_64 then
  , there is a bug: Alpine will not boot. ( all ver. 3.10-3.20, edge tested).
  So use only provided bzImage for such case. For real HW seems hitting same bug.
  So 6.12+git kernel proof to works.



# Usage

```bash
git clone https://github.com/cuzrawr/kexec390 && \
	cd kexec390 && \
	chmod +x deploy.sh && \
	sudo ./deploy.sh
```

Alternative (less ideal) method:

```bash
curl -sSL https://raw.githubusercontent.com/cuzrawr/kexec390/refs/heads/main/deploy.sh | sudo bash
```

# ...

The script has been tested on a real s390x system.

Happy hacking!

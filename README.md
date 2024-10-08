# kexec390
An automated kexec tool for debugging on the s390x architecture, utilizing Alpine netboot images.

(Warning)

 WARNING
 ALPINE LINUX KERNEL CURRENTLY COMPLETELY BROKEN, USE THAT ONE
 WHAT I PROVIDE.

 There tested params for s390x HW (qemu works too without -s ):

 ./deploy.sh -s -k "bzImage" -i "initramfs-lts" -n


Tested kexec:
- ubuntu to alpine works.
- alpine to alpine not works.



The repository provides a pre-compiled 6.12.0-rc1 kernel because qemu-system-s390x when running on an x86_64 or s390x host is NOT booting properly, not sure what causing this.

The bzImage itself has all options set to =y, so there are no missing modules and no need to repack Alpine's initrd.

bzImage using lts alpine kconf.

The script will prompt you to choose which version to use.
But until there bug with hangs will be fixed consider using only bzImage.

The script currently uses some default values:
```bash
" dasd=0.0.0100 s390x_net=qeth_l2,0.0.1000,0.0.1001,0.0.1002 "
```
To enhance, it would be great to implement automatic gathering using the `lshw` command.

If your hardware setup is different, please use the lshw utility to check and update the values as needed (note that this step isn't automated at the moment).


# WARNING:
  If you are running ~6.6 (vmlinuz-lts) in qemu-s390x with host OS x86_64 then
  , there is a bug: Alpine will not boot. ( all ver. 3.10-3.20, edge tested).
  So use only provided bzImage for such case. For real HW seems hitting same bug.
  So 6.12+git kernel proof to works.


# Test run

## Image
![Alpine has successfully executed a kexec.](2024-10-07_09-14_pngquant.png)



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

# Fast way to start

For users with a native IBM S390X computer, please use the following command:

```bash
./deploy.sh -s -k "bzImage" -i "initramfs-lts" -n
```

For those operating within qemu-s390x, use this command instead:

```bash
./deploy.sh -k "bzImage" -i "initramfs-lts" -n
```


# qemu examples:

Where -smp select proper config for your cpu from /proc/cpuinfo


s390x:

```bash
qemu-system-s390x   -enable-kvm  -m 8G   -smp 4,sockets=4,cores=1,threads=1    -nographic   -netdev user,id=vmnic,hostfwd=tcp::2223-:22   -device virtio-net-ccw,netdev=vmnic   -hda ubuntu-24.04-server-cloudimg-s390x.img  -cpu host -object rng-random,filename=/dev/urandom,id=rng0     -device virtio-rng-ccw,rng=rng0


```

x86_64:

```bash
qemu-system-s390x   -m 8G   -smp 4   -nographic   -netdev user,id=vmnic,hostfwd=tcp::2223-:22   -device virtio-net-ccw,netdev=vmnic   -hda ubuntu-24.04-server-cloudimg-s390x.img  -cpu max -object rng-random,filename=/dev/urandom,id=rng0     -device virtio-rng-ccw,rng=rng0


```




# ...

The script has been tested on a real s390x system.

Happy hacking!

# Manual patch KSU

extract payload.bin from factory OTA

then extract images from payload:

```shell
payload-dumper-go ./payload.bin
```
get boot.img from extracted images

Download the AnyKernel3 ZIP file provided by KernelSU that matches the KMI version of your device. You can refer to Install with custom Recovery.

Unpack the AnyKernel3 package and get the Image file, which is the kernel file of KernelSU.

```shell
./magiskboot unpack boot.img
``` 
to unpack boot.img, you will get a kernel file, this is your stock kernel.

Replace kernel with Image by running the command: mv -f Image kernel

```shell
./magiskboot repack boot.img
```
 to repack boot image, and you will get a new-boot.img file, flash this file to device by fastboot.
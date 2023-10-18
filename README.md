# This is the master branch!
This repository is going to keep using the term "master". It will never change.
I refuse to switch to "main".

## R2S is based on native OpenWRT firmware compilation script (AS IS, NO WARRANTY!!!)
Please do not use it for commercial purposes!!!
Also includes x86_64 version

### Release address:
(You may overturn, you are at your own risk. You need to log in to your GitHub account before downloading. No technical support of any kind is provided)
https://github.com/KaneGreen/OpenWrt-Builder/actions  
![OpenWrt for R2S](https://github.com/KaneGreen/OpenWrt-Builder/workflows/OpenWrt%20for%20R2S/badge.svg?branch=master&event=push)
![OpenWrt for x86](https://github.com/KaneGreen/OpenWrt-Builder/workflows/OpenWrt%20for%20x86/badge.svg?branch=master&event=push)

It is recommended to check the change log to confirm changes between versions.

### Precautions:
1. Login IP: `192.168.1.1`, password: none.

2. Built-in upgrade of R2S version of OpenWrt is available.

3. The R2S version no longer exchanges LAN and WAN network ports, which is consistent with the upstream definition.

4. If you are unable to connect to the Internet, please check your own IPv6 connection, or disable IPv6 (disable IPv6 for WAN and LAN at the same time) (DNS resolution of IPv6 is turned off by default, you can manually do so in the advanced settings in DHCP/DNS Adjustment)

5. The sys light of the R2S version flashes during boot and stays on after startup. This is also the upstream setting. If you have any questions, please contact the OpenWrt official community.

### Version Information:
LUCI version: OpenWrt-23.05 RC (latest on the day)

Other module versions: OpenWrt-23.05 RC (latest on the day)

### Features and functions:
1. O2 optimization level. R2S version has a core frequency of 1.5GHz and SquashFS format. x86 version in EXT4 format, non-UEFI version.

2. A built-in theme includes SSRP, OpenClash, SQM, Wake-on-LAN, DDNS, UPNP, FullCone (enabled by default), traffic offloading (enabled manually in the firewall), and BBR v3 (enabled by default).  
[Full feature list](./featurelist.md)

3. The compilation results in Github Actions include SHA256 hash check and MD5 hash check files. The same content will also be displayed in the `Cleaning and hashing` step (the fourth to last step) of the Actions compilation log. **Please pay attention to check and verify the integrity of the firmware file! **

4. [Clean flash tutorial](./howto_cleanflash.md) [Change log](./CHANGELOG.md)

### Third generation shell OLED related
The R2S version does not compile and install the OLED luci-app. Those who need it can find the software package and install it by themselves.
This feature is not supported on the x86 version.

### Local one-click compilation script (experimental)
1. First configure the environment by yourself. For Ubuntu 22.04, please refer to [Line 56 of the Actions script](.github/workflows/R2S-OpenWrt.yml).
2. Get the one-key compilation script: [onekeybuild.sh](./onekeybuild.sh). Modify the script according to the specific situation, such as the parallel number of the compilation tool chain on line 32.
3. Make sure there is no directory or file with the same name in the working directory: `OpenWrt-Builder`, `buildtime.txt`.
4. Specify the compiled firmware through the environment variable `MYOPENWRTTARGET`: `R2S`, `x86`; note that it is case sensitive and the R2S firmware is compiled by default.
5. Specify the number of parallel compilations through the environment variable `MYMAKENUMBER`. The default is 4 parallels.
6. Use bash to execute the script and start compilation.

### grateful
* [QiuSimons](https://github.com/QiuSimons/)
* [quintus-lab](https://github.com/quintus-lab/)
* [CTCGFW](https://github.com/immortalwrt/immortalwrt)
* [coolsnowwolf](https://github.com/coolsnowwolf)
* [Lienol](https://github.com/Lienol)
* [NoTengoBattery](https://github.com/NoTengoBattery)
* and all other contributors who have contributed to R2S.

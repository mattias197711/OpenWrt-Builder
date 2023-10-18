This is the master branch!
This repository is going to keep using the term "master". It will never change. I refuse to switch to "main".

R2S is based on native OpenWRT firmware compilation script (AS IS, NO WARRANTY!!!)
Please do not use it for commercial purposes!!!
Also includes x86_64 version

Release address:
(You may overturn, you are at your own risk. You need to log in to your GitHub account before downloading. No technical support of any kind is provided)
https://github.com/KaneGreen/OpenWrt-Builder/actions
OpenWrt for R2S OpenWrt for x86

It is recommended to check the change log to confirm changes between versions.

Precautions:
Login IP: 192.168.1.1, password: none.

A built-in upgrade is available for the R2S version of OpenWrt.

The R2S version no longer exchanges LAN WAN network ports, which is consistent with the upstream definition.

If you are unable to connect to the Internet, please check your own IPv6 connection, or disable IPv6 (disable IPv6 for WAN and LAN at the same time) (DNS resolution for IPv6 is turned off by default, and can be manually adjusted in the advanced settings in DHCP/DNS)

The sys light of the R2S version flashes during boot and stays on after startup. This is also an upstream setting. If you have any questions, please contact the OpenWrt official community.

Version Information:
LUCI version: OpenWrt-23.05 RC (latest on the day)

Other module versions: OpenWrt-23.05 RC (latest on the day)

Features and functions:
O2 optimization level. R2S version has a core frequency of 1.5GHz and SquashFS format. x86 version in EXT4 format, non-UEFI version.

A built-in theme includes SSRP, OpenClash, SQM, Wake-on-LAN, DDNS, UPNP, FullCone (enabled by default), traffic offloading (enabled manually in the firewall), and BBR v3 (enabled by default).
Full feature list

The compilation results in Github Actions include SHA256 hash check and MD5 hash check files. The same content will also be displayed in Cleaning and hashingthe step (the fourth to last step) of the Actions compilation log. Please pay attention to check and verify the integrity of the firmware file!

Cleaning and Flashing Tutorial Change Log

Third generation shell OLED related
The R2S version does not compile and install the OLED luci-app. Those who need it can find the software package and install it by themselves. This feature is not supported on the x86 version.

Local one-click compilation script (experimental)
First configure the environment by yourself. For Ubuntu 22.04, you can refer to line 56 of the Actions script .
Get the one-key compilation script: onekeybuild.sh . Modify the script according to the specific situation, such as the parallel number of the compilation tool chain on line 32.
Make sure there is no directory or file with the same name in the working directory: OpenWrt-Builder, buildtime.txt.
MYOPENWRTTARGETSpecify the compiled firmware through environment variables : R2S, x86; note that it is case sensitive, and the R2S firmware is compiled by default.
MYMAKENUMBERSpecify the number of parallel compilations through environment variables . The default is 4 parallels.
Use bash to execute the script and start compilation.
grateful
QiuSimons
quintus-lab
CTCGFW
coolsnowwolf
Lienol
NoTengoBattery
and all other contributors who have contributed to R2S.

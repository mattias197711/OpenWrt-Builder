## 清盘刷机脚本使用说明
### 1. 获取脚本
```bash
mkdir /tmp/uploads
cd /tmp/uploads
curl --proto '=https' --tlsv1.2 -sSf -O \
     https://fastly.jsdelivr.net/gh/KaneGreen/OpenWrt-Builder@master/clean_flash.sh
```
### 2. 上传固件
使用 sftp 工具或 scp 命令将固件上传到 `/tmp/uploads` 目录下。  
支持 IMG 镜像文件或 GZ 压缩包格式。  
文件名以 `openwrt` 开头，以 `.img` 或 `.img.gz` 结尾（注意：大小写敏感）。

如果有 MD5 或 SHA256 的校验文件，请也上传到 `/tmp/uploads` 目录下。  
MD5 校验文件的文件名称格式为 `md5_????????.hash`。  
SHA256 校验文件的文件名称格式为 `sha256_????????.hash`。
### 3. 执行刷机
#### 3.1 默认刷写
目前的 OpenWrt 镜像已默认包含写零区段，使用该方式刷机会清除配置。
如果确定要操作，请执行下面的命令。
```bash
/bin/bash /tmp/uploads/clean_flash.sh
```
#### 3.2 额外写零
对磁盘的一定区域进行额外的“写零”清盘后再刷机。  
但是，此过程通常需要消耗较长时间。
```bash
CLEANDISK=2 /bin/bash /tmp/uploads/clean_flash.sh
```
注意 `CLEANDISK` 环境变量的值，上面的例子中是 `2`，即只对储存卡上前 2GB 的空间做“写零”处理。  
同理若为 `1`，则前 1GB；若为 `3`，则前 3GB；若为 `4`，则前 4GB；以此类推。  
但是，若为 `0` 或其他非数字值，则对整个储存卡上的所有空间做“写零”处理。但这可能需要消耗很长时间。  
例如下面的命令将全清整个储存卡。
```bash
CLEANDISK=true /bin/bash /tmp/uploads/clean_flash.sh
```

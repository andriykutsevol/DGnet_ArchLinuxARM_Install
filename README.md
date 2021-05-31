# DGnet_ArchLinuxARM_Install

### Usage
```sh
$ sudo ./ArchToPi.sh <sdCard/DeviceName>
# Example: $ sudo ./ArchToPi.sh /dev/sdc
```


### Description of the [ArchToPi.sh](https://github.com/andriykutsevol/DGnet_ArchLinuxARM_Install/blob/main/ArchToPi.sh)
- Run the script with a root privileges.
If **ArchLinuxARM** installation archive is does not exists in the current directory
will try to upload the **ArchLinuxARM-rpi-4-latest.tar.gz** from the [ArchLinuxARM](https://archlinuxarm.org/about/downloads)

- By the time being the script does not expose any configuration to the command line, except the SD card device name.
But there are the following setups:
It will create 2 partitions: **512 MB fat23 partition for boot, and the rest for ext4 for root.**

- Also by the time being it is configured to use **DHCP Wireless**. 
In the begining of the script set the next variables to yours values:
`WIRELESS_INTERFACE="wlan0"`
`WIRELESS_ESSID="TP-Link_6611"`
`WIRELESS_KEY="26685250"`

- It will disable IPV6
- Root login:
`username: root`
`password: root`

- It will create one more user:
`username: dgnet`
`password: 1234`

### SSH Keys.

- There is the **./ssh** directory. The script will copy the **./ssh/dgnet_alarm.pub** to the PI with according privileges.
So the you could use the **./ssh/dgnet_alarm** private key to login to the PI. Example(from the current directory):
`ssh -vvv -i ./ssh/dgnet_alarm dgnet@192.168.0.105`
where **192.168.0.105** is the PI's IP.
- To find the IP of your's PI - run:
`ficonfig`
And look for: **wlan0: inet <your PI's IP>**
Read an **./ssh/info.txt** for more details.

- Also script will try to remove PI from ~/.ssh/known_hosts (it is annoying to remove it manually every time)
`ssh-keygen -R 192.168.0.105`
where **192.168.0.105** is the PI's IP.


### Description of the [ArchToPi_PostInstall.sh](https://github.com/andriykutsevol/DGnet_ArchLinuxARM_Install/blob/main/ArchToPi_PostInstall.sh)

- **./ArchToPi.sh** will copy the **./ArchToPi_PostInstall.sh** in to the **./root/root** directory

- login to the PI
`ssh -vvv -i ./ssh/dgnet_alarm dgnet@192.168.0.105`
then you have to bacome a root user
`su`
and give it a "root" password.
`cd /root`
`./ArchToPi_PostInstall.sh`
It will init **pacman**, then it will install: **sudo**, **git** and **base-devel** packages.

### Now you are allowed to build your own arch packages. 
Example: [DGnet_arch_linux_repo](https://github.com/andriykutsevol/DGnet_arch_linux_repo)
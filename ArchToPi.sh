#!/bin/bash
set -e
# Any subsequent(*) commands which fail will cause the shell script to exit immediately


## Some configuration

INSTALL_DEVICE=$1

## Wireless settings
WIRELESS_INTERFACE="wlan0"
WIRELESS_ESSID="TP-Link_6611"
WIRELESS_KEY="26685250"

##</> Some configuration



if [[ $EUID -ne 0 ]]; then
   echo "Error. This script must be run as root" 
   exit 1
fi


if [ $# -eq 0 ]
  then
    echo "Usage: ArchToPi.sh /dev/xyz"
    echo "You have to pass the SD card device name (/dev/...)"
    exit 1
fi

if [ $# -gt 1 ]
  then
    echo "Usage: ArchToPi.sh /dev/xyz"
    echo "You have to pass exactly one argument - SD card device name (/dev/...)"
    exit 1
fi



if [ ! -b "$INSTALL_DEVICE" ]; then
    printf "ERROR: INSTALL_DEVICE is not a block device ('%s')\n" "$INSTALL_DEVICE"
    exit 1
fi



doFlush() {
    echo "Syncing"
    sync
    sync
    sync
}


## Check installation directories
doUmount(){
  umount $1
  echo "OK $1 unmounted"
}


doCheckIfMounted(
  if mountpoint "$1" | grep -q 'is a mountpoint'; then
    echo ".$1 is mounted"
      read -p "Try to unmount? [y/n]: " yn
      case $yn in
          [Yy]* ) doUmount "$1";;
          [Nn]* ) echo "You have to umount $1"; exit;;
          * ) echo "Please answer y or n.";;
      esac
  fi
}


doCheckDirectory(){

  if [ -d "$1" ] 
  then
      doCheckIfMounted "$1"
  else
      mkdir "$1"
  fi

  doFlush

}


doCheckDirectory "./boot"
doCheckDirectory "./root"
##</end> Check installtion directories

## Wipe Device
echo "Clearing '$INSTALL_DEVICE' - ALL DATA ON IT WILL BE LOST!"
echo "Enter 'Y' (in capital) to confirm and start clearing the device"

read -r i
if [ "$i" != "Y" ]; then
    echo "Aborted."
    exit 0
fi

dd if=/dev/zero of="$INSTALL_DEVICE" bs=1M count=1

doFlush
##</end> Wipe Device


## Create Partitions
parted "$INSTALL_DEVICE" --script mklabel msdos   # Create Partition Table
parted -a optimal "$INSTALL_DEVICE" --script mkpart primary fat32 1m 512m
parted -a optimal "$INSTALL_DEVICE" --script mkpart primary ext4 512m 100%

doFlush
##</end> Create Partitions



## Create filesystems
doGetAllPartitions() {
    lsblk -l -n -o NAME -x NAME "$INSTALL_DEVICE" | grep "^$INSTALL_DEVICE_FILE" | grep -v "^$INSTALL_DEVICE_FILE$"
}


INSTALL_DEVICE_PATH="$(dirname "$INSTALL_DEVICE")"
INSTALL_DEVICE_FILE="$(basename "$INSTALL_DEVICE")"

doDetectDevices() {
    local ALL_PARTITIONS=($( doGetAllPartitions ))

    BOOT_DEVICE="$INSTALL_DEVICE_PATH/${ALL_PARTITIONS[0]}"
    ROOT_DEVICE="$INSTALL_DEVICE_PATH/${ALL_PARTITIONS[1]}"

}


doMkfs() {
    case "$1" in
        fat32)
            mkfs.vfat -F 32 -n "$2" "$3"
            ;;

        *)
            mkfs.ext4 -F -L "$2" "$3"
            ;;
    esac
}



BOOT_LABEL="boot"
ROOT_LABEL="root"
BOOT_FILESYSTEM="fat32"
ROOT_FILESYSTEM="ext4"

doFormat() {
    doMkfs "$BOOT_FILESYSTEM" "$BOOT_LABEL" "$BOOT_DEVICE"
    doMkfs "$ROOT_FILESYSTEM" "$ROOT_LABEL" "$ROOT_DEVICE"
}

doMount() {
    mount "$ROOT_DEVICE" ./root
    mount "$BOOT_DEVICE" ./boot
}



doDetectDevices
doFormat
doFlush
doMount
doFlush
##</end> Create filesystems




## Download archive if it does not exsists
ARCHIVE="./ArchLinuxARM-rpi-4-latest.tar.gz"
if [ ! -f "$ARCHIVE" ]; then
    wget http://os.archlinuxarm.org/os/ArchLinuxARM-rpi-4-latest.tar.gz
fi
##</end> Download archive if it does not exsists



## Unpack archive
tar xvf "ArchLinuxARM-rpi-4-latest.tar.gz" -C ./root -p

mv ./root/boot/* boot

doFlush
##</end> Unpack archive




## Basic settings
HOSTNAME="pi"
cat > ./root/etc/hostname << __END__
$HOSTNAME
__END__


# /usr/share/zoneinfo
TIMEZONE="Europe/Zaporozhye"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" ./root/etc/localtime


# localectl list-keymaps
# localectl list-keymaps | grep -i search_term
# find /usr/share/kbd/keymaps/ -type f -name "*search_term*"

CONSOLE_KEYMAP="us"

# https://wiki.archlinux.org/title/Linux_console#Fonts
# ls -l /usr/share/kbd/consolefonts/ | grep -i ".psfu.gz"
# http://www.zap.org.au/projects/console-fonts-distributed/
# https://alexandre.deverteuil.net/docs/archlinux-consolefonts/
CONSOLE_FONT="lat9w-16"

cat > root/etc/vconsole.conf << __END__
KEYMAP=$CONSOLE_KEYMAP
FONT=$CONSOLE_FONT
__END__
##</end> Basic settings



#doFixLinkIsNotReady
# Raspberry Pi 4
# https://github.com/raspberrypi/linux/issues/3108#issuecomment-723550749
sed -i 's/^\(MODULES=\)()$/\1(bcm_phy_lib broadcom mdio_bcm_unimac genet)/g' root/etc/mkinitcpio.conf



# #doClearNetwork
rm -f "./root/etc/systemd/network/en*.network"
rm -f "./root/etc/systemd/network/eth*.network"



### doSetWirelessDhcp
cat > "root/etc/systemd/network/$WIRELESS_INTERFACE.network" << __END__
    [Match]
    Name=$WIRELESS_INTERFACE

    [Network]
    DHCP=true
__END__


#### DISABLE_IPV6
cat >> "root/etc/systemd/network/$WIRELESS_INTERFACE.network" << __END__
IPv6AcceptRouterAdvertisements=false
__END__

cat > root/etc/sysctl.d/40-ipv6.conf << __END__
ipv6.disable_ipv6=1
__END__
####</end> DISABLE_IPV6
###</end> doSetWirelessDhcp


### doEnableWireless
echo -n > "./root/etc/wpa_supplicant/wpa_supplicant-$WIRELESS_INTERFACE.conf"

cat >> "./root/etc/wpa_supplicant/wpa_supplicant-$WIRELESS_INTERFACE.conf" << __END__
network={
    ssid="$WIRELESS_ESSID"
    psk="$WIRELESS_KEY"
}
__END__


chmod 0640 "./root/etc/wpa_supplicant/wpa_supplicant-$WIRELESS_INTERFACE.conf"
ln -s "./root/usr/lib/systemd/system/wpa_supplicant@.service" "root/etc/systemd/system/multi-user.target.wants/wpa_supplicant@$WIRELESS_INTERFACE.service"
###</end> doEnableWireless
##</end> Wireless settings





# ## Ethernet settings
# ETHERNET_INTERFACE="eth0"

# cat > "./root/etc/systemd/network/$ETHERNET_INTERFACE.network" << __END__

# [Match]
# Name=$ETHERNET_INTERFACE

# [Network]
# DHCP=true

# __END__




# # Disable IPV6
# cat >> "./root/etc/systemd/network/$ETHERNET_INTERFACE.network" << __END__
# IPv6AcceptRouterAdvertisements=false
# __END__

# cat > root/etc/sysctl.d/40-ipv6.conf << __END__
# ipv6.disable_ipv6=1
# __END__


# cat > ./root/etc/sysctl.d/40-ipv6.conf << __END__
# ipv6.disable_ipv6=1
# __END__
# ##</end> Ethrnet settings



## Let's create ~/.bash_logout
# Upon logout, the commands in ~/.bash_logout are executed, 
#which can for instance clear the terminal,
cat >> ./root/root/.bash_logout << __END__
clear
__END__
##</end> Let's create ~/.bash_logout


## SSH config
cat >> ./root/etc/ssh/ssh_config << __END__
Host *
  PubkeyAcceptedKeyTypes=ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa
__END__

cat >> ./root/etc/ssh/sshd_config << __END__
RSAAuthentication yes
PubkeyAuthentication yes
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAcceptedKeyTypes=ecdsa-sha2-nistp256-cert-v01@openssh.com,ecdsa-sha2-nistp384-cert-v01@openssh.com,ecdsa-sha2-nistp521-cert-v01@openssh.com,ssh-ed25519-cert-v01@openssh.com,rsa-sha2-512-cert-v01@openssh.com,rsa-sha2-256-cert-v01@openssh.com,ssh-rsa-cert-v01@openssh.com,ecdsa-sha2-nistp256,ecdsa-sha2-nistp384,ecdsa-sha2-nistp521,ssh-ed25519,rsa-sha2-512,rsa-sha2-256,ssh-rsa
__END__
##</end> SSH config


## Bug fixing
## https://archlinuxarm.org/forum/viewtopic.php?f=9&t=14792
sed -i '/session   optional   pam_systemd.so/d' ./root/etc/pam.d/system-login
##</end> Bug fixing



##  Create a dgnet user with a 1234 password
echo "dgnet:x:1001:1001:Dgnet:/home/dgnet:/bin/bash" >> ./root/etc/passwd
echo "dgnet:x:1001" >> ./root/etc/group
mkdir ./root/home/dgnet
chmod 755 ./root/home/dgnet
chown 1001:1001 ./root/home/dgnet
pass=`python3 -c 'import crypt; print (crypt.crypt("1234", "$6$salt1234"))'`
echo "dgnet:${pass}:::::::" >> ./root/etc/shadow
chmod 600 ./root/etc/shadow
##</end>  Create a dgnet user with a 1234 password



## Also let's add our ssh keys
mkdir ./root/home/dgnet/.ssh
chown 1001:1001 ./root/home/dgnet/.ssh
chmod 700 ./root/home/dgnet/.ssh

cat ./ssh/dgnet_alarm.pub >> ./root/home/dgnet/.ssh/authorized_keys
chown 1001:1001 ./root/home/dgnet/.ssh/authorized_keys
chmod 400 ./root/home/dgnet/.ssh/authorized_keys
##</end> Also let's add our ssh key


## Disable audit
kernel_cmdline="root=/dev/mmcblk0p2 rw rootwait console=ttyAMA0,115200 console=tty1 selinux=0 plymouth.enable=0 smsc95xx.turbo_mode=N dwc_otg.lpm_enable=0 kgdboc=ttyAMA0,115200 audit=0"
echo "${kernel_cmdline}" > ./root/boot/cmdline.txt
echo "${kernel_cmdline}" > ./boot/cmdline.txt
##</end> Disable audit



## Copy the post installation script
cp ./ArchToPi_PostInstall.sh ./root/root/
##</end>



doFlush
umount "$BOOT_DEVICE"
umount "$ROOT_DEVICE"

# To remove old key from known_hosts on this host.
ssh-keygen -R 192.168.0.105


echo "DONE"










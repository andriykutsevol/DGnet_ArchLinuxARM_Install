#!/bin/bash
set -e

## To sync SD card
doFlush() {
    echo "Syncing"
    sync
    sync
    sync
}
##</end> To sync SD card


## Init pacman
pacman-key --init
pacman-key --populate archlinuxarm
pacman -Syu --noconfirm
##</> Init pacman

doFlush

## Install the sudo package
pacman -S sudo --noconfirm
sed -i '/root ALL=(ALL) ALL/a dgnet ALL=(ALL) ALL' /etc/sudoers
##</end> Install the sudo package


## Install the base-devel package
pacman -S base-devel --noconfirm
##</> Install the base-devel package

## Install the git package
pacman -S git --noconfirm
##</> Install the git package

doFlush

pacman -S python3 --noconfirm

pacman -S python-pip --noconfirm

pacman -S python-wheel --noconfirm

pacman -S python-setuptools --noconfirm


# OR
# curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py
# python3 get-pip.py
# python3 -m pip --version

doFlush
echo "Done"
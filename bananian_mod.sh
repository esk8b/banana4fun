#!/bin/bash

# Script für Anpassungen und Konfiguration des Bananian Images
#
# Auchtung, das Script ist noch nicht voll funktionsfähig
# Im Script sind mehrere Stellen mit TODO markiert
#
# Das Script ist Vorbereitung für die Automation beim Bootstrapping eines eigenen Images
# oder für die automatisierte Anpassungen über die Installation eines deb-Pakets
#

######################################
# Versionscheck
######################################
[ -f /etc/bananian_version ] && BANANIAN_VERSION=$(cat /etc/bananian_version) || BANANIAN_VERSION=140801
if [ $BANANIAN_VERSION -lt 150101 ]; then
  echo -e "\033[0;31mThis version requires Bananian Linux 15.01 (or later). Exiting\033[0m"
  exit
fi


######################################
# Bash Profile anpassen
######################################

# Bash als default Shell einstellen
chsh -s /bin/bash

cat <<EOT > /etc/profile.d/eigene.sh
umask 022

eval "`dircolors`"

export PS1='\[\033[00;30m\]\[\033[47m\]\h [\D{%d.%m.%y} \t]\[\033[40m\] \[\033[01;33m\]\w \[\033[01;35m\]\$ \[\033[00m\]'

alias l='ls -lAh --color=auto'
alias ..='cd ..'
alias grep='grep --color'
alias netstat='netstat -ntplue'

export HISTSIZE=99999999
export HISTFILESIZE=
export HISTTIMEFORMAT='[%d.%m.%y %H:%M] '
EOT


######################################
# Hardware auf bananapro einstellen
######################################

# prepare tmp dir
TMPDIR=$(mktemp -d)

# mount /dev/mmcblk0p1
mkdir ${TMPDIR}/mnt
mount /dev/mmcblk0p1 ${TMPDIR}/mnt

# fex dir
FEXDIR="${TMPDIR}/mnt/fex"
BANANIAN_PLATFORM="BananaPro"

if [[ -f ${FEXDIR}/${BANANIAN_PLATFORM}/script.bin ]]; then {
  cp ${FEXDIR}/${BANANIAN_PLATFORM}/script.bin ${TMPDIR}/mnt/script.bin
  echo $BANANIAN_PLATFORM > /etc/bananian_platform
  echo -e "Hardware configuration has been set to: ${BANANIAN_PLATFORM}. Please reboot your system!"
} else {
  echo -e "\033[0;31mscript.bin not found. exiting!\033[0m"
} 
fi

umount ${TMPDIR}/mnt && rm -rf $TMPDIR


######################################
# Bananian Image bugfixes
######################################
apt-get update; apt-get -y upgrade

# Workaround für nicht funktionierendes lokalisiertes keyboard layout 
apt-get -y install --reinstall console-data console-setup keyboard-configuration

#hostapd kompilieren damit wpa2 funktioniert
apt-get -y install hostapd git make gcc libc6-dev libssl-dev libnl-dev
TMPDIR=$(mktemp -d)
cd $TMPDIR
git clone git://w1.fi/srv/git/hostap.git
cd hostap/hostapd 
cp defconfig .config
make
cp hostapd /usr/sbin/hostapd
cp hostapd_cli /usr/sbin/hostapd_cli
cd
rm -rf $TMPDIR


######################################
# Powerbutton ACPI
######################################

apt-get -y install acpid

cat <<EOT >> /etc/acpi/events/button_power
event=button/power
action=/etc/acpi/shutdown.sh 
EOT

cat <<EOT >> /etc/acpi/shutdown.sh
#!/bin/bash
shutdown -h now
EOT
chmod +x /etc/acpi/shutdown.sh
/etc/init.d/acpid restart


######################################
# Keyboard Layout auf DE, Timezone
######################################
cat <<EOT > /etc/default/keyboard

# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""

BACKSPACE="guess"
EOT

echo "Europe/Berlin" > /etc/timezone


######################################
# Blinkende Grüne LED abschalten. Blinkt nur noch während dem Booten
######################################

#Test ob der Eintrag schon vorhanden ist
grep '^echo none > /sys/class/leds/green\\:ph24\\:led1/trigger' /etc/rc.local > /dev/null
if [ $? -ne 0 ];then

tmpdatei=$(tempfile)
grep -v "^exit 0$" /etc/rc.local > $tmpdatei
cat <<EOT >> $tmpdatei

# Turn off green LED
echo none > /sys/class/leds/green\:ph24\:led1/trigger

exit 0
EOT

cat $tmpdatei > /etc/rc.local
rm $tmpdatei

fi


######################################
# Tools installieren
######################################

# vim 
apt-get -y purge vim.tiny
apt-get -y install vim bash-completion

apt-get -y install unp unrar-free p7zip-full unzip

update-alternatives --set editor /usr/bin/vim.basic

cat <<EOT > /etc/vim/vimrc.local
syntax on
set background=dark
set ignorecase
set incsearch
set showcmd
set showmatch
set noai
EOT

#TODO Entscheiden ob augeas verwendet werden soll
# command line tool to manipulate configuration from the shell
#apt-get -y install augeas-tools


######################################
# .ssh/authorized_keys anlegen
######################################

mkdir /root/.ssh
> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

#TODO eigenen Public Key eintragen
#echo "" >> /root./.ssh/authorized_keys

#TODO root passwort ändern


######################################
# WLAN
######################################

# Wlan Modul aktivieren
grep '^ap6210' /etc/modules > /dev/null
if [ $? -ne 0 ];then
cat <<EOT >> /etc/modules

#wlan onboard chip
ap6210

EOT
modprobe ap6210
fi

# Netzwerk konfigurieren.
# eth0 wird nicht beim booten gestartet
# wlan0 auf feste IP
cat <<EOT > /etc/network/interfaces_ap
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

#auto eth0
iface eth0 inet dhcp

auto wlan0
allow-hotplug wlan0
iface wlan0 inet static
address 192.168.123.1
netmask 255.255.255.0
broadcast 192.168.123.255
EOT


#TODO SSID und wpa_passphrase ändern sobald Projektname feststeht
# AP-Mode http://w1.fi/hostapd/

cat <<EOT > /etc/hostapd/hostapd.conf
interface=wlan0
ssid=esk8b
channel=1
ignore_broadcast_ssid=0
country_code=DE
ieee80211d=1
hw_mode=g
beacon_int=100
dtim_period=2
macaddr_acl=0
max_num_sta=20
rts_threshold=2347
fragm_threshold=2346
#logger_syslog=-1
#logger_syslog_level=0
#logger_stdout=-1
#logger_stdout_level=2
dump_file=/tmp/hostapd.dump
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0
auth_algs=1
wmm_enabled=0
wpa=2
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP
wpa_pairwise=TKIP
wpa_passphrase=12345678
EOT

cat <<EOT > /etc/network/interfaces_client
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

#auto eth0
iface eth0 inet dhcp

auto wlan0
allow-hotplug wlan0

# WLAN Client Mode
iface wlan0 inet dhcp
wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
EOT

cat <<EOT > /etc/wpa_supplicant/wpa_supplicant.conf
ctrl_interface=/var/run/wpa_supplicant
ctrl_interface_group=root
eapol_version=1
ap_scan=1

network={
        ssid="BeispielFunknetzwerk1"
        scan_ssid=1
        proto=RSN
        key_mgmt=WPA-PSK
        pairwise=CCMP
        group=CCMP
        psk="Passphrase des Funknetzwerks"
}

network={
        ssid="BeispielFunknetzwerk2"
        scan_ssid=1
        proto=RSN
        key_mgmt=WPA-PSK
        pairwise=CCMP
        group=CCMP
        psk="Passphrase des Funknetzwerks"
}
EOT

ln -s /etc/network/interfaces_ap /etc/network/interfaces

# dhcpd
apt-get -y install dnsmasq

#TODO Dateiname der Config ändern sobald Projektname feststeht
#Config schreiben
cat <<EOT > /etc/dnsmasq.d/esk8b.conf
interface=wlan0
no-dhcp-interface=eth0
dhcp-range=interface:wlan0,192.168.123.100,192.168.123.200,infinite
EOT

#TODO wenn SSID von bekanntem Netz in Reichweite dann verbinden, sonst AP-Mode
#TODO Button für manuelles umstellen des WLAN Modess


######################################
# Teensy Loader
######################################
#http://www.pjrc.com/teensy/loader_cli.html

#TODO halfkey .. jump to bootloader im teensy
#http://www.pjrc.com/teensy/jump_to_bootloader.html


apt-get install libusb-dev
TMPDIR=$(mktemp -d); cd $TMPDIR
wget http://www.pjrc.com/teensy/teensy_loader_cli.2.1.zip
unp teensy_loader_cli.2.1.zip
cd teensy_loader_cli
make
cp teensy_loader_cli /usr/local/bin/
cd $HOME
rm -rf $TMPDIR

cat <<EOT > /etc/udev/rules.d/49-teensy.rules
# UDEV Rules for Teensy boards, http://www.pjrc.com/teensy/
#
# The latest version of this file may be found at:
#   http://www.pjrc.com/teensy/49-teensy.rules
#
# This file must be placed at:
#
# /etc/udev/rules.d/49-teensy.rules    (preferred location)
#   or
# /lib/udev/rules.d/49-teensy.rules    (req'd on some broken systems)
#
# To install, type this command in a terminal:
#   sudo cp 49-teensy.rules /etc/udev/rules.d/49-teensy.rules
#
# After this file is installed, physically unplug and reconnect Teensy.
#
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789]?", ENV{ID_MM_DEVICE_IGNORE}="1"
ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789]?", ENV{MTP_NO_PROBE}="1"
SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789]?", MODE:="0666"
KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789]?", MODE:="0666"
#
# If you share your linux system with other users, or just don't like the
# idea of write permission for everybody, you can replace MODE:="0666" with
# OWNER:="yourusername" to create the device owned by you, or with
# GROUP:="somegroupname" and mange access using standard unix groups.
#
#
# If using USB Serial you get a new device each time (Ubuntu 9.10)
# eg: /dev/ttyACM0, ttyACM1, ttyACM2, ttyACM3, ttyACM4, etc
#    apt-get remove --purge modemmanager     (reboot may be necessary)
#
# Older modem proding (eg, Ubuntu 9.04) caused very slow serial device detection.
# To fix, add this near top of /lib/udev/rules.d/77-nm-probe-modem-capabilities.rules
#   SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789]?", GOTO="nm_modem_probe_end" 
#
EOT



######################################
# GPIO wiringBP
######################################
#http://wiki.lemaker.org/WiringPi
#http://wiringpi.com

TMPDIR=$(mktemp -d); cd $TMPDIR
apt-get install git-core sudo make gcc libc6-dev libc-dev
git clone https://github.com/LeMaker/WiringBP.git -b bananapro
cd WiringBP
chmod +x build
./bulid
cd $HOME
rm -rf $TMPDIR









exit 0

######################################
# TODO
######################################

# alle ungenutzen dinge abschalten, alles schlank und stromsparend machen, kernel module, hw schnittstellen ...
# sbc performance daten? munin?


# public wlan mit zugriff auf definierte freigaben?
# smb server mit public upload, nützlich bei events um fotos videos zu speichern?



######################################
# GPS Modul
######################################
#GPS 
#http://raspberry.tips/raspberrypi-tutorials/gps-modul-mit-dem-raspberry-pi-ortung-und-navigation/
#http://linlog.blogspot.de/2009/07/synchronizing-ntp-server-to-gpspps.html
apt-get -y install gpsd gpsd-clients
#cgps -s
#gpsmon

cat <<EOT > /etc/default/gpsd
# Default settings for gpsd.
# Please do not edit this file directly - use `dpkg-reconfigure gpsd' to
# change the options.
START_DAEMON="true"
GPSD_OPTIONS="-n -G"
DEVICES="/dev/ttyS2"
USBAUTO="true"
GPSD_SOCKET="/var/run/gpsd.sock"
EOT

# GPS Uhrzeit
#http://raspberry.tips/raspberrypi-tutorials/raspberry-pi-uhrzeit-ueber-gps-beziehen-zeitserver/

# gps track aufzeichen gpxlogger > tracklog.gpx
#TODO GPS + Telemetriedaten in DB speichern 
#http://sgowtham.com/journal/2009/02/12/php-storing-gps-track-points-in-mysql/
#http://phpmygpx.tuxfamily.org/phpmygpx.php

TMPDIR=$(mktemp -d)
cd $TMPDIR
wget --post-data "file=phpMyGPX-0.7.tar.bz2&country=de&submit=Download" http://phpmygpx.tuxfamily.org/force_download.php -O phpMyGPX-0.7.tar.bz2
unp phpMyGPX-0.7.tar.bz2
mv phpmygpx /var/www/
cd
rm -rf $TMPDIR
chown -R root:www-data /var/www/phpmygpx
chmod 775 /var/www/phpmygpx

######################################
# IPv6 abschalten
######################################


######################################
# LAMP
######################################

apt-get -y install apache2 php5 php5-gd php5-mysql mysql-server 


######################################
# apt.esk8b.de Repository hinzufügen
######################################

cat <<EOT > /etc/apt/sources.list.d/apt.esk8b.de

EOT
apt-get update

######################################
# Sprachausgabe mp3 Wiedergabe
######################################

apt-get -y install alsa alsa-utils espeak jackd2 mpg321




######################################
# Notitzen
######################################

# SPI i2c
http://raspberry.tips/raspberrypi-tutorials/raspberry-pi-spi-und-i2c-aktivieren/

# Eigenes Image
http://raspberry.tips/raspberrypi-tutorials/eigenes-raspbian-image-fuer-den-raspberry-pi-erstellen/
http://cbwebs.de/single-board-computer/banana-pi/install-debian-wheezy-on-your-banana-pi/

# webmin?
http://doxfer.webmin.com/Webmin/Main_Page
http://ajenti.org




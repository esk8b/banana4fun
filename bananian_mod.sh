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
if [ $BANANIAN_VERSION -lt 150101 ]; then {
        echo -e "\033[0;31mThis version requires Bananian Linux 15.01 (or later). Exiting\033[0m"
        exit
} fi


######################################
# Hardware auf bananapro einstellen
######################################


# prepare tmp dir
TMPDIR=$(mktemp -d)
cd $TMPDIR

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

# Workaround für nicht funktionierendes lokalisiertes keyboard layout 
apt-get -y install --reinstall console-data console-setup keyboard-configuration




######################################
# Blinkende Grüne LED abschalten. Blinkt nur noch während dem Booten
######################################

#Test ob der Eintrag schon vorhanden ist
grep '^echo none > /sys/class/leds/green\\:ph24\\:led1/trigger' /etc/rc.local > /dev/null
if [ $? -ne 0 ];then

tmpdatei = $(tempfile)
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
apt-get -y install vim

update-alternatives --set editor /usr/bin/vim.basic

#TODO Entscheiden ob augeas verwendet werden soll
# command line tool to manipulate configuration from the shell
#apt-get -y install augeas-tools

apt-get -y install bash-completion



######################################
# .ssh/authorized_keys anlegen
######################################

mkdir /root./.ssh
> /root./.ssh/authorized_keys
chmod 600 /root./.ssh/authorized_keys

#TODO eigenen Public Key eintragen
#echo "" >> /root./.ssh/authorized_keys

#TODO root passwort ändern

######################################
# WLAN in AP-Mode konfigurieren 
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
cat <<EOT > /etc/network/interfaces
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

#TODO FIX WPA2 funktioniert nicht
#TODO SSID und wpa_passphrase ändern sobald Projektname feststeht
# AP-Mode
apt-get -y install hostapd
cat <<EOT >> /etc/hostapd/hostapd.conf
# Schnittstelle und Treiber
interface=wlan0
driver=nl80211

# WLAN-Konfiguration
ssid=esk8b
channel=1

# ESSID sichtbar
ignore_broadcast_ssid=0

# Ländereinstellungen
country_code=DE
ieee80211d=1

# Übertragungsmodus
hw_mode=g

# Optionale Einstellungen
# supported_rates=10 20 55 110 60 90 120 180 240 360 480 540

# Draft-N Modus aktivieren / optional nur für entsprechende Karten
# ieee80211n=1

# Übertragungsmodus / Bandbreite 40MHz
# ht_capab=[HT40+][SHORT-GI-40][DSSS_CCK-40]

# Beacons
beacon_int=100
dtim_period=2

# MAC-Authentifizierung
macaddr_acl=0

# max. Anzahl der Clients
max_num_sta=20

# Größe der Datenpakete/Begrenzung
rts_threshold=2347
fragm_threshold=2346

# hostapd Log Einstellungen
logger_syslog=-1
logger_syslog_level=2
logger_stdout=-1
logger_stdout_level=2

# temporäre Konfigurationsdateien
dump_file=/tmp/hostapd.dump
ctrl_interface=/var/run/hostapd
ctrl_interface_group=0

# Authentifizierungsoptionen 
auth_algs=3

# wmm-Funktionalität
wmm_enabled=0

# Verschlüsselung / hier rein WPA2
wpa=2
rsn_preauth=1
rsn_preauth_interfaces=wlan0
wpa_key_mgmt=WPA-PSK
rsn_pairwise=CCMP

# Schlüsselintervalle / Standardkonfiguration
wpa_group_rekey=600
wpa_ptk_rekey=600
wpa_gmk_rekey=86400

# Zugangsschlüssel (PSK) / hier in Klartext (ASCII)
wpa_passphrase=esk8b.de

EOT


# dhcpd
apt-get -y install dnsmasq

#TODO Dateiname der Config ändern sobald Projektname feststeht
#Config schreiben
cat <<EOT >> /etc/dnsmasq.d/esk8b.conf
# DHCP-Server aktiv für Interface
interface=wlan0

# DHCP-Server nicht aktiv für Interface
no-dhcp-interface=eth0

# IP-Adressbereich / Lease-Time
dhcp-range=interface:wlan0,192.168.123.100,192.168.123.200,infinite
EOT

#TODO wenn SSID von bekanntem Netz in Reichweite dann verbinden, sonst AP-Mode
#TODO Button für manuelles umstellen des WLAN Modess






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














exit 0

######################################
# TODO
######################################

# vim einstellungen
# locals, keyboard
# alle ungenutzen dinge abschalten, alles schlank und stromsparend machen, kernel module, hw schnittstellen ...
# sbc performance daten? munin?


# public wlan mit zugriff auf definierte freigaben?
# smb server mit public upload, nützlich bei events um fotos videos zu speichern?

######################################
# Webserver
######################################

#nginx mit php5 xcache


######################################
# GPS Modul
######################################
# GPS Uhrzeit
#http://raspberry.tips/raspberrypi-tutorials/raspberry-pi-uhrzeit-ueber-gps-beziehen-zeitserver/


######################################
# IPv6 abschalten
######################################


######################################
# apt.esk8b.de Repository hinzufügen
######################################

cat <<EOT > /etc/apt/sources.list.d/apt.esk8b.de

EOT
apt-get update

######################################
# Sprachausgabe
######################################




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




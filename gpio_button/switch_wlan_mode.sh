#!/bin/bash

STATEFILE=/var/run/gpio_button
STATE=$(cat $STATEFILE)

if [ $STATE -eq 1 ];then
  # AP
  echo "1 wlan ap"
  service networking stop
  rm /etc/network/interfaces
  ln -s /etc/network/interfaces_ap /etc/network/interfaces
  service networking start
  service hostapd start
  service dnsmasq start
elif [ $STATE -eq 2 ];then
  # Client
  echo "2 wlan client"
  service hostapd stop
  service dnsmasq stop
  service networking stop
  rm /etc/network/interfaces
  ln -s /etc/network/interfaces_client /etc/network/interfaces
  service networking start
elif [ $STATE -eq 3 ];then
  # WLAN aus
  echo "3 wlan aus"
  service hostapd stop
  service dnsmasq stop
  #service networking stop
  ifdown wlan0
fi
#!/bin/bash

#http://kampis-elektroecke.de/?page_id=1659

IP=$(hostname -i)
SPRACHAUSGABE="Wer das liest ist doof"
STATEFILE=/var/run/gpio_button
WATCHFILE=/sys/class/gpio/gpio17/value
GPIOVALUE_VORHER=$(cat $WATCHFILE)
GPIOVALUE_VORHER=$(gpio -g read 17)
echo "down" > /sys/class/gpio/gpio17/pull
#inotifywait -qq -e modify $WATCHFILE
#inotifywait -e modify $WATCHFILE
while [ `gpio -g read 17` = 0 ]; do
  sleep 0.1
done


GPIOVALUE=$(cat $WATCHFILE)
GPIOVALUE=$(gpio -g read 17)
echo $GPIOVALUE

if [ $GPIOVALUE_VORHER -eq 0 -a $GPIOVALUE -eq 1 ];then


if [ -s $STATEFILE ];then #datei vorhanden und nicht leer
  STATE=$(cat $STATEFILE)
  if [ $STATE -eq 1 ];then # Mit WLAN Verbinden
    NEWSTATE=2
    SPRACHAUSGABE="wlan verbunden! ei pie ist: $IP"
  fi
  if [ $STATE -eq 2 ];then # WLAN aus
    NEWSTATE=3
    SPRACHAUSGABE="wlan aus"
  fi
  if [ $STATE -eq 3 ];then # AP Modus
    NEWSTATE=1
    SPRACHAUSGABE="eckzess point gestartet! es es ei die ist: e s k 8 b"
  fi
else #standard Modus wechsel von 1 auf 2
  NEWSTATE=2
  SPRACHAUSGABE="wlan verbunden! ei pie ist: $IP"
fi

echo $NEWSTATE > $STATEFILE
#./switch_wlan_mode.sh
echo $SPRACHAUSGABE
espeak -vde --punct="." "$SPRACHAUSGABE" &> /dev/null 
fi

#sich selbst aufrufen
exec $0


#!/bin/sh

# tempdir zum bauen erstellen
TMPDIR=$(mktemp -d)
cd $TMPDIR

# git clone
git clone https://github.com/LeMaker/WiringBP.git -b bananapro

cd WiringBP

grep VERSION gpio/gpio.c

VERSION=2.20

mv gpio gpio-$VERSION

tar -zcf gpio-$VERSION.tar.gz gpio-$VERSION/

dh_make -s -p gpio-$VERSION -c gpl --createorig -f ../gpio-$VERSION.tar.gz

cd debian
rm *.ex *.EX README.*

vi changelog 

vi control

Section: devel
Priority: standard
Homepage: http://wiki.lemaker.org/WiringPi
Vcs-Git: https://github.com/LeMaker/WiringBP.git -b bananapro
Vcs-Browser: https://github.com/LeMaker/WiringBP

Architecture: armhf

Description: GPIO command-line utility for banana pro
 This is a modified WiringPi for Banana Pro. We call it WiringBP.
 It is based on the original WiringPi for Raspberry Pi created by Drogon.
 The modification is done by LeMaker. The WiringBP API usage are the same to the original wiringPi.
 http://wiringpi.com http://wiki.lemaker.org/WiringPi

cd ..

dpkg-buildpackage -us -uc
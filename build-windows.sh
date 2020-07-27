#!/bin/bash
set -e

ROOT=`pwd`

if [ ! -f ./build/vs2017_15.8.4 ]; then
  echo 'Windows 10 SDK must be available at build/vs2017_15.8.4'
  exit 1
fi

if [ ! -f ./build/makecab.exe ]; then
  echo 'makecab.exe must be available at build/makecab.exe'
  exit 1
fi

# copy resources from mozilla source which we need for docker build
cp ./mozilla-release/taskcluster/scripts/misc/fetch-content ./build/
# mkdir -p docker/liblowercase
# cp -r mozilla-release/build/liblowercase/* docker/liblowercase
# cp mozilla-release/taskcluster/scripts/misc/build-liblowercase.sh docker/liblowercase

# build base image
cd build
docker build -f Base.dockerfile -t ua-build-base ./

# fetch windows build resources
# TODO vs2017_15.8.4.zip
# TODO makecab.exe

# build windows image
docker build -f Windows.dockerfile -t ua-build-win ./

cd ../
# prepare vfat drive for case insensitive Win10 SDK volume
if [ ! -f /tmp/vfat ]; then
  truncate -s 2G /tmp/vfat
  LOOP=/dev/loop7
  if [ ! -b $LOOP ]; then
    sudo mknod $LOOP -m0660 b 7 9
  fi
  sudo losetup $LOOP /tmp/vfat
  sudo mkfs.vfat $LOOP
  sudo mkdir /mnt/vfat
  sudo mount -t vfat -o rw,uid=$UID $LOOP /mnt/vfat
fi

# extract vs2017 to vfat drive
if [ ! -d /mnt/vfat/vs2017_15.8.4 ]; then
  cp build/vs2017_15.8.4.zip /mnt/vfat/
  cd /mnt/vfat/
  unzip vs2017_15.8.4.zip
  rm vs2017_15.8.4.zip
fi

cd $ROOT

# launches docker image with workspace and Win10 SDK mounted as volumes.
# to build do ./mach build at this prompt
docker run -v $ROOT/mozilla-release:/builds/worker/workspace \
  -v /mnt/vfat/vs2017_15.8.4/:/builds/worker/fetches/vs2017_15.8.4 \
  --env MOZCONFIG=/builds/worker/configs/win64.mozconfig \
  -it ua-build-win \
  /bin/bash
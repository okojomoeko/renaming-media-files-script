#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Select the directory where the images and videos are located" 1>&2
  exit 1
fi

if !(type "exiftool" > /dev/null 2>&1); then
  echo "exiftool is not found"
  exit 1
fi

exiftool -api QuickTimeUTC -api largefilesupport=1 -execute "-FileName<CreateDate" -d "IMG_%Y%m%d_%H%M%S%%-c.%%e" -ext jpg -ext png -ext+ hsp -ext+ heic $1 -execute "-Directory<CreateDate" -d "$1/IMG/%Y-%m-%d" -ext jpg -ext png -ext+ hsp -ext+ heic $1;
exiftool -api QuickTimeUTC -api largefilesupport=1 -execute "-FileName<CreateDate" -d "VID_%Y%m%d_%H%M%S%%-c.%%e" -ext MP4 -ext MOV $1 -execute "-Directory<CreateDate" -d "$1/VID/%Y-%m-%d" -ext MP4 -ext MOV $1;

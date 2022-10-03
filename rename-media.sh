#!/bin/bash

if [ $# -ne 1 ]; then
  echo "Select the directory where the images and videos are located" 1>&2
  exit 1
fi

if !(type "exiftool" > /dev/null 2>&1); then
  echo "exiftool is not found"
  exit 1
fi


imgregex="jpg|png|hsp"
vidregex="mp4|mov"

echo $1
filenames=$( find $1 -maxdepth 1 -type f | grep -i -E ".*($imgregex|$vidregex)" )

count=1
tempRenamedFile=""

for eachValue in $filenames; do
  ext=$( echo "$eachValue" | sed -e "s/.*\.//")

  prefix=""
  if [ $( echo $ext | grep -i -E "$imgregex" ) ]; then
    prefix="IMG"
  elif [ $( echo $ext | grep -i -E "$vidregex" ) ]; then
    prefix="VID"
  fi
  current=$( dirname $eachValue)
  # echo $eachValue
  res=$(exiftool -api QuickTimeUTC -api largefilesupport=1 -CreateDate "$eachValue")
  # echo $res

  timestamp=$( echo "$res" | sed -e "s/.*\([0-9]\{4\}\):\([0-9]\{2\}\):\([0-9]\{2\}\) \([0-9]\{2\}\):\([0-9]\{2\}\):\([0-9]\{2\}\).*/\1\2\3_\4\5\6/")

  dirname=$( echo "$timestamp" | sed -e "s/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\).*/\1-\2-\3/" )

  if [ ! -d "$current/$prefix/$dirname" ]; then
    mkdir -p "$current/$prefix/$dirname"
  fi

  renamedfile=$(echo "$prefix"_"$timestamp")

  if [ "$renamedfile" = "$tempRenamedFile" ]; then
    renamedfile="${renamedfile}_${count}.$ext"
    let count++
  else
    tempRenamedFile=$renamedfile
    renamedfile="${renamedfile}.$ext"
    count=1
  fi

  echo "$current/$prefix/$dirname/$renamedfile"

  mv "$eachValue" "$current/$prefix/$dirname/$renamedfile"

done

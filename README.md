# renaming-media-files-script

## Description

The script that renames media files.

## Demo

## Requirement

- `exiftool`
  - `sudo apt install exiftool`

## Usage

example directory

```
temp
|--IMG_20210610_191943.jpg
|--IMG_20210610_191959.jpg
|--IMG_20210610_191959_1.png
|--IMG_20210610_191959_2.jpg
|--mov_hts-samp001.mp4
```

run script

```
$ bash ./rename-media.sh ~/temp

/home/vagrant/temp/IMG/2021-06-10/IMG_20210610_191943.jpg
/home/vagrant/temp/IMG/2021-06-10/IMG_20210610_191959.jpg
/home/vagrant/temp/IMG/2021-06-10/IMG_20210610_191959_1.png
/home/vagrant/temp/IMG/2021-06-10/IMG_20210610_191959_2.jpg
/home/vagrant/temp/VID/2017-09-11/VID_20170911_154935.mp4
```

after script run

```
temp
|--IMG
|  |--2021-06-10
|  |  |--IMG_20210610_191943.jpg
|  |  |--IMG_20210610_191959.jpg
|  |  |--IMG_20210610_191959_1.png
|  |  |--IMG_20210610_191959_2.jpg
|--VID
|  |--2017-09-11
|  |  |--VID_20170911_154935.mp4
```

## Install

## Contribution

## Licence

## Author

[okojomoeko](https://gitlab.com/okojomoeko)

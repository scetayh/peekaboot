# PeekABoot v0.1.1

A lightweight GRUB theme previewer via QEMU.

## Installation

Clone this repository, then just `make` this project:

``` bash
make
sudo make install
```

This will copy the `peekaboot.sh` script to an executive `peekaboot` file, and install the latter to `/usr/local/bin`.

## Usage

```
Usage: /usr/local/bin/peekaboot [ options ] [ <theme directory> ]
A lightweight GRUB theme previewer via QEMU
If not specified, <theme directory> will be the current directory.

Options:
  -h, --help
         Display this help and exit.
  -V, --version
         Output version information and exit.
  -r, --resolution <integer>x<integer>
         Specify the resolution of QEMU VM in GFX mode (default: 1920x1080).
  -t, --timeout <seconds>
         Specify the GRUB period seconds (default: 60).

Examples:
  /usr/local/bin/peekaboot -r 1920x1080 ~/hello/Projects/my-grub-theme
  /usr/local/bin/peekaboot ~/hello/Projects/my-grub-theme
```
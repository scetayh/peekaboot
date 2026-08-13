# PeekABoot v0.1.0

```
Usage: peekaboot [ options ] [ argument ]
A lightweight GRUB theme previewer via QEMU.
<argument> will be the current directory if not assigned.

Options:
  -r, --resolution <integer>x<integer>      Set resolution of QEMU VM under GFX
                                            mode (default: 1920x1080).
  -h, --help                                Display usage.
  -V, --version                             Display version.

Examples:
  $0 -r 1920x1080 ~/hello/Projects/my-grub-theme
  $0 ~/hello/Projects/my-grub-theme
```
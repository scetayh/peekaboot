#!/usr/bin/env bash
set -Eeo pipefail
shopt -s inherit_errexit
export LANG=C.UTF-8
export LC_ALL=C.UTF-8
IFS=$'\n\t'

readonly VERSION=0.1.1

echo_err() {
    echo "Error: $*" >&2
}

usage() {
    cat >&2 << EOF
Usage: $0 [ options ] [ <theme directory> ]
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
  $0 -r 1920x1080 ~/hello/Projects/my-grub-theme
  $0 ~/hello/Projects/my-grub-theme
EOF
}

main() {
    opt_short=hVr:t:
    opt_long=help,version,resolution:,timeout:

    opt="$(getopt -o "$opt_short" -l "$opt_long" -n "$0" -- "$@")"
    eval set -- "$opt"

    has_flag_h=0
    has_flag_V=0
    has_option_r=0
    option_r_value=""
    has_option_t=0
    option_t_value=""

    while true; do
        case "$1" in
            -h|--help)
                has_flag_h=1
                shift 1
                ;;
            -V|--version)
                has_flag_V=1
                shift 1
                ;;
            -r|--resolution)
                has_option_r=1
                option_r_value="$2"
                shift 2
                ;;
            -t|--timeout)
                has_option_t=1
                option_t_value="$2"
                shift 2
                ;;
            --)
                shift 1
                break
                ;;
            *)
                echo_err "unparsed option '$1'"
                return 1
                ;;
        esac
    done

    (( has_flag_V )) && {
        echo $VERSION
        return 0
    }
    (( has_flag_h )) && {
        usage
        return 0
    }

    [[ $# -eq 0 ]] || [[ $# -eq 1 ]] || {
        echo_err "too many arguments"
        return 1
    }

    [[ $# -eq 1 ]] && {
        [[ ! -f "$1" ]] || {
            echo_err "'$1' is a file"
        }

        [[ -d "$1" ]] || {
            echo_err "'$1' do not exist"
        }
    }

    (( has_option_r )) && {
        [[ "$option_r_value" =~ ^[0-9]+x[0-9]+$ ]] || {
            echo_err "invalid resolution '$option_r_value'"
            return 1
        }
    }
    
    (( has_option_t )) && {
        [[ "$option_t_value" -gt 0 ]] &> /dev/null || {
            echo_err "invalid timeout seconds '$option_t_value'"
            return 1
        }
    }
    
    src_dir=
    theme=
    resolution=
    tmp=
    iso_root=
    grub_dir=
    grub_theme_dir=
    grub_this_theme_dir=
    timeout=
    iso=
    arch=

    [[ $# -eq 0 ]] && \
        src_dir=.
    [[ $# -eq 1 ]] && \
        src_dir="$1"
    
    theme="$(basename "$src_dir")"

    if (( has_option_r )); then
        resolution=$option_r_value
    else
        resolution=1920x1080
    fi

    tmp=$(mktemp -d "/tmp/peekaboot.XXXXXXXXXX")
    iso_root=$tmp/iso_root
    grub_dir=boot/grub
    grub_theme_dir=$grub_dir/themes
    grub_this_theme_dir=$grub_theme_dir/$theme

    if (( has_option_t )); then
        timeout=$option_t_value
    else
        timeout=60
    fi

    iso=$tmp/grub.iso
    arch=$(arch)

    mkdir -p "$iso_root/$grub_theme_dir"

    cp -r "$src_dir" "$iso_root/$grub_theme_dir"

    {
        cat << EOF
set default=0
set_timeout=$timeout

insmod all_video
insmod gfxterm
insmod gfxmenu
insmod png
insmod font

set gfxmode=$resolution,auto
set gfxplayload=keep
terminal_output gfxterm

EOF

        find . -type f -name "*.pf2" -print0 2> /dev/null | \
            while IFS= read -r -d '' font; do
                echo "loadfont /$grub_dir/${font#./}"
            done
        
        cat << EOF

set theme=/$grub_this_theme_dir/theme.txt

menuentry 'Gentoo GNU/Linux' --class gentoo --class gnu-linux --class gnu --class os {
        echo    'Loading Linux 7.1.8 ...'
        echo    'Loading initial ramdisk...'
}
submenu 'Advanced options for Gentoo GNU/Linux' {
        menuentry 'Gentoo GNU/Linux, with Linux 7.1.8' --class gentoo --class gnu-linux --class gnu --class os {
                echo    'Loading Linux 7.1.8 ...'
                echo    'Loading initial ramdisk...'
        }
        menuentry 'Gentoo GNU/Linux, with Linux 7.1.8 (recovery mode)' --class gentoo --class gnu-linux --class gnu --class os {
                echo    'Loading Linux 7.1.8 ...'
                echo    'Loading initial ramdisk...'
        }
}
menuentry 'Gentoo GNU/Linux' --class gentoo --class gnu-linux --class gnu --class os {
        echo    'Loading Linux 7.1.8 ...'
        echo    'Loading initial ramdisk...'
}
submenu 'Advanced options for Gentoo GNU/Linux' {
        menuentry 'Gentoo GNU/Linux, with Linux 7.1.8' --class gentoo --class gnu-linux --class gnu --class os {
                echo    'Loading Linux 7.1.8 ...'
                echo    'Loading initial ramdisk...'
        }
        menuentry 'Gentoo GNU/Linux, with Linux 7.1.8 (recovery mode)' --class gentoo --class gnu-linux --class gnu --class os {
                echo    'Loading Linux 7.1.8 ...'
                echo    'Loading initial ramdisk...'
        }
}
menuentry "Restart" --class reboot --class restart {
    reboot
}
menuentry "Power off" --class shutdown --class poweroff --class halt {
    halt
}
EOF
    } > "$iso_root/$grub_dir/grub.cfg"
    
    grub-mkrescue -o "$iso" "$iso_root"

    "qemu-system-$arch" \
        -M virt -cpu cortex-a57 \
        -bios "/usr/share/qemu/edk2-$arch-code.fd" \
        -cdrom "$iso" \
        -device virtio-gpu-pci \
        -m 256M \
        -serial stdio \
        -display gtk
}

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    echo_err "Do not 'source' this script. You should run it directly."
    exit 1
else
    [[ "$DEBUG" -eq 1 ]] && \
        set -x
    main "$@"
    exit $?
fi
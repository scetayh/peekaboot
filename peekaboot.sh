#!/usr/bin/env bash

# ===== version =====

readonly VERSION=0.1.0

# ===== utility functions =====

if [[ -t 1 ]] && [[ -t 2 ]] && [[ "$(tput colors)" -ge 8 ]]; then
    readonly COLOR_RESET='\033[0m'
    readonly COLOR_WARN='\033[1;33m'
    readonly COLOR_ERROR='\033[1;31m'
fi

log_warn() {
    echo -e "${COLOR_WARN}warning:${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_ERROR}error:${COLOR_RESET} $*" >&2
}

log_error_parse_argument() {
    log_error "failed to parse argument"
}

print_usage() {
    cat << EOF
Usage: $0 [ options ] [ argument ]
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
EOF
}

# ===== check commands =====

for command in \
    cat getopt basename arch find grub-mkrescue;
do
    command -v -- "$command" &> /dev/null|| {
        log_error "command '$command' not found";
        exit 127;
    }
done

# ===== parse parameters =====

opt="$(getopt -o "r:hV" -l "resolution:,help,version" -n "$0" -- "$@")" || {
    log_error_parse_argument
    exit 127
}

eval set -- "$opt" || {
    log_error_parse_argument
    exit 127
}

while true; do
    case "$1" in
        -r|--resolution)
            RESOLUTION="$2"
            shift 2
            ;;
        -h|--help)
            shift
            print_usage
            exit 0
            ;;
        -V|--version)
            echo "$VERSION"
            exit 0
            ;;
        --)
            shift
            if [ $# -gt 1 ]; then
                log_error "too many arguments"
                exit 127
            elif [ $# -eq 1 ]; then
                SRC="$1"
                shift
            fi
            break
            ;;
        *)
            echo "unparsed option '$1'" >&2
            exit 1
            ;;
    esac
done

# ===== check variables =====

# RESOLUTION

if ! [[ "$RESOLUTION" =~ ^[0-9]+x[0-9]+$ ]]; then
    log_error "invalid resolution, '<integer>x<integer>' (e.g. 1920x1080) expected"
    exit 127
fi

[[ -z "$RESOLUTION" ]] && \
    RESOLUTION=1920x1080

# SRC

[[ ! -d "$SRC" ]] && {
    log_error "directory '$SRC' do not exist"
    exit 2
}

[[ -z "$SRC" ]] && \
    SRC=.

# THEME

THEME="$(basename "$SRC")" || {
    log_error "failed to parse directory name as theme name"
    exit 127
}

# TMP

TMP=$(mktemp -d "/tmp/peekaboot.XXXXXXXXXX") || {
    log_error "failed to create temporary directory"
    exit 127
}

# UNIFONT

UNIFONT=/usr/share/grub/unicode.pf2
[[ ! -f $UNIFONT ]] && \
    UNIFONT=""

# ARCH

ARCH=$(arch) || {
    log_error "failed to get architechture"
    exit 127
}

# ===== set constants =====

readonly RESOLUTION
readonly SRC
readonly THEME
readonly TMP
readonly ISO_ROOT="${TMP}/iso_root"
readonly ISO="${TMP}/${THEME}.iso"
readonly GRUB_DIR="boot/grub"
readonly GRUB_FONTS_DIR="${GRUB_DIR}/fonts"
readonly GRUB_THEME_DIR="${GRUB_DIR}/themes"
readonly GRUB_THIS_THEME_DIR="${GRUB_THEME_DIR}/${THEME}"
readonly GRUB_CFG="${GRUB_DIR}/grub.cfg"
readonly UNIFONT
readonly TIMEOUT=60
readonly ARCH

# ===== main =====

# create directories
mkdir -p "$ISO_ROOT/$GRUB_FONTS_DIR" "$ISO_ROOT/$GRUB_THEME_DIR" || {
    log_error "failed to create necessary directories"
    exit 127
}

# copy theme
cp -r "$SRC" "${ISO_ROOT}/${GRUB_THEME_DIR}" || {
    log_error "failed to copy theme"
    exit 127
}

# copy Unicode font
[[ -n "${UNIFONT}" ]] && {
    cp "${UNIFONT}" "${ISO_ROOT}/${GRUB_FONTS_DIR}/" || {
        log_warn "failed to copy Unicode font; skipping"
    }
}


# generate 'grub.cfg'

{

# part 1 start
cat << EOF
set default=0
set timeout=${TIMEOUT}

EOF
# part 1 end

# part 2 start
for mod in all_video gfxterm gfxmenu png font; do
    echo "insmod ${mod}"
done
# part 2 end

# part 3 start
cat << EOF

set gfxmode=${RESOLUTION},auto
set gfxpayload=keep

terminal_output gfxterm

EOF
# part 3 end

# part 4 start
find . -type f -name "*.pf2" -print0 2> /dev/null | \
while IFS= read -r -d '' font; do
    # strip leading './' if present to match previous behavior
    fpath="${font#./}"
    echo "loadfont /${GRUB_THIS_THEME_DIR}/${fpath}"
done
# part 4 end

# part 5 start
cat << EOF
loadfont /${GRUB_FONTS_DIR}/unicode.pf2

set theme=/${GRUB_THIS_THEME_DIR}/theme.txt

EOF
# part 5 end

# part 6 start
i=0
for distro in \
    gentoo \
    arch \
    debian \
    fedora \
    ubuntu \
    kali \
    opensuse \
    steamos \
    zorin \
    deepin \
    lfs \
    linuxmint \
    iso \
    restart \
    shutdown;
do
    if (( (i & 1) == 0 )); then
        parity="even"
    else
        parity="odd"
    fi
    
    {
        echo "menuentry '${distro}' --class ${distro} --class ${parity} {"
        echo "    echo 'Entry ${i}'"
        
        if [[ "${distro}" == "restart" ]]; then
            echo "    reboot"
        fi
        if [[ "${distro}" == "shutdown" ]]; then
            echo "    halt"
        fi

        echo "}"
    }

    ((i++))
done
# part 6 end

} >> "${ISO_ROOT}/${GRUB_CFG}" || {
    log_error "failed to generate 'grub.cfg'"
    exit 127
}

# create GRUB ISO
grub-mkrescue -o "${ISO}" "${ISO_ROOT}" || {
    log_error "failed to create GRUB rescue ISO"
    exit 127
}

# launch QEMU virtual machine
qemu-system-${ARCH} \
    -M virt -cpu cortex-a57 \
    -bios /usr/share/qemu/edk2-$ARCH-code.fd \
    -cdrom "$ISO" \
    -device virtio-gpu-pci \
    -m 256M \
    -serial stdio \
    -display gtk \
|| {
    log_error "failed to launch QEMU VM"
    exit 127
}
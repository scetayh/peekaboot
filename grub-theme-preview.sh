#!/bin/bash

#
# NOTE
#
# Run this script in a GRUB theme directory (with 'theme.txt' in it.)
#

# ===== constant variables =====

readonly THEME="$(basename "${PWD}")"
readonly TMP="/tmp/grub-theme-preview"
readonly ISO_ROOT="${TMP}/${THEME}"
readonly ISO="${TMP}/${THEME}.iso"
readonly GRUB_DIR="boot/grub"
readonly GRUB_FONTS_DIR="${GRUB_DIR}/fonts"
readonly GRUB_THEME_DIR="${GRUB_DIR}/themes"
readonly GRUB_THIS_THEME_DIR="${GRUB_THEME_DIR}/${THEME}"
readonly GRUB_CFG="${GRUB_DIR}/grub.cfg"
for UNICODE_FONT in \
    "/${GRUB_FONTS_DIR}/unicode.pf2" \
    "/usr/share/grub/unicode.pf2";
do
    if [[ -f "${i}" ]]; then
        readonly UNICODE_FONT
        break
    fi
done
readonly TIMEOUT=60
# recommended:
# - 1920x1080 (16:9)
# - 1920x1200 (16:10, default)
# - 1920x1440 (4:3)
# - 1920x1280 (3:2)
readonly GFXMODE="1920x1200"
readonly ARCH="$(arch)"

# ===== main =====

# clean up
rm -rf "${ISO_ROOT}" "${ISO}"

# create temporary directory
mkdir -p "${ISO_ROOT}/${GRUB_FONTS_DIR}"
mkdir -p "${ISO_ROOT}/${GRUB_THIS_THEME_DIR}"

# copy theme
cp -rv "../${THEME}" "${ISO_ROOT}/${GRUB_THEME_DIR}"

# copy Unicode font
if [[ -f "${UNICODE_FONT}" ]]; then
    cp "${UNICODE_FONT}" "${ISO_ROOT}/${GRUB_FONTS_DIR}/"
fi

# generate 'grub.cfg'

# part 1 start
cat >> "${ISO_ROOT}/${GRUB_CFG}" << EOF
set default=0
set timeout=${TIMEOUT}

EOF
# part 1 end

# part 2 start
for mod in all_video gfxterm gfxmenu png font; do
    echo "insmod ${mod}" >> "${ISO_ROOT}/${GRUB_CFG}"
done
unset mod
# part 2 end

# part 3 start
cat >> "${ISO_ROOT}/${GRUB_CFG}" << EOF

set gfxmode=${GFXMODE},1920x1200,auto
set gfxpayload=keep

terminal_output gfxterm

EOF
# part 3 end

# part 4 start
for font in *.pf2; do
    echo "loadfont /${GRUB_THIS_THEME_DIR}/${font}" >> "${ISO_ROOT}/${GRUB_CFG}"
done
unset font
# part 4 end

# part 5 start
cat >> "${ISO_ROOT}/${GRUB_CFG}" << EOF
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
    } >> "${ISO_ROOT}/${GRUB_CFG}"

    ((i++))
done
unset i

# create GRUB ISO
grub-mkrescue -o "${ISO}" "${ISO_ROOT}"

# launch QEMU virtual machine
qemu-system-${ARCH} \
    -M virt -cpu cortex-a57 \
    -bios /usr/share/qemu/edk2-$ARCH-code.fd \
    -cdrom "$ISO" \
    -device virtio-gpu-pci \
    -m 256M \
    -serial stdio \
    -display gtk

# clean up
#rm -rf "${ISO_ROOT}" "${ISO}"

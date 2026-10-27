#!/data/data/com.termux/files/usr/bin/bash
# Installer WPS Switch by LP Tech (berlisensi)
# Pemakaian:
#   curl -fsSL https://raw.githubusercontent.com/lptech22/wps-switch/main/install.sh | bash

SERVER="https://wps-switch-ad.pages.dev"
PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
DEST="$PREFIX/bin/ws"
LIC_DIR="${HOME:-/data/data/com.termux/files/home}/.config/wps-switch"
CONTACT="WhatsApp 087870805424"

if [ -t 1 ]; then
  N=$'\e[0m'; B=$'\e[1m'; RED=$'\e[31m'; GRN=$'\e[32m'; YEL=$'\e[33m'; CYN=$'\e[36m'
else
  N=; B=; RED=; GRN=; YEL=; CYN=
fi
ok()   { printf "  ${GRN}✔${N} %s\n" "$1"; }
err()  { printf "  ${RED}✘${N} %s\n" "$1"; }
warn() { printf "  ${YEL}!${N} %s\n" "$1"; }
info() { printf "  ${CYN}•${N} %s\n" "$1"; }

printf "\n${B}${CYN}▶ Memasang WPS Switch by LP Tech${N}\n"

[ -d "$PREFIX/bin" ] || { err "Ini bukan Termux ($PREFIX/bin tidak ada)"; exit 1; }
ok "Lingkungan Termux terdeteksi"
command -v curl >/dev/null 2>&1 || { err "curl belum terpasang. Jalankan: pkg install curl"; exit 1; }
ok "curl tersedia"
command -v su >/dev/null 2>&1 || warn "Perintah su belum ditemukan. Pasang KernelSU dulu, WPS Switch tetap dipasang."

mkdir -p "$LIC_DIR" && chmod 700 "$LIC_DIR"

# ID perangkat: dibuat sekali, dipakai untuk mengikat lisensi
if [ ! -s "$LIC_DIR/device" ]; then
  head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > "$LIC_DIR/device"
fi
DEV=$(cat "$LIC_DIR/device")

KEY=$(cat "$LIC_DIR/license" 2>/dev/null)
if [ -n "$KEY" ]; then
  ok "Lisensi tersimpan dipakai"
else
  if ! { exec 3</dev/tty; } 2>/dev/null; then
    err "Tidak ada terminal untuk memasukkan lisensi."
    info "Jalankan perintah instalasi langsung di Termux."
    exit 1
  fi
  printf "\n  ${B}Instalasi memerlukan kunci lisensi.${N}\n"
  info "Belum punya? Hubungi LP Tech: $CONTACT"
  printf "\n  Kunci lisensi: " >&2
  IFS= read -r KEY <&3
  exec 3<&-
  KEY=$(printf '%s' "$KEY" | tr -d '[:space:]' | tr 'a-z' 'A-Z')
  case "$KEY" in
    WPS-????-????-????) ;;
    *) err "Format kunci salah (contoh: WPS-ABCD-EFGH-JKLM)"; exit 1 ;;
  esac
fi

tmp=$(mktemp) || exit 1
code=$(curl -sSL --max-time 25 -o "$tmp" -w '%{http_code}' "$SERVER/dl?key=$KEY&device=$DEV") \
  || { err "Tidak bisa menghubungi server. Cek koneksi internet."; rm -f "$tmp"; exit 1; }
if [ "$code" != 200 ]; then
  err "Ditolak: $(head -c 200 "$tmp")"
  info "Hubungi LP Tech: $CONTACT"
  rm -f "$tmp"; exit 1
fi
head -1 "$tmp" | grep -q '^#!' || { err "Respons server tidak valid"; rm -f "$tmp"; exit 1; }
rm -f "$tmp"
ok "Lisensi valid"

printf '%s' "$KEY" > "$LIC_DIR/license" && chmod 600 "$LIC_DIR/license" "$LIC_DIR/device"
cat > "$DEST.new" <<'LAUNCHER_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# WPS Switch by LP Tech - pembuka
# Kode menu diambil dari server lisensi setiap kali dibuka (butuh internet).
SERVER="https://wps-switch-ad.pages.dev"
LIC_DIR="${HOME:-/data/data/com.termux/files/home}/.config/wps-switch"
R=$'\e[31m'; D=$'\e[2m'; N=$'\e[0m'
KEY=$(cat "$LIC_DIR/license" 2>/dev/null); DEV=$(cat "$LIC_DIR/device" 2>/dev/null)
if [ -z "$KEY" ] || [ -z "$DEV" ]; then
  printf "  ${R}✘${N} Data lisensi tidak ditemukan. Pasang ulang lewat install.sh\n"; exit 1
fi
command -v curl >/dev/null 2>&1 || { printf "  ${R}✘${N} curl belum terpasang (pkg install curl)\n"; exit 1; }
tmp=$(mktemp) || exit 1
code=$(curl -sSL --max-time 25 -o "$tmp" -w '%{http_code}' "$SERVER/dl?key=$KEY&device=$DEV" 2>/dev/null)
CODE=$(cat "$tmp"); rm -f "$tmp"
if [ "$code" != 200 ]; then
  if [ -z "$code" ] || [ "$code" = 000 ]; then
    printf "  ${R}✘${N} Tidak bisa menghubungi server. WPS Switch butuh internet saat dibuka.\n"
  else
    printf "  ${R}✘${N} Ditolak server: %s\n" "$(printf '%s' "$CODE" | head -c 200)"
    printf "  ${D}Hubungi LP Tech: WhatsApp 087870805424${N}\n"
  fi
  exit 1
fi
case "$CODE" in "#!"*) ;; *) printf "  ${R}✘${N} Respons server tidak valid\n"; exit 1 ;; esac
exec bash -c "$CODE" ws "$@"
LAUNCHER_EOF
chmod +x "$DEST.new" && mv -f "$DEST.new" "$DEST" || { err "Gagal memasang ke $DEST"; exit 1; }
ok "Terpasang di $DEST"

if [ -e "$PREFIX/bin/ssw" ]; then
  rm -f "$PREFIX/bin/ssw" "$PREFIX/bin/ssw.new" && ok "Perintah lama ssw dihapus"
fi

printf "\n  ${B}Selesai!${N} Ketik ${GRN}ws${N} untuk membuka menu.\n"
info "WPS Switch butuh internet saat dibuka. Bantuan: ws help"
printf "\n"

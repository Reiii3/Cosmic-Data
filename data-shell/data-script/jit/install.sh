#!/system/bin/sh
# ===================================================
#        VeuLexier JIT Compiler — Game Edition
# ===================================================
# Package list : /data/local/tmp/game.txt
# ===================================================

GAME_LIST="/data/local/tmp/game.txt"
LOG_TAG="VeuLexier-JIT"

# ===================================================
#                 HELPER FUNCTIONS
# ===================================================
log_info()  { echo "  $1"; }
log_ok()    { echo "  ✅ $1"; }
log_warn()  { echo "  ⚠ $1"; }
log_err()   { echo "  ❌ $1"; }
log_sep()   { echo "---------------------------------------"; }

# Cek apakah package terinstall
pkg_exists() {
    pm list packages --user 0 2>/dev/null | grep -q "^package:$1$"
}

# Ambil versi package
pkg_version() {
    dumpsys package "$1" 2>/dev/null | grep "versionName" | head -1 | awk -F= '{print $2}' | xargs
}

# ===================================================
#                 VALIDASI AWAL
# ===================================================
echo ""
echo "======================================="
echo "  VeuLexier JIT Compiler — Game Mode  "
echo "======================================="
echo ""

# Cek file game.txt
if [ ! -f "$GAME_LIST" ]; then
    log_err "File tidak ditemukan: $GAME_LIST"
    log_err "Buat dulu dengan: echo 'com.package.game' >> $GAME_LIST"
    exit 1
fi

# Cek file tidak kosong
if [ ! -s "$GAME_LIST" ]; then
    log_err "game.txt kosong! Tambahkan nama package game dulu."
    exit 1
fi

total_lines=$(cat "$GAME_LIST" | tr -d '\r' | grep -v '^[[:space:]]*$' | grep -v '^#' | wc -l | tr -d ' ')

log_info "📄 Package list   : $GAME_LIST"
log_info "📦 Total entries  : $total_lines package"
echo ""


# ===================================================
#         CEK DUKUNGAN CMD PACKAGE COMPILE
# ===================================================
# Tes compile ke package dummy — kalau error "Unknown package" berarti
# command-nya ada, kalau error "Unknown command" berarti tidak support
_test=$(cmd package compile 2>&1)
case "$_test" in
    *"Unknown command"*|*"not found"*)
        log_err "cmd package compile tidak tersedia di perangkat ini."
        log_warn "Pastikan Android 7+ dan akses root/shell."
        exit 1
        ;;
esac
log_ok "cmd package compile tersedia"
echo ""


# ===================================================
#                 PROSES JIT COMPILE
# ===================================================
echo "======================================="
echo "  🚀 Memulai JIT Compilation..."
echo "======================================="
echo ""

success=0
failed=0
skipped=0

# Simpan counter ke tmpfile karena while loop jalan di subshell kalau pakai pipe
TMP_COUNT="/data/local/tmp/.jit_count"
echo "0 0 0" > "$TMP_COUNT"

while read pkg; do
    # Strip \r dan trim whitespace
    pkg=$(echo "$pkg" | tr -d '\r' | xargs 2>/dev/null)

    # Skip baris kosong dan komentar (#)
    case "$pkg" in
        ''|\#*) continue ;;
    esac

    # Baca counter terkini
    read s f sk < "$TMP_COUNT"

    log_sep
    log_info "📦 Package : $pkg"

    # Cek apakah package ada
    if ! pkg_exists "$pkg"; then
        log_warn "Package tidak terinstall, dilewati."
        sk=$((sk + 1))
        echo "$s $f $sk" > "$TMP_COUNT"
        continue
    fi

    ver=$(pkg_version "$pkg")
    [ -n "$ver" ] && log_info "🔖 Versi   : $ver"

    # Force-stop dulu supaya JIT bisa jalan optimal
    log_info "⏹  Force-stop $pkg..."
    am force-stop "$pkg" 2>/dev/null
    sleep 0.5

    # ---- TAHAP 1: speed-profile compile ----
    log_info "⚙  Compile [speed-profile]..."
    cmd package compile -m speed-profile -f "$pkg" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        log_ok "speed-profile: OK"
    else
        log_warn "speed-profile gagal, coba speed..."

        # ---- TAHAP 2: fallback ke speed ----
        cmd package compile -m speed -f "$pkg" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_ok "speed: OK (fallback)"
        else
            # ---- TAHAP 3: fallback ke quicken ----
            log_warn "speed gagal, coba quicken..."
            cmd package compile -m quicken -f "$pkg" >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                log_ok "quicken: OK (fallback)"
            else
                log_err "Semua mode compile gagal untuk $pkg"
                f=$((f + 1))
                echo "$s $f $sk" > "$TMP_COUNT"
                continue
            fi
        fi
    fi

    # ---- bg-dexopt (opsional, Android 12+) ----
    cmd package bg-dexopt-job "$pkg" >/dev/null 2>&1 && \
        log_ok "bg-dexopt: OK"

    s=$((s + 1))
    echo "$s $f $sk" > "$TMP_COUNT"
    log_ok "Done: $pkg"

done < "$GAME_LIST"

# Baca hasil akhir counter
read success failed skipped < "$TMP_COUNT"
rm -f "$TMP_COUNT"


# ===================================================
#                    SUMMARY
# ===================================================
now=$(date '+%A, %d %B %Y  %H:%M:%S')

echo ""
echo "======================================="
echo "  📊 HASIL JIT COMPILATION"
echo "======================================="
echo "  🕐 Waktu     : $now"
echo "  ✅ Berhasil  : $success package"
echo "  ❌ Gagal     : $failed package"
echo "  ⚠  Dilewati  : $skipped package (tidak terinstall)"
echo "  📦 Total     : $total_lines package"
echo "======================================="
echo ""

if [ "$success" -gt 0 ]; then
    echo "  🎮 JIT Compile selesai! Game siap dimainkan."
else
    echo "  ⚠ Tidak ada package yang berhasil di-compile."
fi

echo ""
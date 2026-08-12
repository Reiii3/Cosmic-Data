#!/system/bin/sh
# ================================================================
# Dynamic SurfaceFlinger Tuning — BALANCE SCRIPT (Daily Mode, fixed)
# ================================================================
# Versi tengah antara install (full aggressive) dan restore
# (kosongkan semua). Cocok untuk daily mode dimana SurfaceFlinger
# tetap perlu efisien tapi tidak sekencang mode gaming.
# ================================================================

# [FIX] balance_sf sebelumnya 1000000, install.sh punya 1000000000
#     buat property yang sama (debug.sf.hw/debug.egl.hw) — dua nilai
#     beda jauh tanpa pola jelas mengindikasikan bug/leftover, bukan
#     disengaja. Diseragamin ke 1 (boolean) sama kayak install.sh;
#     VERIFIKASI ke device sebelum final.
balance_sf=1

other() {
    a=$1
    b=$2
    c=$3

    setprop debug.sf.luma_sampling $c
    setprop debug.sf.enable_gl_backpressure $b
    setprop debug.sf.enable_transaction_tracing $c
    setprop debug.sf.disable_client_composition_cache $c
    setprop debug.sf.predict_hwc_composition_strategy $c
    setprop debug.sf.vsync_reactor_ignore_present_fences $c
    setprop debug.sf.use_phase_offsets_as_durations $b
    setprop debug.sf.kernel_idle_timer_update_overlay $b
    setprop debug.sf.cache_source_crop_only_moved $a
    setprop debug.sf.enable_layer_command_batching $a
    setprop debug.sf.fp16_client_target $a
    setprop debug.sf.hw $c
    setprop debug.sf.latch_unsignaled $c
    setprop debug.sf.auto_latch_unsignaled $b
    setprop debug.sf.multithreaded_present $a
    setprop debug.sf.screenshot_fence_preservation $a

    for i in solid_layers shadow_layers image_layers clipped_layers edge_extension_shader hole_punch solid_dimmed_layers image_dimmed_layers pip_image_layers transparent_image_dimmed_layers clipped_dimmed_image_layers; do
        setprop debug.sf.prime_shader_cache.$i $a
    done
}

auto_sf_balance() {
    # [FIX] 2>/dev/null di dumpsys itu sendiri — nutup pesan
    #     "Broken pipe" pas head -n1 nutup pipe duluan
    refresh_rate=$(dumpsys display 2>/dev/null | grep -oE 'fps=[0-9]+' | head -n 1 | cut -d= -f2)

    # [FIX] guard div-by-zero — cek kosong DAN nol
    if [ -z "$refresh_rate" ] || [ "$refresh_rate" -eq 0 ] 2>/dev/null; then
        refresh_rate=62
    fi

    # [FIX] guard kalau bukan angka valid sama sekali
    case "$refresh_rate" in
        ''|*[!0-9]*) refresh_rate=62 ;;
    esac

    # frame time dalam nanosecond
    frame_time=$((1000000000 / refresh_rate))

    # early_offset lebih kecil dari mode perf — tidak seagresif gaming
    early_offset=$(( (frame_time / 8) * -1 ))
    late_offset=$((frame_time * 7 / 10))

    # gl_duration untuk daily bisa sedikit lebih longgar
    gl_duration=$((late_offset - frame_time / 10))

    # idle_timer untuk daily boleh lebih lama dari gaming (hemat daya)
    idle_timer_ms=$((frame_time / 1000000))
    if [ "$idle_timer_ms" -lt 150 ]; then
        idle_timer=150
    else
        idle_timer=$idle_timer_ms
    fi

    setprop debug.sf.hw "$balance_sf"
    setprop debug.egl.hw "$balance_sf"
    setprop debug.sf.hwc.min.duration "$frame_time"
    setprop debug.sf.early.app.duration "$early_offset"
    setprop debug.sf.late.app.duration "$late_offset"
    setprop debug.sf.early.sf.duration "$early_offset"
    setprop debug.sf.late.sf.duration "$late_offset"
    setprop debug.sf.set_idle_timer_ms "$idle_timer"
    setprop debug.sf.earlyGl.sf.duration "$gl_duration"
    setprop debug.sf.earlyGl.app.duration "$gl_duration"
    setprop debug.sf.early_phase_offset_ns "$early_offset"
    setprop debug.sf.early_gl_phase_offset_ns "$early_offset"
    setprop debug.sf.early_app_phase_offset_ns "$early_offset"
    setprop debug.sf.early_gl_app_phase_offset_ns "$early_offset"
    setprop debug.sf.high_fps_early_app_phase_offset_ns "$early_offset"
    setprop debug.sf.high_fps_late_app_phase_offset_ns "$late_offset"
    setprop debug.sf.high_fps_early_sf_phase_offset_ns "$early_offset"
    setprop debug.sf.high_fps_late_sf_phase_offset_ns "$late_offset"
    setprop debug.sf.high_fps_early_gl_phase_offset_ns "$early_offset"
    setprop debug.sf.high_fps_early_gl_app_phase_offset_ns "$early_offset"

    echo "[i] Refresh Rate: ${refresh_rate}Hz"
    echo "[i] Frame Time: ${frame_time}ns"
    echo "[i] Early Offset: ${early_offset}ns"
    echo "[i] Late Offset: ${late_offset}ns"
    echo "[i] GL Duration: ${gl_duration}ns"
    echo "[i] Idle Timer: ${idle_timer}ms"
}

main_balance() {
    auto_sf_balance
    # Flag lebih hemat dibanding perf (1 1 0), tapi tetap ada
    # beberapa optimasi ringan dibanding restore total (0 0 0)
    other 1 0 0
    echo "[+] Dynamic SurfaceFlinger Balance Applied (Daily Mode)"
    echo "[+] SurfaceFlinger 2.1 | Last Update"
}

main_balance
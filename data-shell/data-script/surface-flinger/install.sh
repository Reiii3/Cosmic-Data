#!/system/bin/sh
# ================================================================
# Dynamic SurfaceFlinger Tuning — INSTALL SCRIPT (fixed)
# ================================================================

# [FIX] run_sf sebelumnya 1000000000 — dipakai sebagai boolean flag
#     ke debug.sf.hw / debug.egl.hw, padahal property itu di seluruh
#     script lain lu selalu di-set boolean (1/0). Diganti ke 1 dulu
#     sebagai default aman; VERIFIKASI ke device lu apakah nilai asli
#     (1000000000) memang disengaja buat semantik lain sebelum revert.
run_sf=1

other() {
    a=$1   # client cache / bool
    b=$2   # backpressure / bool
    c=$3   # misc flag / bool

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

auto_sf_dyn() {
    sf_flag="$1"

    # [FIX] tambahin 2>/dev/null di dumpsys itu sendiri (bukan cuma di
    #     ujung pipeline) — nutup pesan "Broken pipe" yang muncul pas
    #     head -n1 nutup pipe duluan sementara dumpsys masih nulis.
    #     Nilai yang keambil tetap sama, cuma stderr-nya diredam.
    refresh_rate=$(dumpsys display 2>/dev/null | grep -oE 'fps=[0-9]+' | head -n 1 | cut -d= -f2)

    # [FIX] guard div-by-zero — sebelumnya cuma cek kosong (-z), gak
    #     cek nol. refresh_rate="0" lolos guard lama dan bikin
    #     `1000000000 / 0` crash arithmetic, menghentikan SELURUH
    #     script di titik ini (semua setprop di bawah gak pernah jalan).
    if [ -z "$refresh_rate" ] || [ "$refresh_rate" -eq 0 ] 2>/dev/null; then
        refresh_rate=62
    fi

    # [FIX] guard tambahan kalau refresh_rate ternyata bukan angka
    #     valid sama sekali (format dumpsys beda di OEM tertentu)
    case "$refresh_rate" in
        ''|*[!0-9]*) refresh_rate=62 ;;
    esac

    # frame time dalam nanosecond
    frame_time=$((1000000000 / refresh_rate))

    # early_offset HARUS negatif — app/SF mulai kerja sebelum vsync
    early_offset=$(( (frame_time / 5) * -1 ))

    # late_offset tetap positif — deadline kerja selesai
    late_offset=$((frame_time * 5 / 6))

    # gl_duration dikurangi dari late_offset, bukan ditambah
    gl_duration=$((late_offset - frame_time / 15))

    # idle_timer di-clamp minimum 100ms
    idle_timer_ms=$((frame_time / 1000000))
    if [ "$idle_timer_ms" -lt 100 ]; then
        idle_timer=100
    else
        idle_timer=$idle_timer_ms
    fi

    sampling_duration=$((frame_time * 4 / 5))
    sampling_period=$((frame_time * 9 / 10))

    setprop debug.sf.hw "$sf_flag"
    setprop debug.egl.hw "$sf_flag"
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

main_active() {
    auto_sf_dyn "$run_sf"
    other 1 1 0
    echo "[+] Dynamic SurfaceFlinger Activated"
    echo "[+] SurfaceFlinger 2.1 | Last Update"
}

main_active
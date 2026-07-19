#!/system/bin/sh
# ================================================================
# Dynamic SurfaceFlinger Tuning — RESTORE SCRIPT
# ================================================================

remove_sf=1000000

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

auto_sf_restore() {
    setprop debug.sf.hw "$remove_sf"
    setprop debug.egl.hw "$remove_sf"
    setprop debug.sf.hwc.min.duration ""
    setprop debug.sf.early.app.duration ""
    setprop debug.sf.late.app.duration ""
    setprop debug.sf.early.sf.duration ""
    setprop debug.sf.late.sf.duration ""
    setprop debug.sf.set_idle_timer_ms ""
    setprop debug.sf.earlyGl.sf.duration ""
    setprop debug.sf.earlyGl.app.duration ""
    setprop debug.sf.early_phase_offset_ns ""
    setprop debug.sf.early_gl_phase_offset_ns ""
    setprop debug.sf.early_app_phase_offset_ns ""
    setprop debug.sf.early_gl_app_phase_offset_ns ""
    setprop debug.sf.high_fps_early_app_phase_offset_ns ""
    setprop debug.sf.high_fps_late_app_phase_offset_ns ""
    setprop debug.sf.high_fps_early_sf_phase_offset_ns ""
    setprop debug.sf.high_fps_late_sf_phase_offset_ns ""
    setprop debug.sf.high_fps_early_gl_phase_offset_ns ""
    setprop debug.sf.high_fps_early_gl_app_phase_offset_ns ""

    other 0 0 0

    echo "[-] Dynamic SurfaceFlinger Restored to Default"
    echo "[+] SurfaceFlinger 2.0 | Last Update"
}

auto_sf_restore
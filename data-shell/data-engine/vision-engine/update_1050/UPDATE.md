# VisionAI Engine — Update 1042-Alpha-X

> **Versi:** 1042-Alpha-X  
> **Sebelumnya:** 1038-Alpha  
> **Status:** Alpha — Experimental Build  

---

## Ringkasan Update

Update ini membawa perbaikan besar pada stabilitas daemon, penambahan sistem manajemen multitasking dengan 3 mode yang dapat dikonfigurasi, perbaikan logika screen state yang sebelumnya terbalik, penambahan CPU cluster tuning, serta refactor berbagai fungsi agar lebih efisien dan POSIX compliant.

---

## Bug Fix

### 🐛 Screen State Logic Terbalik
**Sebelumnya** — kondisi `ON` justru menjalankan `cmd_off_screen_daily` sehingga profil layar mati dijalankan saat layar menyala.

**Sesudah** — logika dibalik dan diperbaiki:
```
Layar OFF  →  cmd_daily_off + cmd_off_screen_daily
Layar ON   →  cmd_daily_off + cmd_on_screen_daily
```

---

### 🐛 Screen CMD Jalan Setiap 2 Detik
**Sebelumnya** — tidak ada tracking state sebelumnya, sehingga `cmd_daily_off` dan `cmd_off_screen_daily` dieksekusi setiap iterasi loop (setiap 2 detik) meskipun tidak ada perubahan.

**Sesudah** — ditambahkan variabel `prev_screen_status`. Screen cmd hanya jalan saat terjadi perubahan state:
```sh
prev_screen_status=""

if [ "$screen_status" != "$prev_screen_status" ]; then
  # jalankan cmd screen
  prev_screen_status="$screen_status"
fi
```

---

### 🐛 Screen Check Jalan Saat Game Aktif
**Sebelumnya** — blok screen state tidak memiliki guard `game_mode_access`, sehingga daily cmd ikut dieksekusi bahkan saat game sedang berjalan.

**Sesudah** — ditambahkan guard:
```sh
if [ "$game_mode_access" = "false" ] && [ "$screen_status" != "$prev_screen_status" ]; then
  # jalankan cmd screen
fi
```

---

### 🐛 `apps_detected` Kosong Menyebabkan False Positive
**Sebelumnya** — `grep -qw ""` pada beberapa implementasi selalu return true jika `apps_detected` kosong, menyebabkan sistem masuk game mode padahal tidak ada game yang terdeteksi.

**Sesudah** — ditambahkan guard `[ -n "$apps_detected" ]`:
```sh
if [ -n "$apps_detected" ] && echo "$game_list" | grep -qw "$apps_detected"; then
```

---

### 🐛 `[[ ]]` Dipakai di POSIX sh
**Sebelumnya** — meski header script menyatakan POSIX sh compatible, banyak bagian masih menggunakan `[[ ]]` dan `==` yang merupakan bashism.

**Sesudah** — semua diganti ke bentuk POSIX:
```sh
# Sebelum
if [[ $screen_status == "ON" ]]
if [[ $first_setup == "false" ]]
if [[ "$(settings get global x)" == "1" ]]

# Sesudah
if [ "$screen_status" = "ON" ]
if [ "$first_setup" = "false" ]
if [ "$(settings get global x)" = "1" ]
```

---

### 🐛 Label `mode_now` Tidak Konsisten
**Sebelumnya** — saat tidak ada game, `mode_now` diset ke `"saver_mode"` yang membingungkan karena bukan nama mode yang tepat.

**Sesudah** — diganti ke `"daily_mode"` agar konsisten dengan penamaan fungsi lainnya.

---

### 🐛 Game Close Tidak Aware Screen State
**Sebelumnya** — saat game ditutup, selalu menjalankan `cmd_on_screen_daily` tanpa cek kondisi layar.

**Sesudah** — saat game close, daemon otomatis deteksi screen state:
```sh
if [ "$screen_status" = "OFF" ]; then
  cmd_off_screen_daily
else
  cmd_on_screen_daily
fi
```

---

### 🐛 Duplikasi Kode Compiler Task
**Sebelumnya** — blok kode compiler (smart cache + JIT + dalvik) ditulis dua kali secara identik di dua kondisi berbeda.

**Sesudah** — direfactor menjadi satu fungsi tersendiri:
```sh
run_compiler_tasks() {
  # smart cache
  # JIT compiler
  # dalvik recompiler
}
```

---

## Fitur Baru

### ✨ Multitasking Manager — `cmd_multitasking()`
Fungsi baru untuk mengatur seberapa agresif sistem mengelola proses background. Mengontrol cached processes, phantom processes, freezer, memory factor, JobScheduler, app standby, dan Doze behavior dalam satu fungsi terpusat.

Dipanggil dengan:
```sh
cmd_multitasking <mode>
```

#### Mode LOW
Untuk perangkat RAM kecil (2–4GB) atau kondisi baterai kritis. Sistem sangat agresif membunuh proses background.

| Parameter | Nilai |
|---|---|
| `max_cached_processes` | 8 |
| `max_phantom_processes` | 4 |
| `memory-factor` | 2 (agresif kill) |
| `greezer` | true |
| `bg_fgs_monitor` | true |
| `inactive_to (Doze)` | 5 menit |
| `max_job_count_active` | 40 |

**Cocok untuk:** Gaming fokus, baterai kritis, RAM minim  
**Trade-off:** App background sering reload, notifikasi bisa delay

---

#### Mode MEDIUM
Mode seimbang untuk penggunaan harian. Menjaga sejumlah app tetap hidup tanpa terlalu boros RAM.

| Parameter | Nilai |
|---|---|
| `max_cached_processes` | 24 |
| `max_phantom_processes` | 16 |
| `memory-factor` | 1 (normal) |
| `greezer` | true |
| `bg_fgs_monitor` | true |
| `inactive_to (Doze)` | 1 jam |
| `max_job_count_active` | 150 |

**Cocok untuk:** Penggunaan harian, RAM 4–8GB  
**Trade-off:** Tidak semua app bertahan lama di background

---

#### Mode HIGH
Mode multitasking penuh untuk perangkat RAM besar (8GB+). Sistem tidak agresif membunuh proses background.

| Parameter | Nilai |
|---|---|
| `max_cached_processes` | 65535 |
| `max_phantom_processes` | 65535 |
| `memory-factor` | 0 (tidak kill) |
| `greezer` | false |
| `bg_fgs_monitor` | false |
| `inactive_to (Doze)` | 4 jam |
| `max_job_count_active` | 300 |

**Cocok untuk:** Power user, RAM 8GB+, banyak app sekaligus  
**Trade-off:** RAM cepat penuh, baterai lebih boros

---

### ✨ CPU Cluster Tuning
Ditambahkan tuning eksplisit untuk cluster CPU little dan big agar hint frekuensi diberikan langsung ke scheduler berdasarkan nilai aktual dari sysfs.

**Efek:** Scheduler lebih akurat dalam mendistribusikan beban kerja antara core efisien dan core performa, mengurangi thermal throttling yang tidak perlu saat load rendah.

> Nilai diambil langsung dari `/sys/devices/system/cpu/cpu1/cpufreq/` sehingga otomatis menyesuaikan spesifikasi perangkat.

---

### ✨ Uninstall One Time Setup — `cmd_one_time_setup_remove()`
Ditambahkan fungsi uninstall untuk mengembalikan semua setting dari one time setup ke nilai default sistem, termasuk:
- Mengaktifkan kembali Advanced Protection, Backup Manager, Supervisi
- Mengembalikan Autofill, Content Capture, Accessibility ke default
- Menghapus override HDR display
- Mengembalikan logging (binder stats, looper stats, dropbox)
- Menghapus throttle package update
- Mengembalikan grammatical inflection dan contextual search ke default

---

### ✨  Fungsi Profil Cmd Daily Dipisah Menjadi 3

| Fungsi | Trigger |
|---|---|
| `cmd_on_screen_daily` | Layar menyala, tidak ada game |
| `cmd_off_screen_daily` | Layar mati / idle penuh |
| `cmd_daily_off` | Transisi keluar dari daily ke mode lain |

Sebelumnya hanya ada satu profil daily yang dijalankan tanpa mempertimbangkan kondisi layar.

---

## Perubahan dan Perbaikan Alur Eksekusi Cmd Tweak

```
# Sebelumnya
screen ON  →  cmd_daily_off + cmd_off_screen_daily  ← terbalik
screen OFF →  tidak ada handling

# Sesudah
screen ON  →  cmd_daily_off + cmd_on_screen_daily
screen OFF →  cmd_daily_off + cmd_off_screen_daily
game open  →  cmd_daily_off → cmd_game
game close →  cmd_close_game → cek screen → cmd_on/off_screen_daily
```

---

## Catatan

- Semua `cmd device_config`, `setprop debug.*`, dan `cmd activity` bersifat volatile dan akan reset saat reboot. Daemon harus autostart agar setting kembali diapply.
- CPU cluster tuning menggunakan `cpu1` sebagai referensi. Pada beberapa perangkat dengan topologi CPU berbeda, path sysfs mungkin perlu disesuaikan.
- Multitasking mode disarankan dipanggil dari `switch_game_mode` atau `switch_daily_mode` dengan membaca nilai dari `settings get global vision_multitasking_mode`.

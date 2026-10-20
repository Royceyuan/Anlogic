import_device eagle_s20.db -package EG4S20BG256
set folder _build_tf_video
set f [open [file join $folder final.status] r];set status [read $f];close $f
set f [open [file join $folder console.log] r];set log [read $f];close $f
if {![regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+[0-9]+ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $status] ||
    ![regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+[0-9]+ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $status] ||
    [regexp { ERROR:|No clock match|Clock group is empty|black box} $log] ||
    [string first {No multi-drive.} $log]<0 || [string first {No abnormal timing path.} $log]<0} {
    error "REFUSED: failed offline-video timing/DRC/clock constraints"
}
# Same two inherited IP warnings as scripts/generate_bitstream.tcl and the
# board-passed seed/playback_speed: internal SDRAM macro relocation and its
# single forwarded C2 clock sink, not a new fabric-clock exception.
foreach line [split $log "\n"] {
    if {[string first {CRITICAL-WARNING:} $line]<0} {continue}
    if {[regexp {^PHY-7002 CRITICAL-WARNING: Instance u_store/u_sdram/sdram location \((12, 12|164, 288)\) is not honored\.} [string trim $line]]} {continue}
    if {[regexp {^PHY-5079 CRITICAL-WARNING: Marked 1 clock net\(s\) utilize the local routing resources\.} [string trim $line]] &&
        [regexp {u_pll\.clkc\[2\][[:space:]]+\|[[:space:]]+AL_PHY_PLL[[:space:]]+\|[[:space:]]+0/1[[:space:]]+\|[[:space:]]+1[[:space:]]+\|[[:space:]]+u_store/u_sdram/u2_ram/SDRAM_CLK[[:space:]]+\|[[:space:]]+true} $log]} {continue}
    error "REFUSED: unreviewed warning $line"
}
# Check every project dependency, including vendored memories and constraints.
set f [open secondary_tf_video.al r];set project [read $f];close $f
set dependencies [regexp -all -inline {Path="([^"]+)"} $project]
foreach {match path} $dependencies {
    if {$path=="."} {continue}
    if {![file exists $path] || [file mtime $path]>[file mtime [file join $folder final.db]]} {
        error "REFUSED: missing or stale source $path"
    }
}
foreach source {secondary_tf_video.al scripts/build_tf_video.tcl vendor/anlogic_lab6/sdram/enc_file/global_def.v} {
    if {[file mtime $source]>[file mtime [file join $folder final.db]]} {error "REFUSED: stale build input $source"}
}
foreach result {sd_0ns sd_14ns fat32_mvid_reader fat_multiblock mvid_scale2x mvid_frame_control scale720 sdram_turnaround} {
    set f [open [file join $folder ${result}.log] r];set simulation [read $f];close $f
    if {[string first PASS $simulation]<0 || [regexp {FAIL|FATAL|ERROR} $simulation]} {error "REFUSED: simulation $result failed"}
}
foreach {result sources} {
    sd_0ns {src/storage/sd_native_read.v src/storage/sd_native_command.v src/storage/sd_native_data_rx.v sim/tb_sd_native_read.v}
    sd_14ns {src/storage/sd_native_read.v src/storage/sd_native_command.v src/storage/sd_native_data_rx.v sim/tb_sd_native_read.v}
    fat32_mvid_reader {src/storage/fat32_mvid_reader.v sim/tb_fat32_mvid_reader.v}
    fat_multiblock {src/storage/fat32_mvid_reader.v sim/tb_fat32_mvid_reader.v}
    mvid_scale2x {src/video/mvid_scale2x.v sim/tb_mvid_scale2x.v}
    scale720 {src/video/mvid_scale2x.v sim/tb_mvid_scale2x.v}
    mvid_frame_control {src/video/mvid_frame_control.v sim/tb_mvid_frame_control.v}
    sdram_turnaround {vendor/anlogic_lab6/al_ip/afifo_16_32_256.v vendor/anlogic_lab6/al_ip/afifo_32_16_256.v vendor/anlogic_lab6/frame_fifo_read.v vendor/anlogic_lab6/frame_fifo_write.v vendor/anlogic_lab6/frame_read_write.v sim/tb_mvid_sdram_turnaround.v}
} {
    foreach source $sources {
        if {[file mtime $source]>[file mtime [file join $folder ${result}.log]]} {error "REFUSED: stale simulation $result"}
    }
}
import_db [file join $folder final.db]
bitgen -bit [file join $folder secondary_tf_video.bit]
exit

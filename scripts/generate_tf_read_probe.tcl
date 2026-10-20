import_device eagle_s20.db -package EG4S20BG256
set folder _build_tf_read_probe
set f [open [file join $folder final.status] r];set status [read $f];close $f
set f [open [file join $folder console.log] r];set log [read $f];close $f
if {![regexp {Setup[[:space:]]+:[[:space:]]+WNS[[:space:]]+[0-9]+ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $status] ||
    ![regexp {Hold[[:space:]]+:[[:space:]]+WNS[[:space:]]+[0-9]+ps[[:space:]]+TNS[[:space:]]+0ps[[:space:]]+NUM_FEPS[[:space:]]+0} $status] ||
    [regexp { ERROR:|CRITICAL-WARNING:|No clock match|black box} $log] ||
    [string first {No multi-drive.} $log]<0 || [string first {No abnormal timing path.} $log]<0} {
    error "REFUSED: failed SD probe timing/DRC/clock constraints"
}
foreach source {secondary_tf_read_probe.al src/storage/sd_native_command.v src/storage/sd_native_data_rx.v src/storage/sd_native_read.v src/secondary/top_secondary_tf_read_probe.v constraints/secondary_tf_read_probe.adc constraints/secondary_tf_read_probe.sdc scripts/build_tf_read_probe.tcl} {
    if {[file mtime $source]>[file mtime [file join $folder final.db]]} {error "REFUSED: stale source $source"}
}
import_db [file join $folder final.db]
bitgen -bit [file join $folder secondary_tf_read_probe.bit]
exit

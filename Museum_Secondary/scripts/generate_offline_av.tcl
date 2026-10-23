set secondary [file dirname [file dirname [file normalize [info script]]]]
set target secondary
if {[info exists ::env(OFFLINE_AV_TARGET)]} {set target $::env(OFFLINE_AV_TARGET)}
if {$target ni {secondary main}} {error "Unknown offline AV target"}
set root $secondary
set folder _build_secondary
set name museum_secondary_final
if {$target eq "main"} {
    set root [file join [file dirname $secondary] Museum_Main]
    set folder _build_main
    set name museum_main_final
}
cd $root
set python D:/Anaconda/python.exe
if {[info exists ::env(OFFLINE_AV_PYTHON)]} {set python $::env(OFFLINE_AV_PYTHON)}
puts [exec $python [file join $secondary scripts verify_offline_release.py] $target]
set release_dir release
if {[info exists ::env(OFFLINE_AV_RELEASE_DIR)]} {set release_dir $::env(OFFLINE_AV_RELEASE_DIR)}
set bit [file join $release_dir ${name}.bit]
if {[file exists $bit]} {error "Existing bit is preserved: $bit; archive it explicitly before rebuilding"}
import_device eagle_s20.db -package EG4S20BG256
import_db [file join $folder final.db] -check_drc
file mkdir $release_dir
bitgen -bit $bit
puts "PASS OFFLINE_AV_BIT $target $bit; board validation pending"
exit

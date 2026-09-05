source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_800x600_adaptive_v69_subtitle_bram_aligned_manifest.tcl
set SYN_DB $LINEBUF_BUILD_ROOT/media_gate.db
if {![file exists $SYN_DB]} { error "Missing synthesis database: $SYN_DB" }
cd $LINEBUF_BUILD_ROOT
import_device eagle_s20.db -package EG4S20BG256
import_db $SYN_DB
read_adc $LINEBUF_ADC
read_sdc $LINEBUF_SDC
set_param place seed 23
place
update_timing -mode manhattan
report_area -io_info -file media_place.area
report_timing_summary -file media_place.timing
set_param route fix_hold off
route
fix_hold
set_param route fix_hold on
update_timing -mode final
report_timing_status -file media_phy.ts
report_timing_summary -file media_pr.timing
report_timing_exception -file media_exception.timing
flow_status -file media_pr.status
export_db $LINEBUF_BUILD_ROOT/media_pr.db
exit

source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_800x600_adaptive_v69_subtitle_bram_aligned_manifest.tcl
file mkdir $LINEBUF_BUILD_ROOT
cd $LINEBUF_BUILD_ROOT
import_device eagle_s20.db -package EG4S20BG256
read_hdl -include_dir $PROJECT_ROOT -file [join $LINEBUF_SOURCES "\n"] -top $LINEBUF_TOP
read_adc $LINEBUF_ADC
read_sdc $LINEBUF_SDC
optimize_rtl
report_area -file media_rtl.area
optimize_gate -packarea media_gate.area
legalize_phy_inst
update_timing
report_timing_status -file media_gate.ts
report_timing_summary -file media_gate.timing
flow_status -file media_syn.status
export_db $LINEBUF_BUILD_ROOT/media_gate.db
exit

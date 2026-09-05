# v69 retains the v67 media path and fixes only subtitle BRAM/read-coordinate alignment.
source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_800x600_adaptive_v65_multi5_transition_manifest.tcl
set old_top_index [lsearch -exact $LINEBUF_SOURCES $PROJECT_ROOT/src/memory/top_800x600.v]
set old_core_index [lsearch -exact $LINEBUF_SOURCES $PROJECT_ROOT/src/memory/sdram_bmp_row_top.v]
if {$old_top_index < 0 || $old_core_index < 0} { error "v65 source list changed unexpectedly" }
set LINEBUF_SOURCES [lreplace $LINEBUF_SOURCES $old_top_index $old_top_index \
    $PROJECT_ROOT/src/memory/top_800x600_v69_subtitle_bram_aligned.v]
set old_core_index [lsearch -exact $LINEBUF_SOURCES $PROJECT_ROOT/src/memory/sdram_bmp_row_top.v]
set LINEBUF_SOURCES [lreplace $LINEBUF_SOURCES $old_core_index $old_core_index \
    $PROJECT_ROOT/src/memory/sdram_bmp_row_top_v66.v]
set LINEBUF_SOURCES [concat $LINEBUF_SOURCES [list \
    $PROJECT_ROOT/src/video/uart_subtitle_overlay.v \
]]
set LINEBUF_TOP top_800x600_feature_v69_subtitle_bram_aligned
set LINEBUF_BUILD_ROOT $PROJECT_ROOT/_media_800x600_adaptive_v69_subtitle_bram_aligned
set LINEBUF_BIT $PROJECT_ROOT/release/hx4s20_800x600_adaptive_v69_subtitle_bram_aligned.bit
set LINEBUF_ADC $PROJECT_ROOT/constraints/top_800x600_adaptive_v66_uart_subtitle.adc
set LINEBUF_SDC $PROJECT_ROOT/constraints/top_800x600_adaptive_v69_subtitle_bram_aligned.sdc

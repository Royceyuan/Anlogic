# v57: v56 800x600 transport with corrected one-shot OSD, two BMP files,
# and a shorter key debounce interval.  Do not alter the proven video/SDRAM clocks.
source D:/Anlogic_information/hx4s20_multimedia_main/scripts/linebuf_1280_media_fifo128_v51_manifest.tcl
set LINEBUF_SOURCES [concat $LINEBUF_SOURCES [list \
    $PROJECT_ROOT/src/clock/video_pll_40m.v \
    $PROJECT_ROOT/src/memory/top_800x600.v \
]]
set LINEBUF_TOP top_800x600_feature_v57
set LINEBUF_SDC $PROJECT_ROOT/constraints/top_800x600_feature_v57.sdc
set LINEBUF_BUILD_ROOT $PROJECT_ROOT/_media_800x600_feature_v57
set LINEBUF_BIT $PROJECT_ROOT/release/hx4s20_800x600_feature_v57.bit

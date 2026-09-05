# v72 is an independent resource-optimized derivative of the frozen v71
# full-feature candidate.
source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_1280x720_v71_full_features_manifest.tcl
set old_top_index [lsearch -exact $LINEBUF_SOURCES $PROJECT_ROOT/src/memory/top_1280x720_feature_v71_full_features.v]
if {$old_top_index < 0} { error "v71 wrapper source not found" }
set LINEBUF_SOURCES [lreplace $LINEBUF_SOURCES $old_top_index $old_top_index \
    $PROJECT_ROOT/src/memory/top_1280x720_feature_v72_resource_optimized.v]
set LINEBUF_TOP top_1280x720_feature_v72_resource_optimized
set LINEBUF_BUILD_ROOT $PROJECT_ROOT/_media_1280x720_v72_resource_optimized_r3
set LINEBUF_BIT $PROJECT_ROOT/release/hx4s20_1280x720_v72_resource_optimized.bit
set LINEBUF_SDC $PROJECT_ROOT/constraints/top_1280x720_v72_resource_optimized.sdc

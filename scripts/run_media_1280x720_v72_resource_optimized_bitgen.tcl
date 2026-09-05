source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_1280x720_v72_resource_optimized_manifest.tcl
set PR_DB $LINEBUF_BUILD_ROOT/media_pr.db
if {![file exists $PR_DB]} { error "Missing P&R database: $PR_DB" }
cd $LINEBUF_BUILD_ROOT
import_device eagle_s20.db -package EG4S20BG256
import_db $PR_DB
bitgen -bit $LINEBUF_BIT
exit

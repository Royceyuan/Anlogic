source D:/Anlogic_information/hx4s20_multimedia_main/scripts/media_800x600_adaptive_v69_subtitle_bram_aligned_manifest.tcl
set PR_DB $LINEBUF_BUILD_ROOT/media_pr.db
if {![file exists $PR_DB]} { error "Missing P&R database: $PR_DB" }
import_device eagle_s20.db -package EG4S20BG256
import_db $PR_DB
bitgen -bit $LINEBUF_BIT
exit

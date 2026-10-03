# Enable interpolation only in a generated candidate, not the product entry.
set root [file normalize .]
source ./experiments/scale_quality/prepare_horizontal.tcl
set fd [open ./dual_fpga_museum_terminal_main_board.al r]
set project [read $fd]
close $fd
set fd [open ./_build_horizontal_interpolation/dual_fpga_museum_terminal_main_board.al w]
set kernel_file {<Verilog>
            <File Path="experiments/scale_quality/rgb565_interpolate.v">
                <FileInfo>
                    <Attr Name="AutoExcluded" Val="true"/>
                    <Attr Name="UsedInSyn" Val="true"/>
                    <Attr Name="UsedInP&R" Val="true"/>
                    <Attr Name="BelongTo" Val="design_1"/>
                    <Attr Name="CompileOrder" Val="200"/>
                </FileInfo>
            </File>}
set project [string map [list \
    src/memory/museum_display_subsystem.v _build_horizontal_interpolation/rtl/src/memory/museum_display_subsystem.v \
    src/memory/museum_media_core.v _build_horizontal_interpolation/rtl/src/memory/museum_media_core.v \
    src/storage/fat32_image_loader.v _build_horizontal_interpolation/rtl/src/storage/fat32_image_loader.v \
    <Verilog> $kernel_file] $project]
set project [string map [list "Path=\"$root\"" "Path=\"$root/_build_horizontal_interpolation\""] $project]
puts -nonewline $fd [string map {{<File Path="} {<File Path="../}} $project]
close $fd
set fd [open ./scripts/build_museum_main_board.tcl r]
set commands [read $fd]
close $fd
set include_file vendor/anlogic_lab6/sdram/enc_file/global_def.v
file mkdir ./_build_horizontal_interpolation/[file dirname $include_file]
file copy -force $include_file ./_build_horizontal_interpolation/$include_file
cd ./_build_horizontal_interpolation
eval [string map {
    ./_build_museum_main_board .
    ./constraints/ ../constraints/
} $commands]

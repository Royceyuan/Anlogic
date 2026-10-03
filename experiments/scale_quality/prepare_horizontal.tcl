# Callers set root to the product repository. Patch generated copies only.
set rtl $root/_build_horizontal_interpolation/rtl
foreach path {src/storage/fat32_image_loader.v src/memory/museum_media_core.v src/memory/museum_display_subsystem.v} {
    file mkdir [file dirname $rtl/$path]
    set fd [open $root/$path r]
    set content [read $fd]
    close $fd
    set fd [open $rtl/$path w]
    puts -nonewline $fd $content
    close $fd
}
exec git -C $root apply --directory=_build_horizontal_interpolation/rtl $root/experiments/scale_quality/horizontal_integration.patch

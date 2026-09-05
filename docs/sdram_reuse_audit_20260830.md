# SDRAM reuse audit: 2026-08-30

## Reusable reference

该历史测试工程已在 2026-09-01 清理，不属于当前统一 TD 工程。
is a TD 6.2 project targeting `EG4S20BG256`.  It contains a generated
`pic_sdram.bit`, a complete `top.adc`, `top.sdc`, encrypted SDRAM wrapper,
TF/BMP path, and the routed database.

The routed report is
`pic_sdram_Runs/phy_1/pic_sdram_phy.ts`:

- SDRAM clock `ext_mem_clk`: 125 MHz
- shifted SDRAM clock: `sys_pll_m0/pll_inst.clkc[2]`, 180-degree relation
- hard timing: `HWNS=0.005 ns`, `HTNS=0`
- device: `EG4S20BG256`

This is a valid implementation reference.  The files do not by themselves
prove that the archived bit was recently tested on the physical board.

## What can be copied

- the complete generated SDRAM PLL plus its shifted output
- `src/sdram/sdram.v` and all three encrypted controller files
- `frame_read_write`, the two frame FIFOs, and the TF/BMP read path
- the HDMI1/TF/LED/seven-segment pin assignments
- the TD project structure and clock constraints as a starting point

## What cannot be copied unchanged

- `video_define.v` and the timing path are hard-coded for 640x480
- the reference top uses `bmp_width=640` and `read_len=307200`
- the reference does not implement the requested 1280x720 aspect-preserving
  scaler and centered borders
- the separate `src/sdram_r` controller is incomplete and is not the proven
  path used by the reference bit

## Current root-cause correction

The active project copied the encrypted wrapper but replaced the reference
SDRAM clock relationship with a 25 MHz custom PLL.  Therefore the previous
v15/v16 raw-bus experiments did not reproduce the known reference operating
point.  The next candidate must first reproduce the reference 125 MHz and
180-degree SDRAM clock pair, then change only the 1280x720 video layer.

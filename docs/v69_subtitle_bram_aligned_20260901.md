# v69 subtitle BRAM alignment correction

- Bit: `release/hx4s20_800x600_adaptive_v69_subtitle_bram_aligned.bit`
- SHA-256: `2AA3F085E4E60F15898C2C15AAFBED1C1C79E6C35C1E77364EA4F8681CE6B75C`
- Top: `top_800x600_feature_v69_subtitle_bram_aligned`

## Root cause and scope

The Anlogic `EG_LOGIC_BRAM` simulation model reads its array on the read-clock
edge even with `REGMODE_B="NOREG"`; `OUTREG` adds another output register.
The old subtitle-only simulation incorrectly modeled `NOREG` as an asynchronous
read.  The RTL consequently inserted an unnecessary fabric byte register.  Its
pixel index and byte data were one memory word apart, which affected detailed
glyphs every four pixels while broad solid bars still looked correct.

v69 restores `NOREG`, consumes that one-cycle synchronous BRAM output directly,
and removes the extra byte-stage from the pixel decision.  v67 packet version,
two-bit payload, frame-edge commit, picture path, OSD, transitions, TF and
SDRAM remain unchanged.  The UART reply handshake fix from v68 is retained.

## Verification

- ModelSim BPP=1 and BPP=2: PASS.
- BPP=2 registered byte-boundary sequence: PASS for alpha values `3,0,0,0,
  1,2,3,0`, catching the prior four-pixel mismatch.
- UART `OK` reply, atomic commit, CRC reject and scroll: PASS.
- Synthesis: setup WNS `+1.709 ns`, TNS `0`; hold WNS `+0.471 ns`, TNS `0`.
- P&R: setup WNS `+2.974 ns`, TNS `0`; hold WNS `+0.023 ns`, TNS `0`.
- DRC: no error reported in final physical flow.

## Hardware status

`NOT TESTED`.  v65, v67 and v68 artifacts are retained as rollback references.

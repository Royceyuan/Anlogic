# FPGA Diagnostic Brief

## 0. Snapshot

- Project: `D:\Anlogic_information\hx4s20_multimedia_main`
- FPGA: HX4S20 / `EG4S20BG256`
- EDA: TangDynasty V6.2.168116
- Simulator: ModelSim at `E:\Modelsim\win64\vsim.exe`
- Git commit: `NO GIT REPOSITORY`
- Current branch: `NO GIT REPOSITORY`
- Target mode: HDMI1, 1280x720, 75 MHz pixel clock, 960x540 BMP source
- Stable baseline: v26 local BRAM registered-read path; user previously observed no horizontal stripe
- Current bitstream: `release\hx4s20_1280x720_media_fifo128_v51.bit`
- Bitstream SHA256: `C2A31D42E0B41544139E50D97987A92264CAE114F12D3AA26F7875999835958F`
- Hardware status: `FAIL` for v51: board locks the 1280x720 picture and LED4
  lights, but the certificate's fine text/QR features show persistent
  ghosting/jagged duplication.  This is an exact user-confirmed v51 result.

---

## 1. Current Objective

Produce a clear and stable 1280x720 HDMI image from the 960x540 `IMAGE0.BMP`, with no tearing, ghosting, jagged duplication, black screen, red fault screen, or reset-dependent variation.

---

## 2. Current Symptom

### Simulation

Targeted scaler, registered line-buffer, media-handshake, and FIFO128 block-writer regressions pass. The existing long real-media chain model still reports `active_mismatch=1613`; that model contains unknown/weak storage behavior and is not a sign-off result.

### Synthesis / P&R

v51 fresh TangDynasty synthesis and P&R/hold-fix completed successfully with DRC pass.

### Timing

Synthesis setup WNS +218 ps, hold WNS +471 ps, TNS 0. Final P&R setup WNS +873 ps, hold WNS +24 ps, TNS 0.

### Hardware

v51 has now been board-tested: the 1280x720 HDMI picture locks, LED4 is on,
and fine text/QR content remains visibly ghosted/jagged.  The result is a
hardware `FAIL`, not a timing or simulation failure.  Earlier red/blank
screens and values such as `507F`, `6006`, and `FFFF` remain historical
candidate observations and are not reclassified as v51 evidence.

---

## 3. Known-Good Boundary

| Boundary | Evidence | Confidence |
|---|---|---|
| HDMI timing can lock a monitor | v14 red diagnostic display and prior direct-pattern tests | HIGH |
| 1280x720 local scaler mapping | `sim/run_linebuf_scaler.do`: `PASS linebuf scaler` | HIGH |
| Registered line-buffer output with blanking prefetch | `sim/run_linebuf_registered_long.do`: `PASS registered linebuf two frames with blanking prefetch` | HIGH |
| Media handshake control for two frames | `sim/run_linebuf_media_handshake.do`: `PASS linebuf media handshake loop_frames=2 words=48` | HIGH |
| 128-word BMP block address/data ordering | `sim/run_bmp_block_writer_fifo128.do`: `FIFO128 block writer: PASS blocks=15 pixels=3840 words=1920` | HIGH |
| v51 TangDynasty implementation and timing | `_linebuf_1280_media_fifo128_v51/media_pr.status`, DRC and bitgen logs | HIGH (offline) |
| v26 local BRAM board path | `docs/sdram_v26_local_bram_readreg_build_20260830.md` and user board observation | HIGH |

---

## 4. Known-Bad Boundary

| Boundary | Evidence | Confidence |
|---|---|---|
| Real media path after leaving the local BRAM isolation | User observed v27 moving horizontal tearing/stripes; v27 is retained as a failing comparison bit | HIGH |
| Some historical diagnostic/media candidates | User reported red/blank output and values such as `FFFF`, `507F`, and `6006` with nonuniform LED states | MEDIUM (candidate mapping varies) |
| Full real-media simulation model | `run_sdram_bmp_row_top_chain_long.do` reports `active_mismatch=1613` with weak/unknown storage model | HIGH for model limitation; not a hardware root cause |

---

## 5. Latest Evidence

### ModelSim

- Test: `sim/run_linebuf_scaler.do`
- Result: PASS, errors 0, warnings 0
- Test: `sim/run_linebuf_registered_long.do`
- Result: PASS, errors 0, warnings 0
- Test: `sim/run_linebuf_media_handshake.do`
- Result: PASS, errors 0, warnings 0
- Test: `sim/run_bmp_block_writer_fifo128.do`
- Result: PASS, errors 0, warnings 0; 15 blocks, 3840 pixels, 1920 words
- Limitation: the long real-media chain is not a valid v51 sign-off simulation because its storage model produces unknown/weak mismatches.

### Waveform

- Signal: current full real-media VCD/FST
- Expected: cycle-accurate address/data, valid/data, FIFO, DE, line, and frame alignment
- Observed: `UNKNOWN`; no current design VCD/FST was found
- Offset: `UNKNOWN`
- GTKWave MCP was tested only with its small fixture VCD; it extracted four signals, but external GTKWave timing analysis is blocked by the missing executable.

### Synthesis

- Result: PASS, top `top_1280x720_linebuf_media_fifo128_v51`, device `EG4S20BG256`
- Key warnings: encrypted SDRAM undriven-pin and `PHY-5014` PLL feedback-route warnings remain from the shared controller/clock structure; no new differential evidence was established.

### P&R / STA

- Setup WNS: +873 ps
- Setup TNS: 0 ps
- Hold WNS: +24 ps
- Hold TNS: 0 ps
- DRC: PASS; no over-100% congestion tiles
- Report: `_linebuf_1280_media_fifo128_v51/media_pr.status`

### Hardware

- Bitstream: `release\hx4s20_1280x720_media_fifo128_v51.bit`
- SHA256: `C2A31D42E0B41544139E50D97987A92264CAE114F12D3AA26F7875999835958F`
- Switch state for the intended test: SW1-SW4 down, `0000`
- Expected LED: LED1 heartbeat; LED2 init; LED3 frame done; LED4 video healthy
- Expected 7-segment: approximately `80b8` after the 960x540 image load completes
- HDMI: actual v51 result is stable lock but visible fine-feature
  ghosting/jagged duplication; `FAIL`
- UART: `NOT TESTED`; only Bluetooth COM4/COM5 were enumerated
- Result: `FAIL` (board observed)

---

## 6. Last Known Good State

- RTL commit: `NO GIT REPOSITORY`
- Bitstream: `release\hx4s20_1280x720_linebuf_local_bram_readreg_v26.bit`
- SHA256: `5F78352E440A9281F425BDE498038F11C3B5DCCF956C8D137DE447A963C04E25`
- Resolution/mode: 1280x720 local video-clock source, registered BRAM read, no SDRAM/FIFO media read
- Timing: routed HWNS +0.038 ns, HTNS 0 in the v26 report; encrypted SDRAM macro timing was intentionally not used as the isolation verdict
- Hardware result: user previously reported no horizontal stripe; this is the preserved rollback baseline

---

## 7. Last Change

- Files changed: `src/memory/top_1280x720_linebuf_media.v`, `scripts/linebuf_1280_media_fifo128_v51_manifest.tcl`, v51 build Tcl scripts, and `sim/tb_bmp_block_writer_fifo128.v` / its `.do` file
- RTL change: added `top_1280x720_linebuf_media_fifo128_v51` using 128-word write/read bursts, registered line-buffer output, v26 output pipeline, direct 24-bit BMP mode, and OSD/fade disabled
- Constraint change: no timing exception was added; the v51 manifest selects the official 25 MHz system PLL and existing 1280x720 timing values
- Testbench change: added a FIFO128 block-writer ordering test; no expected value was changed to manufacture PASS
- Reason: reduce transaction/boundary pressure and verify address/data ordering across 128-word block and row boundaries
- Intended effect: remove media read/write misalignment suspected of causing tearing while preserving the known-good HDMI timing

---

## 8. Result of Last Experiment

### Hypothesis

Long or misaligned SDRAM transactions and media read boundaries contribute to the tearing/ghosting seen after the local BRAM path.

### Experiment

Build v51 with 128-word SDRAM write/read bursts, registered line-buffer output, direct 960x540 BMP input, OSD/fade disabled, and the official system PLL.

### Expected result

Offline block ordering, line-buffer timing, synthesis, P&R, and timing should pass; the board should show a clear, stable image without tearing.

### Actual result

Offline checks passed and `release\hx4s20_1280x720_media_fifo128_v51.bit` was
generated.  The user then confirmed the exact v51 board result: it locks but
has visible fine-feature ghosting/jagged duplication with LED4 on.

### Interpretation

The result rules out a simple “unprogrammed/no-lock” explanation.  It does not
yet distinguish nearest-neighbour 960x540 scaling from SDRAM/FIFO data error,
so the next implementation is a full-frame address-derived v52 readback
diagnostic.  Hardware root cause remains `UNKNOWN`.

---

## 9. Ruled-Out Hypotheses

| Hypothesis | Why ruled out | Evidence |
|---|---|---|
| Monitor cannot lock 1280x720 timing | Prior diagnostic/direct-pattern candidates locked the same monitor | v14/v21 history in `HANDOFF.md` |
| Pure scaler or registered line-buffer mapping is inherently wrong | Targeted two-frame and exact 3:4 regressions pass | `sim/run_linebuf_scaler.do`, `sim/run_linebuf_registered_long.do` |
| v51 fails the offline timing gate | Fresh final setup/hold WNS are positive and TNS is zero | `media_pr.status` |

---

## 10. Remaining Hypotheses

| Rank | Hypothesis | Evidence For | Evidence Against | Confidence |
|---:|---|---|---|---|
| 1 | Real media SDRAM read/FIFO ownership or pixel-valid alignment still differs on hardware | v27 hardware tearing; full real-media model is not sign-off | FIFO128 writer and local line-buffer tests pass | MEDIUM |
| 2 | TF/FAT32/BMP row addressing, format, or card timing differs from the isolated writer model | User supplied multiple card-generated images and symptoms varied by reset/program cycle | FIFO128 row/block ordering test passes; exact v51 card test missing | MEDIUM |
| 3 | Board was running a different candidate, or reset/card initialization state varied | User reported different screens and 7-segment codes after reprogram/reset | v51 artifact hash is fixed, but board hash was not observed | MEDIUM |
| 4 | HDMI electrical/cable issue | Tearing appears in media path | v14/v21 timing lock argues against it as primary cause | LOW |

Ranking between 1-3 is uncertain until the exact v51 hash is tested on the board.

---

## 11. Critical Signal Relationships

| Signal A | Signal B | Expected Relation | Observed Relation |
|---|---|---|---|
| `app_wr_addr` | `app_wr_din` | Address and packed RGB565 data refer to the same pixel/beat | PASS in FIFO128 block-writer simulation; hardware UNKNOWN |
| `fifo_wr_en` | `fifo_rd_en` | Enqueue/dequeue boundaries do not cross a block or frame ownership boundary | PASS in handshake simulation for two frames; full media hardware UNKNOWN |
| `video_read_en` | line-buffer read data | Registered read latency is included before active output | PASS in registered line-buffer regression; real media readback UNKNOWN |
| `DE` | output pixel | DE/HS/VS and pixel are delayed together at line/frame boundaries | PASS in local path simulation; board UNKNOWN |
| `frame_done` / status | LED3 / 7-segment | Diagnostic outputs reflect loader/frame completion without masking errors | RTL mapping is known; v51 board observation UNKNOWN |

---

## 12. Timing Status

### Setup

- WNS: +873 ps final P&R
- TNS: 0 ps
- Worst path: `UNKNOWN` (not extracted into a compact path record)

### Hold

- WNS: +24 ps final P&R
- TNS: 0 ps
- Worst path: `UNKNOWN` (not extracted into a compact path record)

### Constraint concerns

Shared encrypted SDRAM and PLL feedback-route warnings remain. No false path, multicycle path, or clock exception was added for v51.

### Timing verdict

`PASS` offline; hardware timing/functional verdict `UNKNOWN`.

---

## 13. Regression Status

| Test | Status | Notes |
|---|---|---|
| Stable baseline | PASS (preserved) | v26 artifact and SHA256 retained; no reprogramming performed |
| Target mode | PASS offline / FAIL hardware | v51 locks but has user-observed fine-feature ghosting/jagged duplication |
| SDRAM | PASS for FIFO128 ordering / UNKNOWN full media | Full long-chain model mismatch is not sign-off evidence |
| HDMI | PASS local timing/path simulation / FAIL v51 media picture | Monitor lock is proven; v51 picture quality is not accepted |
| KEY/input | UNKNOWN | No board input test was run during this audit |

---

## 14. Current Root-Cause Boundary

Local scaler, registered line-buffer behavior, FIFO128 block ordering, and v51 offline timing are verified; the remaining failure is bounded to the real media SDRAM/readback/line-frame ownership path or board execution state, but the evidence is not sufficient to select one root cause.

---

## 15. Recommended Next Experiment

### Question

Does the v52 diagnostic BMP survive a full SDRAM write/readback with every
returned word correct?  The fresh v52 artifact now exists at
`release/hx4s20_1280x720_media_fifo128_v52_diag.bit`, SHA256
`CDF47FCBE4A22A1296E7F4C067F8637F9BE6836EFA2C806E03ACCF9DB5B7DAE3`.
Its fresh final P&R has setup WNS +586 ps, hold WNS +23 ps, and zero TNS;
hardware status is still `NOT TESTED`.

### Change

Program the separately documented v52 diagnostic bit (never automatically),
place `testdata\generated\sdram_diag_960x540.bmp` at TF root as
`IMAGE0.BMP`, use SW1-SW4=`0000`, press KEY1 once, then record LEDs and the
7-segment display.  Use SW=`0001/0010/0011` only if `DEAD` is shown.

### Do NOT change

Do not change RTL, HDMI timing, SDC exceptions, TF image dimensions, or the v26 rollback bit during this experiment. Do not auto-program from an MCP.

### Expected Outcome A

`D0A5`, LED1 heartbeat, LED2/3 on, LED4 on.  HDMI timing remains locked; the
diagnostic readback stage intentionally does not claim a picture-quality pass.

Interpretation: the actual media SDRAM/FIFO contents match the diagnostic
pattern.  The remaining v51 fine-feature defect is then the 960x540
nearest-neighbour scaling path, so proceed to v53 native validation.

### Expected Outcome B

`DEAD`, LED4 off, with a first-error page available from the three diagnostic
switch positions.

Interpretation: diagnose from the stable or reset-varying first-error address,
actual word, and expected word.  Do not advance to v53 board testing.

### Expected Outcome C

Red/blank screen, `FFFF`/other fault code, or a different LED pattern.

Interpretation: first reconcile bitstream identity, TF/card initialization, reset release, and loader error status; do not infer a new pipeline delay.

### Why this experiment

It separates a 960x540 scaling limitation from real SDRAM/FIFO corruption with
one observable and repeatable hardware result.

---

## 16. Constraints / Guardrails

- Preserve the 640x480 and v26 stable baselines.
- Keep changes local and minimal.
- Do not modify testbench expected values to manufacture PASS.
- Do not add timing exceptions to hide a functional problem.
- Do not auto-program the FPGA.
- Keep simulation, synthesis/P&R, timing, and hardware results separate.
- One experiment should answer one question.

---

## 17. Open Questions

1. Does v52's full-frame readback of the supplied diagnostic BMP pass on three
   cold starts and ten KEY1 resets?
2. If it fails, are first-error address/data stable, boundary-related, or
   reset-dependent?
3. Can a production-size, real-BMP SDRAM/FIFO waveform be captured with
   concrete first-error evidence?
4. Is there an identified FPGA UART rather than Bluetooth COM4/COM5?

---

## 18. Handoff Summary

1. v51 is `hx4s20_1280x720_media_fifo128_v51.bit`, SHA256 `C2A31D42...5958F`.
2. TangDynasty synthesis/P&R/DRC/bitgen pass; final setup +873 ps, hold +24 ps, TNS 0.
3. Scaler, registered line-buffer, handshake, and FIFO128 ordering simulations pass.
4. The full real-media long simulation remains model-limited (`active_mismatch=1613`).
5. v26 local BRAM is the preserved hardware-good rollback baseline.
6. Prior real-media board candidates showed tearing/ghosting and variable fault codes.
7. v51 hardware is `FAIL`: monitor lock and LED4 on, but fine features ghost/
   jag; no claim of a final fix is justified.
8. v52 full-frame readback is the next board experiment; the fresh bit is
   `release/hx4s20_1280x720_media_fifo128_v52_diag.bit`, SHA256
   `CDF47FCBE4A22A1296E7F4C067F8637F9BE6836EFA2C806E03ACCF9DB5B7DAE3`,
   with explicit `D000/D001/D0A5/DEAD` states.  Details are in
   `docs/sdram_v52_diag_release_20260831.md`.
9. The v53 native 1280x720 / 50MHz+180-degree candidate exists in RTL, but
   its fresh P&R is `FAIL` (status setup WNS -915 ps; detailed worst hold
   -20 ps).  No v53 bit was generated or approved for board use.
10. v52 hardware returned `DEAD`, first-error address `01E0`, actual low
    `0000`, expected low `0000`; v52b adds SW pages `0100/0101` for actual/
    expected high halves.  Its bit SHA256 is
    `6736928C6C2944B1BC7CAA9F7966D5C484348472C8A47386D4A90F5EF521DE26`.
11. v52b showed actual high `0000` versus expected high `FFFF` at the same
    address. The earlier v52c conclusion that this proved a 480-word row-tail
    overwrite was incorrect: v52/v52b use `ADAPTIVE_BMP=0` and the
    `bmp_sdram_block_writer`, with 259200 words exactly divisible by 128, so
    the changed short-tail code is not exercised. v52c consequently reproduced
    the same board result and is superseded.
12. Production-size simulation of the actual FAT32 top-down BMP ->
    `bmp_row_buffer` -> `bmp_sdram_block_writer` path passed all 259200 words,
    including the `0x01E0` row boundary, with zero data errors. The remaining
    A/B candidate is v52d, which changes only the SDRAM PLL from
    `sys_pll_50m_official.v` to the previously used 25 MHz/180-degree
    `sys_pll_25m_180phase_v37.v`. v52d bit SHA256 is
    `9FBAF10FF7A30B28D2D968E9A229332496E22FA62ED00053B930BA2C41A0F6F6`;
    fresh final P&R is setup WNS +647 ps, hold WNS +30 ps, TNS 0.
13. Boundary bit `release/hx4s20_1280x720_sdram_boundary_diag.bit` was tested
    on hardware and showed `7800` (fail at application address `0`), but its
    HDMI outputs were intentionally tied off, so a blank monitor was expected.
14. A serialized replacement is built at
    `release/hx4s20_1280x720_sdram_serial_diag.bit`, SHA256
    `D3905AD83FEF18011D330A3E1DF18F8CA96D1E633DA17F6588D689ABB50B7C9F`.
    It probes addresses `0,479,480,511,512` one transaction at a time and
    outputs blue/red/green diagnostic HDMI. Final P&R is setup `+877 ps`, hold
    `+46 ps`, TNS `0`, DRC passed. This is the next boundary experiment; it is
    not an image-display bitstream.
15. Hardware result of the serialized replacement: red screen, LED2/LED4 on,
    LED3 off, `DEAD`; failing address `0000`, actual data `FFFF_FFFF`,
    expected data `5A00_0000`. This is a fixed all-ones readback at address 0,
    not a row or burst-boundary error.
16. A separate native 50 MHz controller experiment was synthesized, but its
    fresh routed timing is setup WNS `-656 ps` / TNS `-19664 ps` and hold WNS
    `-241 ps` / TNS `-6551 ps`; no bitstream was generated or approved.
17. Adding the dedicated 50 MHz/180-degree SDRAM clock to that native
    controller did not close timing: final setup remained `-656 ps` / TNS
    `-19664 ps`, while hold degraded to `-4262 ps` / TNS `-12251 ps`. It was
    rejected without bitgen.
18. v54 is a separate native 800x600 (4:3) display candidate: no spatial
    scaler, OSD, or fade; source and HDMI geometry are both 800x600, with the
    existing 25 MHz SDRAM-side controller retained unchanged. Its corrected
    CDC constraints group the board 50 MHz, SDRAM PLL, and video PLL domains
    separately while keeping the SDRAM clock and 180-degree output related.
    Fresh final P&R is setup WNS `+2756 ps`, hold WNS `+38 ps`, TNS `0`; bit
    `release/hx4s20_800x600_native_v54.bit` SHA256
    `139D68F3C375D6273E62742AEB83EE740BCCE8FFB4BB2443C9A57CAB6FB0C20D`.
    The matching top-down 24-bit BMP is
    `release/IMAGE0_800x600_native_v54.BMP` SHA256
    `F35451180D4FE6C20A201012A65603D82CDE448956EE19F80086CC331A7EF921`.
    This candidate is `NOT PASSED`: its changed aspect ratio removes the
    960x540-to-1280x720 nearest-neighbor artifact but cannot itself repair the
    serialized SDRAM address-0 all-ones readback failure.
19. Hardware result for v54: `PASS` for the 800x600 native image path.  The
    monitor displays the supplied image clearly; LED2, LED3, and LED4 are on,
    and the seven-segment display reads `8078`.  This is the first verified
    stable real-media baseline above the official 640x480 example.  It proves
    that the 4:3 native geometry removes the observed scaling artifact for this
    path.  It does not retroactively validate the failed 1280x720 variants.
20. v55 is a native 1024x768 (4:3) candidate built from the v54 structure.
    It changes only the source/display geometry and reuses the existing 65 MHz
    pixel/325 MHz serializer PLL, 25 MHz SDRAM-side clock, 128-word transfers,
    and CDC boundary.  Fresh synthesis passed (setup `+628 ps`, hold `+471
    ps`); fresh final P&R passed (setup `+1332 ps`, hold `+22 ps`, TNS `0`).
    Bit `release/hx4s20_1024x768_native_v55.bit` SHA256
    `05EC9CD89CC4218A3C6712963502B8AC137AFA2591DEE592BEE973BD510CA568`;
    matching 1024x768 top-down 24-bit BMP
    `release/IMAGE0_1024x768_native_v55.BMP` SHA256
    `189FECF892FB990C726E78A1BA85230B256F9BDC09A2D2F61134B8B5793F0CA2`.
    Hardware is `NOT TESTED`; this resolution raises average SDRAM read demand
    from 14.4 to 23.6 million 32-bit words/s, close to the 25 MHz controller
    ceiling, so LED4/monitor stability must be checked on board.
21. Hardware result for v55: `FAIL`. LED2 and LED3 are on, LED4 is off,
    seven-segment reads `80F8`, and HDMI shows a large corrupted mosaic.  The
    known-good v54 boundary is 800x600.  LED4 off is the RTL's recorded video
    FIFO underflow condition; with 1024x768@60 the required average read rate
    is 23.6 million 32-bit words/s before refresh/command overhead, leaving no
    usable margin below a 25 MHz SDRAM-side controller.  Current root cause is
    therefore insufficient sustained read bandwidth, not BMP geometry or HDMI
    lock.  Do not retry v55 unchanged.
22. v56 restores OSD, KEY2 image switching, KEY3/KEY4 brightness/contrast,
    SW4 automatic carousel, and frame-boundary fade on the board-proven native
    800x600 v54 data path. No SDRAM/FIFO/HDMI timing parameters changed.
    Fresh final P&R is setup WNS `+3207 ps`, hold WNS `+24 ps`, TNS `0`; bit
    `release/hx4s20_800x600_feature_v56.bit` SHA256
    `FEC0FF357CD565854BE9E3D2B83F9D81AF181F8C66B3A86E31A064BBE550DAAB`.
    Hardware is `NOT TESTED`; test procedure is in
    `docs/v56_800x600_feature_board_test.md`.

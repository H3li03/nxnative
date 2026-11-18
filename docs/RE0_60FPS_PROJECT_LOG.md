# Resident Evil 0 — 60 FPS investigation log

> Persistent technical notebook for the RE0 frame-pacing investigation in `H3li03/nxnative`.
> Last consolidated: 2026-11-18.
>
> This document records conversation context available to the assistant and repository evidence. It is not a substitute for runtime validation. Keep observations, source facts, and hypotheses separate.

## 1. Objective and current conclusion

**Goal:** achieve genuine 60 rendered/presented frames per second in Resident Evil 0 while preserving the original game/simulation speed.

The user explicitly confirmed that the current experimental 60 FPS behavior runs **everything at approximately 2× speed** (character movement, animations, timers/gameplay as a whole). Therefore the experiment that raises the paired timing fields from 30/30 to 60/60 is not an acceptable solution: it changes simulation timing, not merely presentation cadence.

Working direction:
- Preserve the game's original simulation time step / timing semantics (currently observed values 30 and 30).
- Find and decouple the 30 FPS limiter or present cadence from the simulation update.
- Investigate whether the engine can update simulation at 30 Hz and render at 60 Hz using interpolation, or whether its render/present loop can be safely decoupled.
- Do not assume that changing a field called a frame limit is safe: RE Engine examples show that a frame limiter can also determine how much real elapsed time the simulation consumes.

**Do not change +0x48/+0x4c to 60 again as a proposed fix without first proving their semantics.** Do not claim success until both 60 presented FPS and correct real-time game speed are measured in the same run.

## 2. Repository and game identity

- Repository: `H3li03/nxnative`
- Remote: `https://github.com/H3li03/nxnative.git`
- Local working copy mentioned by user: `/Users/maclifedrive/Downloads/nxnative-clean-check`
- Game: Resident Evil 0, Nintendo Switch title ID `010097000BC10000`
- Main build ID: `fb4239aa962b429b3d1776af92d93e79`
- Profile: `dm/games/010097000BC10000/game.tsv`
- The profile currently has `fps_target 30` and `fps_max 120`; 30 is deliberately retained as the tested/default target. Do not silently change the profile default to 60.
- The profile identifies version 1.0.0 and main build ID above.

### Git references noted in the conversation

These are historical references from the project discussion; re-check branch heads before basing new work on them.

- Base branch: `analysis/re0-present-interval-20261118`
- Base SHA: `0288d1ab0ae2bc3c5304ce34af3c77d7cfd75812`
- Experimental branch: `experiment/re0-60fps-opt-in-20261118`
- An early experimental patch commit: `3b7c6d79de81e2f0a49cdf044fff6120e98f0e63`
- A later repository HEAD reported in the conversation: `74d65ec1887e52a0e00477c29531214da3da9c39`
- Remote and local were reported synchronized at that later HEAD.
- The early patch was described as 84 additions / 0 removals in `dm/host/hle_fpslock.c`, relative to the base. Do not assume that exact diff still describes the latest branch head.

## 3. Relevant code and reverse-engineering notes

### `dm/host/hle_fpslock.c`

Repository source inspected while preparing this log contains:
- Existing generic frame-lock handling for multiple games.
- A read-only RE0 timing survey/probe targeting main build `fb4239aa962b429b3d1776af92d93e79`.
- The probe follows the global slot and instance pointers, samples timing fields, and logs render flags. It is designed not to write game memory.
- `rd()` reads process memory using `vm_read_overwrite(mach_task_self(), ...)`.

A prior experimental change was described as opt-in via `DM_RE0_TIMING_60=1`. It checked the target build, singleton/instance identity, and expected 30/30 values at offsets +0x48/+0x4c before attempting to write 60/60 and read them back. This is an experimental/historical description; inspect the exact current source and diff before relying on it.

**Important memory-safety question:** a previous implementation used `memcpy((void *)(uintptr_t)(instance + offset), ...)` to write fields. The fact that `rd()` can read an address through Mach VM APIs does not prove that the same address is a valid, writable host pointer for `memcpy`. Before any write experiment, establish the correct guest-memory write API/mapping and protection semantics. Do not treat successful readback alone as proof that an arbitrary pointer cast is safe.

### RE0 symbols and offsets from prior analysis

- `sMain::move`: main offset `0x7aa5a0`, size `0x50c`.
- `sRender::end`: main offset `0x7ce660`.
- Global timing slot: main + `0x1285650`.
- `sMain::mpInstance` global: main + `0x1baac60`.
- `sRender::mpInstance` global: main + `0x1bab108`.
- Shared frame constant: main + `0xfca870`.
- Probe verifies the pointer chain and whether the slot owner equals the main singleton.
- The RE0 probe was described as taking 12 samples at 120-present intervals, with singleton matching checks and read-only sampling.

### Timing fields

- The active `sMain` instance has float fields at +`0x48` and +`0x4c`.
- Prior disassembly analysis found `sMain::move` reads both fields: +0x48 scales a delta-time quantity; +0x4c participates in normalization / threshold behavior.
- Runtime survey observed both fields at 30.0.
- +0x50 was observed as 0 in the probe.
- A constructor was reported to initialize adjacent floats +0x48 and +0x4c to 30.0 in the related RE timing investigation.
- Do not yet assign a definitive one-field-one-purpose semantic without following all writers/readers and call paths. The pair may jointly encode the timing convention.
- User's 2×-speed confirmation is strong evidence that raising the pair to 60/60 changes simulation speed in the tested configuration.

### Render path

- `sRender::end` at `0x7ce660` was inspected.
- Previously observed live flags: +`0x2f` = 1, +`0x29` = 1, +`0x2a` = 0.
- The earlier control-flow analysis reported that `sRender::end` exits before a suspected timing gate under those flag values.
- A previous NOP experiment at `sMain::move` offset `0x7aa934` (described as a `SleepThread` call) did not achieve 60 FPS.
- This makes it important to trace the actual frame loop, render submission, GPU completion/fence waits, and present/acquire pacing rather than guessing at a single sleep.

## 4. Runtime evidence and logs

### Read-only RE0 timing probe

A prior probe report recorded:
- 12 samples.
- `slot_owner_match=1`.
- `main_match=1`.
- +0x48 = 30.
- +0x4c = 30.
- +0x50 = 0.
- `frame_constant=1000`.

This supports the identity of the sampled object and the observed default values. It does not establish 60 FPS behavior.

A file named `re0-timing-probe-60fps.log` was reported on the experimental branch. Its first sample showed 30/30 and later samples showed 60/60 through sample 12. This proves that the sampled values changed in that test; by itself it does **not** prove 60 presented FPS or correct simulation speed.

### Earlier present/gameplay measurements

One earlier gameplay capture was described as approximately 66 seconds and 1,886 samples:
- Present tick around 60 Hz.
- Frame interval median around 33.339 ms.
- Work time median around 33.3 ms.
- CPU/GPU were not considered the limiting bottleneck in that capture.

A separate `re0-runtime.log` from a prior remote session was described as 27 KB:
- Host target 60 / present tick 60.
- Game timing remained 30/30.
- Frame duration remained around 33.3 ms.
This was not a successful 60 FPS game run.

A local `re0-gameplay-runtime.log` was described as 1,404,162 bytes, with blob SHA `9e59eaf1af402ffc6504725d2bf29c65a17997e7`. The same blob SHA and size were reported for local HEAD and remote branch at the time. A GitHub connector fetch returned empty content despite the file existing locally; treat that as a connector retrieval limitation, not evidence that the file is empty.

The pasted head/tail of that gameplay log showed:
- Launcher environment: `DM_FPS_TARGET=60`, `DM_FPS_HOLD=on`, `DM_OPMODE=1`.
- Host build commit `820100b84865` (this is the dmhost build commit, not the game's main Build ID).
- Around samples 1850–1877: `@frame_ms` roughly 32.9–34.0 ms; `@work_ms` roughly 32.7–33.9 ms; `@display_ms` around 33.3 ms; `@presented_ms` typically 33.333 ms, occasionally 50 ms; `@gpu_ms` around 7.2–8.4 ms; `@link_ticks` usually 2, sometimes 3.
- This particular log therefore describes roughly 30 frames/s. It may be from a different run than the user's later 60 FPS / 2× speed observation. Do not use it to deny the user's observation.

### User's direct runtime observation (latest clarification)

The user explicitly stated:
- The game does run at 60 FPS in the experimental test.
- Everything runs at double speed.
- The target is to retain 60 FPS while restoring normal game speed.

This is the most important current test observation. The log evidence above must be associated with its own run and not conflated with this sped-up test.

## 5. Other relevant frame-pacing context in the host

The inspected `hle_fpslock.c` includes comments/examples showing that frame timing is game-specific:
- Some games' frame limit values are also used by the simulation step.
- Other games step according to actual elapsed time and can tolerate a higher render cap.
- The file documents examples where a frame time in milliseconds and present interval interact; too-short frame time can result in cadence issues.
- The source notes that a 60 FPS frame-time value may use a small margin (currently `MS_MARGIN 0.5f`) to avoid missing vsync due to work after the timer's start.
- These examples are useful methodology, not proof that RE0 uses the same mechanism.

## 6. Hypotheses to test (not established facts)

1. RE0's simulation update and rendering are coupled to a 30 Hz loop.
2. The 30/30 pair may be consumed by simulation time scaling and/or frame pacing.
3. A distinct present interval, wait, fence, or frame limiter may be enforcing every-other-vsync behavior.
4. A true 60 FPS implementation may require a 30 Hz simulation with render interpolation, or a safe decoupling of render cadence from simulation.
5. The early NOP of one `SleepThread` call was insufficient because another limiter / synchronization path remained active, or because the loop's simulation cadence is controlled elsewhere.

Do not promote these hypotheses to facts until backed by disassembly, instrumentation, or controlled tests.

## 7. Recommended next investigation

1. Identify the exact test build and exact environment for the run that produced 60 FPS at 2× speed. Preserve its complete log and record whether `DM_RE0_TIMING_60=1` was enabled.
2. Reproduce a baseline run with original 30/30 timing and record, in the same capture:
   - presented frames and timestamps,
   - simulation/update calls per second,
   - game-time progression (e.g. in-game timer),
   - character displacement per real second,
   - animation progression per real second.
3. Reproduce the 60/60 run and collect the same measurements. This quantifies the 2× relation and confirms which code path was active.
4. Trace every read and write of the +0x48/+0x4c fields, including constructor, post-boot initialization, and any per-frame writes.
5. Trace callers and callees around `sMain::move` and `sRender::end`; identify where simulation update, render submission, GPU wait, present/acquire and sleep occur.
6. Determine whether the present interval is set to 2, whether the host overrides it, and whether the observed 60 Hz tick is merely the display/vsync clock while the game submits one frame every two ticks.
7. Inspect existing engine timing/interpolation support before implementing an extra render between simulation ticks.
8. Only after identifying a safe mechanism, make one isolated opt-in change. Keep the default profile at 30 FPS and include build-ID guards.
9. Validate the same-run acceptance criteria:
   - 60 presented frames/s sustained;
   - original gameplay speed (movement, animation, timers);
   - no duplicated/incorrect input, physics instability, or visual interpolation artifacts;
   - no regressions at the default 30 FPS setting.

## 8. Working rules for future sessions

- Do not modify source unless the user explicitly asks for implementation or approves a proposed edit.
- Do not change the game's default profile from 30 FPS without explicit approval and validation.
- Do not infer successful runtime behavior from a successful compile, a memory readback, or a changed timing field.
- Never conflate host build commit, game Build ID, Git commit SHA, and runtime log identity.
- Label every datum with its source: source inspection, disassembly, probe, runtime log, or user observation.
- Record exact branch, commit, build ID, environment variables, and test procedure for every new test.
- Preserve failed experiments and explain what they ruled out.
- When new evidence contradicts an older log, keep both with their run identities; do not silently overwrite history.

## 9. Change history for this notebook

- 2026-11-18: Initial consolidation from available conversation context and repository inspection.
- 2026-11-18: Confirmed current project direction: decouple rendering/presentation from simulation; the user's 60 FPS test runs all gameplay at approximately 2× speed.


## 10. New experiment: presentation-only 60 Hz (2026-11-18)

### Branch and commit

- New branch: `experiment/re0-display-60-sim30-20261118`
- Parent: `c1766636bb0b6e1d22c24ac9addaa9cb33567273`
- Patch commit: `1707c07670e8901779e499708903bd62b4360912`
- Changed file: `dm/gfx/nvn/hle_nvn.c` only.
- Change: in `configured_display_mode()`, add an opt-in Resident Evil 0 Title ID case (`010097000BC10000`). It selects NVN display pacing only when `DM_RE0_PRESENT_60=1` and the selected target is exactly 60 (`DM_FPS_TARGET=60`, or profile target if environment absent). The existing `DM_PRESENT_INTERVAL` override remains higher priority.
- The patch does not write RE0 guest memory, does not change +0x48/+0x4c, and does not change `game.tsv` (default remains 30 fps).
- The existing `DM_RE0_TIMING_60` experiment remains in the source but must be **unset** for this test.

### Why this experiment

The NVN layer already supports display mode: it ignores the game's requested present interval and follows one present per display-link tick. `fps_present_cap()` permits a 60 fps present cap when display mode is active and the engine has no host-written engine limiter. RE0 currently lacks a special display-mode case; another Resident Evil Title ID (`010050F00BC1A000`, HD Remaster) has its own special handling, which is not assumed to apply to RE0.

This patch isolates the presentation policy from the previously tested 30/30 → 60/60 guest-memory write. It does not synthesize extra frames and cannot guarantee 60 unique rendered frames if RE0's own update/render loop still waits at 30 Hz. That is exactly what the runtime test is meant to establish.

### Test recipe

Build and run this branch with:
- `DM_FPS_TARGET=60`
- `DM_RE0_PRESENT_60=1`
- `DM_RE0_TIMING_60` unset (or explicitly `0`)
- `DM_PRESENT_INTERVAL` unset, so the new opt-in branch is exercised rather than the global override.

Keep all other test variables identical to the baseline. Do not change the game profile.

### Expected diagnostics and acceptance

Confirm in the log:
- `[nvn] present tick 60 Hz`
- `interval mode display`
- `present cap 60 fps ... applied by the present interval alone`
- The RE0 read-only timing probe continues to report +0x48/+0x4c as 30/30.

Measure the same gameplay segment as baseline:
- `@presented_ms` / actual unique presentation cadence near 16.667 ms (not just a 60 Hz display tick);
- game timer and character movement per real second equal to baseline;
- animation progression equal to baseline.

Interpretation:
- **60 presents/s + normal game speed:** promising decoupling; inspect for visual duplication and input/physics correctness.
- **30 presents/s + normal speed:** RE0's native loop or another wait still limits frame submissions; this patch only changed the host present policy.
- **60 presents/s + 2× speed:** display pacing alone is not enough; another simulation-step dependency is coupled to each rendered frame, so revert this branch and trace the update path before trying another timing write.
- **unstable/irregular cadence:** capture full NVN acquire/present timings and compare `@frame_ms`, `@work_ms`, `@presented_ms`, `@gpu_ms`, and `@link_ticks`.

No build or runtime test has been performed by the assistant. The patch is committed but remains unvalidated.


## 11. Read-only NVN frame-loop trace (2026-11-18)

- Branch: `experiment/re0-frame-loop-trace-20261118`
- Parent: `ac48c76d21862c0e4cccc2aba17c0c08341cba20`
- Source commit: `ba2569b60a6be301d7dba85138b57fc1267ca64a`
- Changed source: `dm/gfx/nvn/hle_nvn.c`
- New opt-in: `DM_RE0_TRACE_PRESENT=1` (RE0 Title ID guard).
- The trace samples NVN `nvnWindowAcquireTexture` and `nvnQueuePresentTexture` separately. It logs the first four events and then every 60 events, with elapsed milliseconds, game-requested interval, effective interval, display-mode flag, tick rate, and caller module/offset.
- The trace is read-only: it does not write guest memory, change frame pacing, alter present intervals, or modify the game profile. It is intended to distinguish a 30 Hz game submission loop from an NVN/display pacing problem.
- Build and runtime validation have not been performed by the assistant. The patch is committed but unvalidated.

Test configuration:
- `DM_FPS_TARGET=60`
- `DM_RE0_PRESENT_60=1`
- `DM_RE0_TIMING_60=0` (or unset)
- `DM_RE0_TRACE_PRESENT=1`
- `DM_PRESENT_INTERVAL` unset

Interpretation:
- Acquire and present deltas near 33.3 ms: the game submits frames at about 30 Hz before presentation; investigate the MT Framework frame loop and its waits.
- Acquire/present deltas near 16.7 ms but visible output remains 30: investigate downstream queue/display behavior and frame drops.
- Acquire at 16.7 ms but present at 33.3 ms: investigate work between texture acquisition and queue submission.
- Compare the caller offsets and the first interval/mode log; do not change timing fields based only on this trace.


## 12. RE0 single-field MT Framework limiter (2026-11-18)

### External reference and finding

- Exact title/build match found in FPSLocker-Warehouse: Title ID `010097000BC10000`, Build ID `FB4239AA962B429B`, version 1.0.0.
- Reference patch: https://github.com/masagrator/FPSLocker-Warehouse/blob/b765680937f1177ec2719a6d31490b2d6e4edcb3/SaltySD/plugins/FPSLocker/patches/010097000BC10000/FB4239AA962B429B.yaml
- Its `ALL_FPS` rule writes `FPS_LOCK_TARGET` only to `[MAIN, 0x1BAAC60, 0x4C]` as a float. It does not write `+0x48`.
- Its cutscene rules separately detect prerendered cutscenes and temporarily select 30 Hz. That behavior is documented as a follow-up validation item; this first host-side port focuses on the gameplay limiter.

### Host implementation

- Branch: `experiment/re0-single-field-60fps-20261118`
- Source commit: `025c4b9b7b77bf54cd1c2dcd6d046e3e8ce46352`
- Added a build-ID-guarded `k_locks` row for RE0: global pointer `main+0x1BAAC60`, instance field `+0x4C`, one float copy.
- Removed the earlier RE0 opt-in that wrote both `+0x48` and `+0x4C`; that pair is no longer written by this branch. The read-only probe remains.
- The existing profile default remains 30 FPS. Selecting `DM_FPS_TARGET=60` asks the generic FPS-lock path to write 60.0 to +0x4C while leaving +0x48 untouched at 30.0.
- The RE0 display-mode opt-in remains required for host presentation at 60 Hz: `DM_RE0_PRESENT_60=1`. Keep `DM_PRESENT_INTERVAL` unset.

### Test configuration

- `DM_FPS_TARGET=60`
- `DM_RE0_PRESENT_60=1`
- `DM_RE0_TIMING_60` unset (legacy option removed)
- `DM_RE0_TRACE_PRESENT=1`
- `DM_PRESENT_INTERVAL` unset

### Acceptance criteria

1. Runtime log reports the RE0 frame-limit row changing +0x4C from 30 to 60.
2. Read-only timing probe reports +0x48 = 30 and +0x4C = 60 after the write.
3. NVN acquire and present intervals approach 16.67 ms (about 60 Hz).
4. In-game timer, movement distance per real second, and animation speed match the 30 FPS baseline. If any of these double, stop the test and report it; do not add a write to +0x48.
5. Test a prerendered cutscene separately. The Warehouse patch holds these at 30 Hz; this first port has not yet added that cutscene-specific override.
6. Re-test the default profile with no `DM_FPS_TARGET` override: it must remain 30 FPS.

The source patch is committed but has not been built or run by the assistant. A successful local build and the runtime checks above are still required before treating this as validated.


## 13. Default adaptive 120 FPS and movie-clock pacing (2026-11-18)

### User-verified starting point

The user reports the single-field limiter branch now runs RE0 at 60 FPS with correct gameplay speed. This is the first positive runtime result for the exact game/build; it is user-reported, not independently reproduced in this environment.

### Reference patches and implementation choice

- Exact RE0 1.0.0 FPSLocker reference: https://github.com/masagrator/FPSLocker-Warehouse/blob/b765680937f1177ec2719a6d31490b2d6e4edcb3/SaltySD/plugins/FPSLocker/patches/010097000BC10000/FB4239AA962B429B.yaml
- That patch detects prerendered cutscenes (main offsets 0x9F2548 / 0x9F26EC) and selects a 30 Hz refresh rate while its cutscene flag is set.
- nxnative already has a less offset-specific movie clock: `dm_movie_picture()` measures decoded picture PTS and `dm_movie_hz()` exposes the active decoder's actual picture rate. `hle_codec_video.c` reports nn::codec picture timestamps to this clock.
- Resident Evil HD Remaster's NVN path uses `present_itv()` to convert the selected render rate into a per-picture interval while a movie is active. This RE0 change extends that same 60 Hz movie rule to RE0; the existing high/120 path already uses the same PTS ratio.
- This avoids copying RE0's cutscene hook addresses into runtime code. It relies on the decoder reporting PTS and the game respecting the NVN window interval, both of which still need an in-game cutscene test.

### Proposed source changes

- Branch: `experiment/re0-default-120-movie-clock-20261118`
- Base: single-field RE0 limiter branch `experiment/re0-single-field-60fps-20261118`.
- `dm/games/010097000BC10000/game.tsv`: set `present_interval display`, `fps_target 120`, `fps_max 120`. The generic adaptive high-FPS path targets 120 on a 120 Hz display and falls back to 60 when the display/thermal hold requires it. On a 60 Hz display it cannot present 120.
- `dm/gfx/nvn/hle_nvn.c`: remove the RE0-specific `DM_RE0_PRESENT_60` opt-in branch; the profile now enables display pacing. Extend the RE HD Remaster 60 Hz movie PTS interval rule to RE0.
- `dm/host/hle_movie.c`: include RE0 in the existing bounded decoded-picture PTS diagnostic written to `/tmp/re_movie_clock_probe.log`.
- The only RE0 guest timing write remains the build-ID-guarded float at `sMain::mpInstance + 0x4C`. `+0x48) remains untouched. The read-only NVN trace still requires `DM_RE0_TRACE_PRESENT=1) only when collecting diagnostics; it is not needed for normal operation.

### Normal launch

No RE0-specific environment variables are required. Keep `DM_PRESENT_INTERVAL`, `DM_RE0_PRESENT_60`, and `DM_RE0_TIMING_60` unset. The optional `DM_FPS_TARGET=30|60|120` remains a generic override, not a requirement. `DM_RE0_TRACE_PRESENT=1) is optional diagnostics only.

### Validation still required on the user's Mac

1. Compile the branch with the existing macOS NSP build command.
2. On a 120 Hz display, confirm runtime logs show the RE0 engine limiter at 120 and NVN acquire/present near 8.33 ms; on a 60 Hz display expect 16.67 ms and 60 FPS.
3. Confirm movement, animations and timers remain at normal real-time speed at both 60 and 120. Specifically verify `+0x48=30` and `+0x4C=120` while 120 is active, or +0x4C=60 under a 60 Hz hold.
4. Play a prerendered cutscene at both selected targets. Check that the decoder PTS rate (typically 30 pictures/s) matches the movie playback duration and audio/subtitle synchronization; inspect `/tmp/re_movie_clock_probe.log` and `~/Library/Logs/nxnative/010097000BC10000.log`.
5. Test a 60 Hz display separately. Adaptive 120 mode must fall back cleanly to 60 rather than claim 120.
6. Confirm explicit 30 and 60 overrides still work.

The GitHub source changes are proposed only. No macOS build, game launch, 120 Hz display run, or cutscene playback has been executed by the assistant; no build or runtime success is claimed here.

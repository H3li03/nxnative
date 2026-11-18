# Resident Evil 0 60 FPS investigation — 2026-11-18

## Evidence from the autonomous diagnostics

- Game build ID: `fb4239aa962b429b3d1776af92d93e79` (1.0.0).
- Profile advertises `fps_target=60`, but explicitly describes the native simulation clock as 30 Hz.
- Rewrite log reports `cuts 1`; the sole registered game cut is `main+0x7aa934`, replacing one dynamic `nn::os::SleepThread` call with NOP. The user reports that this experiment still runs at 30 FPS.
- Runtime timing around frame 600: frame-time p50 33.33 ms, frame-work p50 33.33 ms, NVN submit+present p50 0.12 ms, GPU p50 3.72 ms. The GPU/present path is not the 33.33 ms bottleneck.
- Main thread reports about 999 ms/s CPU time at the sampled interval (approximately one fully occupied core).

## Code-path finding

In `dm/gfx/nvn/hle_nvn.c`, `fps_present_cap()` uses the profile's `fps_target`, but in game interval mode it deliberately refuses to apply that cap when there is neither a frame-step state page nor a recognized engine frame limiter (`dm_fps_lock_engine()`). In that case it sets the present cap to zero and preserves the game's own present interval. The RE0 title ID is special-cased for the 120-fps high-mode check, not for an ordinary 60-fps engine limiter.

In `dm/host/hle_fpslock.c`, `dm_fps_lock_engine()` returns true only when a recognized limiter row, a detected generic target field, or the explicitly unsafe RE0 experiment is active. The RE0 unsafe path is disabled by default. Therefore a profile value of 60 by itself does not make this title's simulation run at 60.

## Next investigation — no timing-field writes

1. Confirm the runtime log's actual NVN present interval and whether it logs that the 60-fps cap was not applied.
2. Inspect the RE0 main-loop disassembly around `0x7aa7ac–0x7aa990`, including both SleepThread call sites and the reads/writes of the timing object.
3. Verify the existing read-only RE0 pointer probe (`main+0x1285650 -> object1 -> object2+0x48`) against runtime evidence. Do not assume that the value is an FPS selector.
4. Identify a field that changes the update cadence without changing simulation time scale. Only then add a build-ID-scoped guarded limiter row and test it.
5. Do not re-enable writes to `+0x48/+0x4c` based on the current evidence; earlier tests changed simulation speed.

## Decision

Do not add another NOP or force display-only 60-Hz presentation yet. The present cap is not the missing engine-side simulation limiter, and duplicating 30-Hz simulation frames would not establish genuine 60-FPS gameplay.

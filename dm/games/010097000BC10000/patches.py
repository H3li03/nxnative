# Resident Evil 0 1.0.0 (main build fb4239aa962b429b3d1776af92d93e79).
#
# Experimental 60 fps probe: bypass main fixed sleep and render-end frame gate.
#
# sMain::move fixed SleepThread:
#   main+0x7aa840: BL nn::os::SleepThread -> NOP.
#
# sRender::end frame pacing:
#   main+0x7ce6f0: B.PL 0x7ce728 -> B 0x7ce728.
# This skips the elapsed-frame threshold wait, but preserves the subsequent
# callback polling path (including its 1 ms SleepThread) used for render work.
#
# No writes to the +0x48 time-scale multiplier, +0x4c timing field, or
# simulation-clock accumulation are made by this patch.
# The render-end gate may still affect presentation/synchronization; test
# frame rate, gameplay speed, animation, audio, and stability.
#
# Build-ID-scoped diagnostic experiment, not a general RE0 update rule.
CUTS = {
    "fb4239aa962b429b3d1776af92d93e79": [
        (0x7aa840, "7e660994", "1f2003d5",
         "RE0 probe: bypass fixed main-loop SleepThread; preserve simulation timing fields"),
        (0x7ce6f0, "c5010054", "0e000014",
         "RE0 probe: skip sRender::end elapsed-frame threshold wait; preserve render callback polling"),
    ],
}

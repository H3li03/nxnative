# Resident Evil 0 1.0.0 (main build fb4239aa962b429b3d1776af92d93e79).
#
# Experimental callback-polling probe.
#
# Existing probes:
#   main+0x7aa840: bypass sMain::move fixed SleepThread.
#   main+0x7ce6f0: bypass sRender::end elapsed-frame threshold gate.
#
# New probe:
#   main+0x7ce74c: NOP the CBNZ retry after the first render callback poll.
# This lets sRender::end continue after one callback poll rather than sleeping
# and polling repeatedly. It may race unfinished render/GPU work; test only
# as a diagnostic. Revert immediately if there are artifacts, hangs, or crashes.
#
# No writes to +0x48, +0x4c, or simulation-clock accumulation are made.
# Build-ID-scoped diagnostic experiment; not a general RE0 update rule.
CUTS = {
    "fb4239aa962b429b3d1776af92d93e79": [
        (0x7aa840, "7e660994", "1f2003d5",
         "RE0 probe: bypass fixed main-loop SleepThread; preserve simulation timing fields"),
        (0x7ce6f0, "c5010054", "0e000014",
         "RE0 probe: skip sRender::end elapsed-frame threshold wait"),
        (0x7ce74c, "40ffff35", "1f2003d5",
         "RE0 diagnostic: stop repeated render callback polling after first poll; may race GPU work"),
    ],
}

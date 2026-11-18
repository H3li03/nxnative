# Resident Evil 0 1.0.0 (main build fb4239aa962b429b3d1776af92d93e79).
#
# Experimental 60 fps probe (main fixed-wait path).
# sMain::move tests object+0x50 at main+0x7aa824:
#   set:   fixed SleepThread at main+0x7aa840
#   clear: dynamic pacing path at main+0x7aa934
#
# This branch bypasses ONLY the fixed SleepThread call. It does not modify
# the +0x48 time-scale multiplier, +0x4c timing field, elapsed-tick math,
# or either branch's simulation-clock updates.
#
# main+0x7aa840: BL nn::os::SleepThread(nn::TimeSpan) -> NOP.
# The dynamic wait at main+0x7aa934 remains untouched in this experiment.
#
# Build-ID-scoped diagnostic experiment, not a general RE0 update rule.
CUTS = {
    "fb4239aa962b429b3d1776af92d93e79": [
        (0x7aa840, "7e660994", "1f2003d5",
         "RE0 safer probe: bypass fixed main-loop SleepThread at +0x7aa840 only; preserve simulation timing fields and dynamic wait path"),
    ],
}

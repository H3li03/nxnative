# Resident Evil 0 1.0.0 (main build fb4239aa962b429b3d1776af92d93e79).
#
# Experimental 60 fps probe: bypass only the dynamically computed SleepThread
# call in the main update loop. The native elapsed-tick calculation and the
# +0x48/+0x4c simulation clock fields are deliberately left untouched.
#
# main+0x7aa934: BL nn::os::SleepThread(nn::TimeSpan) -> NOP.
# The other SleepThread call at main+0x7aa840 is intentionally preserved.
#
# This is a build-ID-scoped test, not a general RE0 update rule. If the loop
# becomes unstable or simulation speed changes, remove this cut and rebuild.
CUTS = {
    "fb4239aa962b429b3d1776af92d93e79": [
        (0x7aa934, "41660994", "1f2003d5",
         "RE0 experiment: bypass only main-loop dynamic SleepThread at +0x7aa934; preserve tick-based delta and simulation clock"),
    ],
}

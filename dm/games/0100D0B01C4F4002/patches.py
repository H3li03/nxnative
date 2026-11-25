# Metal Gear Solid 4: Guns of the Patriots
# Program ID: 0100D0B01C4F4002
# Verified on update v393216.
#
# The game's display initialization clamps both swap chain
# dimensions to 1920 pixels. This produces an incorrect
# aspect ratio when requesting 1440p or 4K.
#
# Raise the ceiling to 3840, leaving the actual resolution
# controlled by the game's configuration.
#
# Runtime verified: 2560x1440 and 3840x2160 swap chains,
# correct 16:9 aspect ratio, approximately 60 fps at 4K
# with the engine's 60 fps configuration.

CUTS = {
    '3e7443aca182388f98e13069311fb51f': [
        (
            0x911314,
            '3f001e71',
            '3f003c71',
            'MGS4 native resolution: width ceiling 1920 -> 3840',
        ),
        (
            0x911318,
            '08f08052',
            '08e08152',
            'MGS4 native resolution: clamp value 1920 -> 3840',
        ),
        (
            0x911324,
            '5f001e71',
            '5f003c71',
            'MGS4 native resolution: height ceiling 1920 -> 3840',
        ),
    ],
}

BINDING = [
    {
        'what': 'MGS4 native swap chain resolution ceiling',
        'now': 'build',
        'goal': 'build',
        'purpose': 'rendering',
        'checked': 'v393216: 1440p and 4K native swap chains',
        'why': 'Exact build ID and original instruction checks',
        'kept': 'Other executable builds have not been verified',
    },
]

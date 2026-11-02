"""Pixel designs of the four roguelike characters drawn from scratch.

Used by tools/build_character_variants.py. Every pattern is one character
per art cell (one cell = 7 source pixels = about one screen pixel at the
in-game scale of 0.15), "." is empty. Each part gets a one-cell outline when
drawn, so the patterns hold fills only (plus "o" for inner dark lines).

Coordinates are art cells of the 250x250 frame (36x36 cells, column 0 on
the left, row 0 at the top). The floor is FLOOR_ROW: the last row of boot
fill, the outline under it lands on the wizard's feet line.

Views: "side" faces right (the game flips it), "front" faces the player
(digging with the shovel), "back" faces away (climbing the vertical
ladder).
"""

FLOOR_ROW = 32

OUTLINE = (25, 14, 32, 255)


def rgb(hex_colour):
    hex_colour = hex_colour.lstrip("#")
    return tuple(int(hex_colour[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


COMMON = {
    "o": OUTLINE,
    "e": rgb("#1a0f14"),
    "s": rgb("#e0a27c"),
    "z": rgb("#b4735a"),
    "w": rgb("#ffffff"),
    "M": rgb("#9698a8"),
    "m": rgb("#cdcfda"),
    "N": rgb("#5e606e"),
}


def mirror(half):
    """A symmetric pattern from its left half; the last column of each row
    is the centre column."""
    return [row + row[-2::-1] for row in half]


class Design:
    """Everything needed to pose one character.

    For each view: the pattern of the upper body (head and torso, no legs,
    no arms), the cell of its top-left corner in the standing pose, the
    hips (leg tops) and the shoulders, all in frame cells.
    """

    def __init__(self, **values):
        self.__dict__.update(values)

    def colour(self, letter):
        return self.legend.get(letter) or COMMON[letter]



# ---------------------------------------------------------------------------
# Miner: stocky and broad, short legs, orange hard hat with a headlamp, big
# dark beard over the chest, rust shirt with suspenders, heavy boots.
# ---------------------------------------------------------------------------

MINER = Design(
    id="miner",
    legend={
        "H": rgb("#f0a030"), "h": rgb("#b8661e"), "j": rgb("#ffd27a"),
        "L": rgb("#fff6c0"), "l": rgb("#9698a8"),
        "B": rgb("#6e3e26"), "b": rgb("#4c2a1a"),
        "R": rgb("#c4582a"), "r": rgb("#8e3c1e"), "Q": rgb("#e07a3e"),
        "U": rgb("#4a2a1a"),
        "D": rgb("#3c2618"), "Y": rgb("#e8be3c"),
        "P": rgb("#7a5a40"), "p": rgb("#56402c"),
        "K": rgb("#4a3022"), "k": rgb("#2e1e16"),
    },
    side=[
        ".........jjjjHH......",
        ".......jjHHHHHHHH....",
        "......jHHHHHHHHHHHl..",
        "......HHHHHHHHHHHHLL.",
        "......HHHHHHHHHHHHLL.",
        "......hHHHHHHHHHHHl..",
        "...hhhhhhhhhhhhhhhhhh",
        "......bbbsssssssss...",
        "......bbbssssssesss..",
        "......bbbsssssssssss.",
        "......bbbbBBBBBBBzs..",
        "......bbBBBBBBBBBBB..",
        "...rrRRbBBBBBBBBBBB..",
        "..rRRRRRbBBBBBBBBB...",
        ".rRRRRRRRbBBBBBBBRR..",
        ".rRRRRRRRUbBBBBBRRRR.",
        ".rRRRRRRRURbBBBRRRRR.",
        ".rRRRRRRRURRbBRRRRRR.",
        ".rRRRRRRRURRRRRRRRRR.",
        ".DDDDDDDDDDDDDDDDYYD.",
        ".pPPPPPPPPPPPPPPPPPP.",
    ],
    side_origin=(8, 8),
    side_hips=((11, 29), (19, 29)),
    side_shoulder=(15, 21),
    side_front_shoulder=(23, 21),
    side_back_shoulder=(11, 21),
    front=mirror([
        ".........jj",
        ".......jjHH",
        "......jHHHH",
        "......HHHlL",
        "......HHHlL",
        "......hHHHH",
        "...hhhhhhhh",
        "......bssss",
        "......bsess",
        "......bssss",
        "......bbBBs",
        "......bBBBB",
        "...rRRbbBBB",
        "..rRRRRRbBB",
        ".rRRRRRRRbB",
        ".rRRRRRRUbB",
        ".rRRRRRRURb",
        ".rRRRRRRURR",
        ".rRRRRRRURR",
        ".DDDDDDDDDY",
        ".pPPPPPPPPP",
    ]),
    front_origin=(9, 8),
    front_hips=((12, 29), (23, 29)),
    front_shoulders=((12, 21), (26, 21)),
    back=mirror([
        ".........jj",
        ".......jjHH",
        "......jHHHH",
        "......HHHHH",
        "......HHHHH",
        "......hHHHH",
        "...hhhhhhhh",
        "......bbbbb",
        "......bbBBB",
        "......bbBBB",
        "......bbbBB",
        "......rrrrr",
        "...rRRRRRRR",
        "..rRRRURRRR",
        ".rRRRRRURRR",
        ".rRRRRRRURR",
        ".rRRRRRRRUR",
        ".rRRRRRRRRU",
        ".rRRRRRRRRU",
        ".DDDDDDDDDD",
        ".pPPPPPPPPP",
    ]),
    back_origin=(9, 8),
    back_hips=((12, 29), (23, 29)),
    back_shoulders=((12, 21), (27, 21)),
    leg_width=3,
    leg="P",
    boot_side=["KKK..", "KKKKK"],
    boot_front=["KKK", "KKK"],
    sleeve="Q",
    hand="s",
)


# ---------------------------------------------------------------------------
# Engineer: medium build, blue cap with a long bill and welding goggles
# pushed up on it, yellow shirt, blue overalls with a tool belt, a big
# wrench slung across the back (its jaw shows over the shoulder).
# ---------------------------------------------------------------------------

# A bundle of three boards strapped across the back: what the engineer
# builds the longer bridges and ladders with.
ENGINEER_PLANKS = [
    ".X.",
    "ZXx",
    "ZXx",
    "ZXx",
    "ttt",
    "ZXx",
    "ZXx",
    "ZXx",
    "ZXx",
    "ZXx",
    "ttt",
    "ZXx",
    "ZXx",
    "ZXx",
]

ENGINEER = Design(
    id="engineer",
    legend={
        "C": rgb("#3a62d8"), "c": rgb("#24409a"), "q": rgb("#7fa0ff"),
        "G": rgb("#e0aa3c"), "g": rgb("#2e5a5a"),
        "n": rgb("#5a3824"),
        "Y": rgb("#f2c230"), "y": rgb("#c08a1c"), "Q": rgb("#ffe070"),
        "U": rgb("#2f56b8"), "u": rgb("#1f3a80"),
        "T": rgb("#7a4a26"), "t": rgb("#4e2e18"),
        "K": rgb("#4a3a34"), "k": rgb("#2e2420"),
        "X": rgb("#e0aa66"), "x": rgb("#b47a40"), "Z": rgb("#8a5630"),
    },
    side=[
        "............qqqq......",
        "..........qqCCCCCq....",
        "........qCCCCCCCCCC...",
        ".......cCCCCCCCCCCC...",
        ".......cCCCCCCCCGGG...",
        ".......cCCCCCCCCGgG...",
        ".......ccccccccccGGGcc",
        "......nnnnssssssssss..",
        "......nnnsssssssesss..",
        "......nnnssssssssssss.",
        ".......nnssssssssss...",
        "........nzzssssss.....",
        ".........yYYYYYYYU....",
        ".......yYYYYYYUUUUU...",
        "......yYYYYYYYUUUUU...",
        "......yYYYYYYYUUmUU...",
        "......yYYYYYYYUUUUU...",
        "......TTTTTTTTTTTMT...",
        "......uUUUUUUUUUUMU...",
        "......uUUUUUUUUUUUU...",
        "......uUUUUUUUUUUUU...",
    ],
    side_origin=(7, 6),
    side_behind=[(ENGINEER_PLANKS, (10, 3))],
    side_hips=((14, 27), (19, 27)),
    side_shoulder=(16, 19),
    side_front_shoulder=(22, 19),
    side_back_shoulder=(14, 19),
    front=mirror([
        "..........qq",
        "........qCCC",
        ".......cCCCC",
        "......cCCCCC",
        "......cCGGGG",
        "......cGgggG",
        "....ccccGGGG",
        "......nsssss",
        "......nsesss",
        "......nsssss",
        ".......sssss",
        "........zsss",
        "........yYYY",
        "......yYYUUU",
        ".....yYYYUUU",
        ".....yYYYUmU",
        ".....yYYYUUU",
        ".....TTTTTTT",
        ".....uUUUUUU",
        ".....uUUUUUU",
        ".....uUUUUUU",
    ]),
    front_origin=(7, 6),
    front_behind=[(ENGINEER_PLANKS[:8], (10, 3))],
    front_hips=((14, 27), (21, 27)),
    front_shoulders=((13, 19), (25, 19)),
    back=mirror([
        "..........qq",
        "........qCCC",
        ".......cCCCC",
        "......cCCCCC",
        "......cCCCCC",
        "......gggggg",
        "......cCCCCC",
        "......nnnnnn",
        "......nnnnnn",
        "......nnnnnn",
        ".......nnnnn",
        "........ssss",
        "........yYYY",
        "......yYUYYY",
        ".....yYYYUYY",
        ".....yYYYYUY",
        ".....yYYYYYU",
        ".....TTTTTTT",
        ".....uUUUUUU",
        ".....uUUUUUU",
        ".....uUUUUUU",
    ]),
    back_origin=(7, 6),
    back_front=[(ENGINEER_PLANKS, (12, 3))],
    back_hips=((14, 27), (21, 27)),
    back_shoulders=((13, 19), (26, 19)),
    leg_width=2,
    leg="U",
    boot_side=["KKK.", "KKKK"],
    boot_front=["KKK", "KKK"],
    sleeve="Q",
    hand="s",
)


# ---------------------------------------------------------------------------
# Scout: lean and tall, green hood with the face showing, red scarf whose
# tails stream behind, short dark cape, long legs in tall boots.
# ---------------------------------------------------------------------------

SCOUT_SCARF = [
    (["FFFF..", "FF.FFF", "...FF."], (9, 13)),
    (["FFFFF.", ".FF.FF", "......"], (9, 13)),
    (["FFFF..", "FFFFF.", "....FF"], (9, 13)),
    (["FFFFF.", "FF.FFF", "......"], (9, 13)),
]

SCOUT = Design(
    id="scout",
    legend={
        "G": rgb("#3f9a46"), "g": rgb("#24642e"), "v": rgb("#79c24e"),
        "F": rgb("#c4322a"), "f": rgb("#7c1c1c"),
        "C": rgb("#2a5a30"), "c": rgb("#1a3e22"),
        "T": rgb("#79b04a"), "t": rgb("#4e7e30"), "Q": rgb("#9ccc64"),
        "L": rgb("#7a4a26"), "l": rgb("#a8714a"), "Y": rgb("#e8be3c"),
        "P": rgb("#5a5a3a"), "p": rgb("#3e3e28"),
        "K": rgb("#6e3f26"), "k": rgb("#4a2a1a"),
    },
    side=[
        ".......vGGG.......",
        ".....vGGGGGGG.....",
        "....gGGGGGGGGG....",
        "...gGGGGGGGGGGG...",
        ".ggGGGGGGGsssGG...",
        "gg.gGGGGGsssssG...",
        "g..gGGGGGssssess..",
        "...gGGGGGsssssss..",
        "....gGGGGGsssGG...",
        ".....FFFFFFFFF....",
        "....FFFFFFFFFFF...",
        "...CCTTTTTTTTT....",
        "..CCCTTTTTTTTTT...",
        "..CCCTTTTTTTTTT...",
        "..CCCTTTTTTTTTT...",
        "..CCCLLLLLLYLLL...",
        "...CCTTTTTTTTTT...",
        "....tTTTTTTTTTT...",
        "....tTTTTTTTTT....",
    ],
    side_origin=(9, 4),
    side_behind=SCOUT_SCARF,
    walk_lean=-5,
    side_hips=((15, 23), (20, 23)),
    side_shoulder=(17, 16),
    side_front_shoulder=(22, 16),
    side_back_shoulder=(14, 16),
    front=mirror([
        "........vG",
        "......vGGG",
        ".....gGGGG",
        "....gGGGGG",
        "....gGGsss",
        "....gGssss",
        "....gGsses",
        "....gGssss",
        ".....gGsss",
        "......FFFF",
        ".....FFFFF",
        "...CCTTTTT",
        "..CCCTTTTT",
        "..CCTTTTTT",
        "..CCTTTTTT",
        "..CCLLLLLL",
        "...CTTTTTT",
        "....tTTTTT",
        "....tTTTTT",
    ]),
    front_origin=(9, 4),
    front_hips=((15, 23), (21, 23)),
    front_shoulders=((13, 16), (24, 16)),
    back=mirror([
        "........vG",
        "......vGGG",
        ".....gGGGG",
        "....gGGGGG",
        "....gGGGGG",
        "....gGGGGG",
        "....gGGGGG",
        "....gGGGGG",
        ".....gGGGG",
        "......FFFF",
        ".....FFFFF",
        "...CCCCCCC",
        "..CCCCCCCC",
        "..CCCCCCCC",
        "..CCCCCCCC",
        "..CCLLLLLL",
        "...TTTTTTT",
        "....tTTTTT",
        "....tTTTTT",
    ]),
    back_origin=(9, 4),
    back_hips=((15, 23), (21, 23)),
    back_shoulders=((13, 16), (25, 16)),
    leg_width=2,
    leg="P",
    boot_side=["lll.", "KKK.", "KKK.", "KKKK", "kkkk"],
    boot_front=["lll", "KKK", "KKK", "KKK", "kkk"],
    sleeve="Q",
    hand="s",
)


# ---------------------------------------------------------------------------
# Tinkerer: small, big head of wild white hair, huge round goggles with
# cyan lenses, teal coat, brass-trimmed backpack with a gear and an antenna
# with a red bulb sticking up behind.
# ---------------------------------------------------------------------------

TINKERER_ANTENNA = [".R.", "RwR", ".R.", ".M.", ".M.", ".M.", ".M.", ".M."]

TINKERER = Design(
    id="tinkerer",
    legend={
        "W": rgb("#eeeef2"), "V": rgb("#a8a8bc"),
        "B": rgb("#e0aa3c"), "b": rgb("#8e6420"), "j": rgb("#fff0b0"),
        "g": rgb("#7fe8ff"),
        "A": rgb("#2fb0c8"), "a": rgb("#1c7890"), "x": rgb("#8ae4f0"), "Q": rgb("#66d4e6"),
        "K": rgb("#6e3f26"), "k": rgb("#4a2a1a"),
        "R": rgb("#e83a30"),
        "D": rgb("#4a2a1a"),
        "P": rgb("#3c3a58"), "p": rgb("#28263e"),
        "E": rgb("#3a3440"), "f": rgb("#22202a"),
    },
    side=[
        "..R..............",
        ".RwR.............",
        "..R..............",
        "..M.......W.W....",
        "..M....WWWWWWW...",
        "..M...WWWWWWWWW..",
        "..M..VWWWWWWWWWW.",
        "..M..VWWWWssBBB..",
        ".bjb.VWWsssBgggB.",
        "bjjjbVWssssBgwgB.",
        ".bjb.VWssssBgggB.",
        "KKKKK.Vzsss.BBBss",
        "KKKKKK.zsssssssss",
        "KbBbKK..zssssss..",
        "KBgBKAAAAAAAAA...",
        "KbBbKAAAAAAAAAA..",
        "KKKKKaAAAAAAAAA..",
        "KKKKKaAAAAAAAAA..",
        ".KKKKaAAAAAAAAA..",
        ".....aDDDDDDDBD..",
        ".....aAAAAAAAAA..",
    ],
    side_origin=(8, 8),
    side_hips=((15, 29), (19, 29)),
    side_shoulder=(17, 23),
    side_front_shoulder=(21, 23),
    side_back_shoulder=(14, 23),
    front=mirror([
        "........",
        "........",
        "........",
        "......W.",
        "....WWWW",
        "...WWWWW",
        "..VWWWWW",
        "..VWBBBs",
        "..VBgggB",
        "..VBgwgB",
        "..VBgggB",
        "..VzBBBs",
        "...zssss",
        "....zsss",
        "...AAAAA",
        "..AAAAAx",
        "..aAAAAx",
        "..aAAAAx",
        "..aAAAAx",
        "..aDDDDB",
        "..aAAAAx",
    ]),
    front_origin=(12, 8),
    front_behind=[(TINKERER_ANTENNA, (13, 8))],
    front_hips=((15, 29), (20, 29)),
    front_shoulders=((14, 23), (24, 23)),
    back=mirror([
        "........",
        "........",
        "........",
        "......W.",
        "....WWWW",
        "...WWWWW",
        "..VWWWWW",
        "..VWWWWW",
        "..VWWWWW",
        "..VWWWWW",
        "..VWWWWW",
        "..KKKKKK",
        "..KbBBBB",
        "..KBbjbB",
        "..KBjjjB",
        "..KBbjbB",
        "..KBBBBB",
        "..KKKKKK",
        "..aKKKKK",
        "..aDDDDD",
        "..aAAAAA",
    ]),
    back_origin=(12, 8),
    back_behind=[(TINKERER_ANTENNA, (13, 8))],
    back_hips=((15, 29), (20, 29)),
    back_shoulders=((14, 23), (25, 23)),
    leg_width=2,
    leg="P",
    boot_side=["EEE.", "ffff"],
    boot_front=["EE", "ff"],
    sleeve="Q",
    hand="s",
)


DESIGNS = [MINER, ENGINEER, SCOUT, TINKERER]

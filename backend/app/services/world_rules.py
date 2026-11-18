"""FindEZ World season rules, transcribed from the supplied prototype.

World references existing inventory IDs. These rules never create inventory.
"""
from bisect import bisect_right

LEVELS = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200]
XP = {'scan': 10, 'add': 25, 'spot': 10, 'game': 30, 'build': 5, 'tour': 20}
CAPS = {'scan': 200, 'add': 600, 'spot': 600, 'game': 300, 'build': 50}
LOCKS = {'plant': 2, 'lamp': 2, 'rug': 2, 'tallplant': 2, 'robot': 3,
         'printer': 3, 'toolbox': 3, 'spool': 3, 'arm': 4, 'fridge': 4,
         'bear': 2, 'hrug': 2, 'cat': 3, 'cloud': 4, 'counter': 4,
         'pegboard': 4, 'bike': 5, 'tires': 5, 'ladder': 5, 'sawhorse': 5}
PIECES = 'workbench desk table counter shelf drawers sawhorse pegboard fridge ladder bin emptybin box toolbox spices cans robot servo battery laptop spool gears drill clamps hexkeys tape nails lumber plant lamp monitor keyboard cables headphones earbuds books pens mugs fruit toaster bike tires coil beanbag rrug hrug bear cat duck mlamp vase cactus cloud pshelf printer arm rug tallplant'.split()
STYLES = ['Lab grey', 'Garage', 'Vanilla', 'Rosewood', 'Sage', 'Strawberry milk',
          'Matcha latte', 'Lavender', 'Peach fizz', 'Cotton sky', 'Lemonade',
          'Mint choc', 'Bubblegum', 'Night owl', 'Cabin', 'Cherry blossom']
STYLE_LEVELS = [1, 1, 1, 1, 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6]
QUESTS = [
    {'id': 'scan5', 'title': 'Scan 5 different things', 'event': 'scan', 'goal': 5, 'xp': 50},
    {'id': 'add1', 'title': 'Add your first item', 'event': 'add', 'goal': 1, 'xp': 50},
    {'id': 'spots', 'title': 'Give 3 new items a spot', 'event': 'spot', 'goal': 3, 'xp': 60},
    {'id': 'find1', 'title': 'Finish any game', 'event': 'play', 'goal': 1, 'xp': 50},
    {'id': 'fast', 'title': 'Find all five in under 20 seconds', 'event': 'fast', 'goal': 1, 'xp': 80},
    {'id': 'count', 'title': 'Get 4 right in Count it', 'event': 'count4', 'goal': 1, 'xp': 60},
    {'id': 'where', 'title': 'Get 4 right in Where is it?', 'event': 'where4', 'goal': 1, 'xp': 60},
    {'id': 'add5', 'title': 'Add 5 items', 'event': 'add', 'goal': 5, 'xp': 100},
    {'id': 'build3', 'title': 'Place 3 pieces in Build', 'event': 'build', 'goal': 3, 'xp': 50},
    {'id': 'scan15', 'title': 'Scan 15 different things', 'event': 'scan', 'goal': 15, 'xp': 100},
]


def level(xp):
    return bisect_right(LEVELS, max(0, xp))


def unlocks(best_level):
    return {'pieces': [p for p in PIECES if LOCKS.get(p, 1) <= best_level],
            'styles': [i for i, lv in enumerate(STYLE_LEVELS) if lv <= best_level]}


def transaction_rules():
    return {'xp': XP, 'caps': CAPS, 'levels': LEVELS, 'quests': QUESTS,
            'locks': {p: LOCKS.get(p, 1) for p in PIECES}, 'styles': STYLE_LEVELS}

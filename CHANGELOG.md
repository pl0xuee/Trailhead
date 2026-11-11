# Changelog

## 0.12.0

- Find it lists places closest first, wherever they are on your continent, and each row says how far away it is in yards. Places on another continent come last.
- Every page was reviewed for layout in all three looks, with a tool that draws each page outside the game and measures it (`tools/layout_review.py`). Fixed:
  - Guide: the sections of a topic now sit under each other however long the text is. Before, a long explanation ran into the next heading and "Coming up" ran under its button. Long lines wrap to a second line instead of being cut, and the list shows as many rows as fit.
  - Guide: the count on a group button sits on its corner instead of on top of the label. "Your character" is now "Character".
  - Screen setup: on a game that offers nothing to set, the message no longer lies over the list and the two unusable buttons are hidden. Rows have a little more room for two lines.
  - A button that changes from the filled style to the outlined one (a setting turned off, "Stop following", "Undo") no longer keeps its glow.
  - Find it: the list uses the whole page (six rows instead of five).
  - "How to get there": the place line sits above the title, where a long title cannot reach it.
  - Welcome: all buttons end on the same right edge.
  - Quest hub list: the inn and flight marks and "Start here" close up to the buttons.
  - Home: a long milestone title no longer runs past its card.
  - The Back button no longer sits two units above the page.

## 0.11.0

- Find it works from the first minute: about 1,800 places ship inside the addon (class trainers, vendors, repair, inns, flight masters, mailboxes, banks, profession trainers, auction houses, stable masters), shown for your side, your class and the zone you are in. Places you find yourself are added on top and replace the built-in entry at that spot.
- Quest hubs: every zone says where your side starts and lists its quest hubs with levels, an inn or flight master where there is one, a map marker and "How to get there". Hubs can be searched by name.
- Dungeon routes: a step-by-step route for every dungeon and raid with each boss, where it stands and a tip. Inside a dungeon the page follows along and ticks bosses off as they die. Doors are shipped for the old dungeons; new dungeons say where the door is in words.
- Builds for all nine classes (15 builds), each with who it suits, a gear line, the order to take talents and how to fight. The helper beside the talent window is narrower.
- Guide: four groups (Your character, The world, With others, Gold and more) and 18 topics. "Coming up" lists the spells your trainer has before you have visited one.
- Screen setup: a page of recommended interface settings for a first character, each switched on with one click and undone with one click.
- Settings is split into three sections (Window, At vendors, Help and data) so the rows are no longer squeezed together.
- Checked before release against Forever guides, the game's own tables and Blizzard's interface source. Corrected: positions in Stormwind, Mulgore, Redridge and the Eastern Plaguelands (Forever's maps differ from the old ones); class and profession trainers now follow Forever's trainer guides; seasonal and instance-only vendors removed; noisy quest hubs removed and each side given its own town in shared zones; the Deadmines, Stratholme, Dire Maul and raid routes; racial priest spells no longer listed for every priest; the shaman build takes Stormstrike at 25; the Guide no longer describes an automatic dungeon queue (Forever has none); a dungeon run is no longer resumed after logging out inside.
- First-run welcome: shown once when the window is first opened, with four doors into the right pages and the look picker. Skippable, and reopened from Settings.
- Vendors: the game already has Sell All Junk and Repair buttons, so Trailhead only adds what it lacks. "Sell grey items by itself" and "Repair by itself" in Settings do it when a vendor window opens (both off by default), with one chat line saying what was sold or repaired. "Extra vendor buttons" (off by default) adds a second pair that shows the amounts first.
- Legacy page (new tab): your Legacy Points, how points are earned, what the three perk trees and the rewards are, and buttons into the game's own Legacy window and challenges.
- Settings: vendor buttons, the two automatic options, and the welcome.
- Translation scaffold: `tools/gen_locale_keys.py` lists every text key and writes a ready-to-fill locale file.
- Release packaging: `.pkgmeta`, README, this changelog, `tools/package.sh`.

## 0.10.0

- Find it: weapon masters and riding trainers and mount vendors, from launch guides.
- Guide: Mount and Dying topics.

## 0.9.0

- Guide: Gear topic (armour you can wear, most worn piece, repair advice).

## 0.8.0

- Guide: Inns and rest, and Supplies topics.

## 0.7.1, 0.7.0

- The talent window helper says where the next talent sits.
- Guide: "Coming up", the next levels that bring something.

## 0.6.1, 0.6.0

- Builds page with the first ready-made build, a talent helper beside the talent window, and a fix so "Open talents" no longer closes Trailhead.

## 0.5.1, 0.5.0

- Guide topics: Talents, Weapon skills, Professions. Home card for a weapon far behind its limit. City flight masters on the map.

## 0.4.0

- "How to get there" steps for every place, zone, dungeon and raid. Raids list (empty until raids open).

## 0.3.0

- Trailhead sits beside the game's spellbook, talent and map windows when it opens them.

## 0.2.2, 0.2.1, 0.2.0

- Ember look, now the default. Class trainer reading fixed. "Set marker" puts the game's own marker and opens the map.

## 0.1.x

- First version: Home advice cards, Find it, Spells, Zones, three looks, minimap button, the game check.

# Trailhead: build plan

A new-player companion addon for **World of Warcraft: Forever** (live build 1.60.1.70888, addon interface `16001`).
Written 2026-11-11. Mockups of the main window in its three looks: `docs/mockups/night.png`, `journal.png`, `ember.png`.

**Status (2026-11-11): everything planned for Phases 1 to 3 is built except the Weekly page and the release itself** (`Trailhead/`, version 0.11.0; about 4,600 offline checks). Confirmed in the game up to 0.9.0: finding places, guard directions, Zones, the trainer's full list, the Spells page, Trailhead moving beside the map, the spellbook and the talent window, "How to get there", the Builds page with Follow and "Open talents", and the Guide's Weapon skills, Talents, Coming up, Inns and rest, Supplies and Gear topics. **Built but not yet seen in the game:** 0.10.0 (weapon masters, riding, Mount and Dying topics) and all of 0.11.0: built-in places, quest hubs, dungeon routes, builds for all nine classes, the regrouped Guide, the welcome, the Legacy page, the vendor options, the screen setup page. 0.11.0 was followed by a correctness review of all shipped data, text and code (see "What 0.11.0 built and what the review found" below). **How facts are gathered:** general game knowledge is looked up online by the developer (Blizzard's articles and Forever-specific guides) or read from the game's own tables; the player is asked for `/th check` only when the addon needs to learn how the game's own functions answer, and is never sent to visit NPCs. Where sources disagree, only what they agree on is shipped, with no figure. **The addon ships its data** (decided by the user): a new character never starts with an empty list, and what the player finds is added on top. Next: see the pages in the game, then release.

## 1. What it is

One window that answers three questions for someone new to the game:

1. **What should I do now?** (Home)
2. **Where is the thing I need?** (Find it)
3. **What is this and why does it matter?** (Guide)

It is not a quest-by-quest leveling guide (RestedXP and several others do that) and it stays out of combat entirely.

### Why there is room for it

Blizzard's own tutorial on Forever stops at level 10 and is mostly stubbed out (`Blizzard_NewPlayerExperience/Camelot/Blizzard_TutorialData.lua`: `TUTORIAL_LEVEL_LIMIT = 10`, most class data `UNUSED_ID`). It covers moving, looting, vendors, equipping and dying, and nothing after that.

The field is crowded one week after launch, but the existing addons are narrow:

| Addon | What it does | Gap |
|---|---|---|
| Waypoint Tracker (MIT, about 5.5K downloads) | TomTom-style arrow, `/wp find` NPC search, ships a location database | A power tool; no guidance, no "what now" |
| Where's My Trainer, Closest Vendor | One category each | Not unified |
| WoW Handbook, Adventure Guide Forever, Lodestar | Guides and progression rankers | Not location-aware |
| RestedXP, Wayfinder Forever | Quest routing | Different job |

The gap is a single, good-looking, proactive companion that ties guidance to location: "you have 3 spells to train, and the trainer is here".

## 2. What the research established

### Verified against Blizzard's Forever UI source (build 1.60.1.70888, same as the installed game)

- Game type is `camelot`, family `standard` (shares the Retail code family). TOC `## Interface: 16001`. Addons on this machine that declare only 16001 load and save data.
- **Spellbook exposes untrained spells.** `C_SpellBook.GetSpellBookItemInfo` returns `itemType = FutureSpell` for spells not yet learned, and `C_SpellBook.GetSpellBookItemLevelLearned` gives the level. Blizzard's own spellbook marks a spell "trainable" when that level is at or below the player's level. Spell ranks exist (`IsSpellBookItemLowRank`).
- **Missing-from-bars check exists.** `ActionButtonUtil.GetActionBarStatusForSpell(actionID, true, false)` returns `MissingFromAllBars`; fallback `C_ActionBar.FindSpellActionButtons`.
- **Trainer window data** at `TRAINER_SHOW`: `GetNumTrainerServices`, `GetTrainerServiceInfo(i)` (name, available/unavailable/used, required level, rank text), `GetTrainerServiceCost`, `C_Trainer.GetTrainerType()`.
- **One event identifies every service NPC**: `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` with `Enum.PlayerInteractionType` (Merchant, Trainer, Banker, MailInfo, Auctioneer, TaxiNode, Binder = innkeeper, StableMaster, Transmogrifier, and more).
- **City guard directions are readable**: `DYNAMIC_GOSSIP_POI_UPDATED` plus `C_GossipInfo.GetPoiForUiMapID` / `GetPoiInfo` (name and map position).
- **Minimap tracking covers the services new players look for**: Repair, Innkeeper, TaxiNode, Stablemaster, Battlemaster, TrainerClass, TrainerProfession, Auctioneer, Banker, Mailbox (`Blizzard_Minimap/Camelot/MinimapConstants.lua`), toggled with `C_Minimap.SetTracking`.
- **Map functions exist**: `C_Map.GetMapLevels`, `C_Map.GetMapChildrenInfo`, `C_TaxiMap.GetTaxiNodesForMap` (position, name, faction, discovered or not), `C_EncounterJournal.GetDungeonEntrancesForMap`, `C_Map.SetUserWaypoint`, `C_SuperTrack.SetSuperTrackedUserWaypoint`. The Forever world map uses the flight point, dungeon entrance and waypoint pin providers.
- **Legacy system is built on standard APIs**: challenges are achievements (`GetCategoryList`, `GetAchievementInfo`), points are a trait currency (`C_Traits`), the reward track is a renown faction (`C_MajorFactions`), IDs in `Constants.LegacyConsts`.
- **Group finder** is the vanilla-style list; `C_LFGList.GetActivityInfoTable` carries `minLevel`, `minLevelSuggestion`, `maxLevelSuggestion`, `mapID` per dungeon.
- **Experience preset** is readable: `C_GameRules.GetForeverExperiencePreset()` returns Classic (0) or Enhanced (1).
- **Addon compartment** (the minimap addon menu) exists on Forever; TOC field `AddonCompartmentFunc`.
- **Secret values**: `UnitName` and `UnitGUID` can be secret when unit identity is restricted; guard with `issecretvalue`. Position, level, money, bag and spellbook reads carry no secret flags.

### Not yet verified (functions exist, returned data unknown until probed in-game)

- Whether `C_Map.GetMapLevels` returns real level ranges for Forever zones.
- Whether `GetTaxiNodesForMap` and `GetDungeonEntrancesForMap` return data on every Forever map, including the new zones.
- Whether `SetSuperTrackedUserWaypoint` shows the in-world marker on Forever (one fan site lists it as blocked; an installed addon calls it without guarding).
- Whether the minimap tracking list is the same for every class and level.

Phase 0 settles all four with a probe (section 7).

### Game facts used in the design (community sources unless marked official)

- Class spells and ranks are bought from class trainers; trainers are race and faction specific and some are sparse (Alliance shaman, Horde paladin, Skyborne).
- Weapon skills are the Classic system, with weapon masters in capitals.
- Talents start at level 10 (9 with a Legacy perk). Dual spec: level 40, 50 gold, from the class trainer.
- Riding: level 40, about 100g training plus 20g mount; level 60, about 1,000g plus 200g. Sources disagree on whether the mount is included.
- No flying, no level scaling, no summoning stones, no automatic group finder: players walk to dungeons.
- Rested XP: accrues in inns and capitals, caps at 150% of a level, doubles kill XP only.
- Official: Camping (campfire from Cooking, profession camp items at skill 20), PvP rank points with a weekly cap, experience preset contents.
- Level ranges for every dungeon, including the 9 new ones (Warcraft Wiki, Patch 1.60). Raids open 2026-12-09.
- Legacy: account-wide, about 65 points at launch, 16 spendable per character, three perk trees.

## 3. Features by phase

### Phase 0: skeleton and probe

- TOC, saved variables, slash command `/trailhead` (alias `/th`), keybinding, minimap button and addon compartment entry.
- Empty themed window with the tab rail.
- `/trailhead probe`: records what the unverified APIs return into saved variables. I read the saved-variables file from disk afterwards, so nothing has to be copied out of the chat window.

### What the first game check proved (2026-11-11, level 21 Horde rogue, The Barrens)

- No errors, no failed sections, no missing events. Native waypoints work and the marker was seen.
- `C_Map.GetMapLevels` answers 0 for every zone. **Zone and dungeon level ranges come from the group finder list** instead (`C_LFGList.GetAvailableActivities` and `GetActivityInfoTable`: `fullName`, `minLevelSuggestion`, `maxLevelSuggestion`, `categoryID`; 116 is zones, 2 is dungeons). Its names can differ from map names by a leading "The".
- `C_TaxiMap.GetTaxiNodesForMap` lists every flight point with position and faction (1 Horde, 2 Alliance, 0 neutral), named "Town, Zone". `isUndiscovered` is always false, so it cannot tell which ones the player has.
- `C_EncounterJournal.GetDungeonEntrancesForMap` returns nothing. Dungeon entrances need our own data (Phase 2).
- The spellbook has no `FutureSpell` items, so trainable spells cannot be read from it. Trainable spells are read from the trainer's own list when the player visits. (`C_SpellBook.GetCurrentLevelSpells` was tried as a stand-in and dropped: it answers for level 1 only.)
- Spells missing from the bars: `ActionButtonUtil.GetActionBarStatusForSpell` works as planned.
- Minimap tracking has 26 entries and can be switched by addon code; entries are matched by icon file id.

### What the second game check proved (2026-11-11, same character, Orgrimmar)

- Places are learned at vendors, repairers, the bank and the mailbox (`PLAYER_INTERACTION_MANAGER_FRAME_SHOW` works for the last two). Innkeeper, auction house and stable were not visited.
- A guard's directions are captured and filed correctly ("A class trainer > Rogue" became a class-trainer place at the flag's position).
- **Zones page crashed** (the sort compared a missing value with a false one). Fixed in 0.2.1.
- **The trainer window opens empty**; its list arrives with `TRAINER_UPDATE`. 0.2.0 judged it too early and filed the class trainer under "other". 0.2.1 waits for the list, recognises a class trainer by ranked spells, and moves a wrongly filed record.
- **The trainer window's filter hides spells for later levels**, so only what could be learned at once was saved. 0.2.1 switches the "unavailable" filter on for a moment, reads the full list and puts the filter back (`GetTrainerServiceTypeFilter`, `SetTrainerServiceTypeFilter`). Whether the game applies that at once or a moment later is unknown; both are handled and what happened is written to the game check. If it cannot be done, the Spells page says to tick Unavailable in the trainer's filter.
- No screenshots were found, so the new pages and the Journal and Ember looks are still unseen.

**Re-check with 0.2.1 (same day):** no new errors; Zones opens. The trainer filter change applies at once: 6 services became 94, the filter was put back, and the trainer was filed as "Rogue: Shenthul". Learned from that list and the check:

- The game calls later ranks of a spell you have not bought yet "available" (Garrote at 22, 30, 38… with rank 1's price) although they need a higher level. 0.2.2 lets the required level decide what is ready now.
- Rank text ("Rank 2") is often not loaded yet when the list is read, and the service's category is blank for most spells ("Poisons" is the only one filled in). Ranks are told apart by required level instead.
- The group finder lists zones that did not exist in 2006 (Riverglades, Mount Hyjal) and, at level 21, no raids. World data cannot be assumed from old Classic.

### What the fourth game check proved (2026-11-11, same character, Orgrimmar)

- **Maps.** Map ids are the Classic ones (Orgrimmar 1454, Durotar 1411, Kalimdor 1414, Azeroth 947). `C_Map.GetMapRectOnMap` and `GetMapWorldSize` work (Kalimdor is 36799.8 x 24533.2 yards), so distances between zones are real. The game gives **no** sea crossings (`GetMapLinksForMap` is empty), no dungeon entrances and only cities as points of interest: those must be learned as the player plays or checked by hand.
- **Flight points.** At a flight master `C_TaxiMap.GetAllTaxiNodes` marks each node current, reachable or unreachable; reachable ones are the points the character knows (5 saved). `isUndiscovered` on the map's own node list is always false and means nothing.
- **Entrances.** Walking into Ragefire Chasm recorded its door (Orgrimmar 0.53, 0.49).
- **Talents.** The tree is read the way the game's window reads it: one tree (1111) with three groups (Assassination, Combat, Subtlety), 54 talents in rows 600 apart, one currency (3820), and `PurchaseRank`, `CommitConfig` and `ImportLoadout` all present. The rogue tree has talents the 2006 game never had (Coup de Grace, Puncturing Wounds, Flash of Steel, Death Mark, Boot Knife and more), so a build can only be written from the talents' own texts: game check 5 records them.
- **Skills.** `C_SkillInfo` lists 27 lines under headings whose ids are the rows' category (Weapon Skills 6, Professions 11, Secondary Skills 9). A weapon skill's limit is 5 x level. Each profession appears twice (a child row with a parent id), so child rows are skipped.
- **Weapon skill, from Blizzard's own skills window** (`Camelot/SkillsFrame.lua`, `PaperDollFrameStats.lua`): each point under 5 x level takes 0.04% off the chance to hit (and to avoid a dodge or parry) and 0.04% off the chance to crit an enemy of your level. That is far milder than the 2006 game, so Trailhead says "a little", gives the real figure, and only raises a Home card from 50 points behind (2%). The same file maps each kind of weapon to its skill; fist weapons use Unarmed.
- **Game check 5 (same day).** The game's own text for each skill confirms the Guide's wording ("Higher weapon skill increases your chance to hit", "Higher defense makes you harder to hit", professions: "can be found on trainers around the world"). The tree has no row gates of its own (`GetTreeInfo().gates` is empty, `cannotRefund` is true); each talent carries a condition id for its row instead. `C_Spell.GetSpellDescription` is the wrong source for talent text: only 18 of 54 had arrived before the reload, and it prints wrong figures for talents with several ranks ("0% chance"). The game's talent button uses `C_TooltipInfo.GetTraitEntry(entry, rank)`; game check 6 reads that at the first and last rank, records each row's condition, and reads late texts again after 1, 3 and 6 seconds and as the interface reloads.
- **Game check 6 (same day).** `C_TooltipInfo.GetTraitEntry(entryID, rank)` gave all 54 talent texts at their first and last rank (the last non-empty line is the description). Each row of a tree asks for 5 more points in that tree (5, 10, 15, 20, 25, 30; the condition's `spentAmountRequired` is what is still missing), and `isAvailable` on a node follows that. The character has had one point a level since 10 (12 at 21) and the top level is 60, so a build is written for 51 points; that the rate holds to 60 is not confirmed. The rogue trainer teaches Shank at 24 and one talent grants "Poised": both are new to Forever and not yet understood, so the build leaves them out.
- **Found and fixed.** A city's flight master was marked on the edge of the zone around the city; markers now go on the town's own map when it takes one. Walking times are measured as the crow flies, so walks of 5 minutes or more now read "N minutes or more".

### Phase 1: the core loop (built)

**Home ("What now?")**. Up to three cards from a rules engine (`Services/Advisor.lua`), each with one or two short lines and one button. Cards can be dismissed until their subject changes.

| Card | Trigger | Data source |
|---|---|---|
| Game check | Not yet run with this version's questions | `Core/Probe.lua` |
| Unspent talent points | Points available | `C_ClassTalents.HasUnspentTalentPoints` |
| New spells to train | Trainer's saved list has spells available, or due since the last visit. Before the first visit: "Visit your class trainer" | Trainer window |
| Spells not on your bars | Known, non-passive, highest-rank class spell is missing from all bars | `ActionButtonUtil` |
| Gear is damaged | Any item under 25% durability | `GetInventoryItemDurability` |
| Bags nearly full | Fewer than 4 free slots | `C_Container` |
| This zone is too hard or outgrown | Zone range vs your level | Group finder list |
| A dungeon fits your level | Level inside a dungeon's range | Group finder list |
| Hearthstone not set | `GetBindLocation` | built-in |

Home also has a "Find nearby" grid (eight services), the next milestone (talents at 10, first dungeon from the game's list, mount at 40, level 60) and a rotating tip.

**Find it** (`Modules/Find.lua`, `Services/Places.lua`). A search box in the title bar plus category buttons. Results come from:

1. **Live game data**: every flight point for your side on your continent, nearest first.
2. **Places you have found**: every vendor, repairer, trainer, bank, mailbox, innkeeper, auction house and stable you use, and every direction a city guard gives you, remembered for all characters.
3. **Nearby mode**: one button turns on the matching minimap tracking.
4. Search also finds zones and dungeons with their level ranges.

"Set marker" places the game's own map marker and arrow and opens the map on it (0.2.2). An empty category says how places get learned and to ask a guard. No shipped location data yet (section 6).

**Spells** (`Modules/Spells.lua`). Left: class spells you know that are on no action bar. Right: what the class trainer has for you now with prices, and what comes at later levels.

**Zones** (`Modules/Zones.lua`). Every zone with its level range, judged against your level ("Right for you", "Almost", "Too dangerous", "Outgrown"), zones without a flight point for your side marked and listed last; a Dungeons list; "Open map" opens the game's map on the zone.

**To confirm in game** (cannot be tested offline):

- "Set marker" opens the map with the marker on it, and Trailhead sits beside the map (0.3.0): the placement is confirmed by the log (right of the map, full size); not yet seen in a screenshot.
- "Open talents" puts Trailhead beside the talent window (0.3.0): no record yet (the spellbook is confirmed by screenshot).
- Guide: Weapon skills and Talents are confirmed by screenshot (0.5.0, 0.5.1), with the low flag when an axe is equipped. Still to see: Professions, and whether Home showed the card for a weapon far behind.
- Found in game with 0.6.0 and fixed in 0.6.1: pressing "Open talents" closed Trailhead. The talents tab is a centred game panel, and showing one runs the game's `CloseWindows`, which hides every frame in `UISpecialFrames`, Trailhead included (the spellbook is "centerOrLeft", so it never did). `Window:Keep` now takes Trailhead off that list while it opens a game window, and "Open talents" uses `PlayerSpellsUtil.OpenToClassTalentsTab` so it never closes a talent window that is already up. Opening the talents from the game's own button still closes Trailhead, like any Escape-closable window.
- **Game check 7** (run 2026-11-11 on the level 21 rogue, 0 failed). It reads rest state, the hearthstone, everything carried and worn, and logs the last 8 vendors and trainers opened (`TrailheadDB.visits`). Results:
  - Rest: `GetRestState()` gives `1, "Rested", 2` (id, the game's word, the experience multiplier); `GetXPExhaustion()` is the bonus experience left; `IsResting()` is true in an inn or city. The game's own help text says the rest of it: rested players earn twice the experience from monsters, and rest builds by spending time at or logging out at an inn or city.
  - Hearthstone: item 6948, "Use: Returns you to <home>. Speak to an Innkeeper in a different place to change your home location." with a 1 hour cooldown, read through `C_Container.GetItemCooldown(6948)` (the global `GetItemCooldown` is gone). A mount journal exists (`C_MountJournal`, 136 mounts listed).
  - Items: `C_Item.GetItemInfoInstant` files consumables as class 0 with subclass 5 "Food & Drink", 7 "Bandages", 1 "Potions", 4 "Scrolls"; armour is class 4 (1 Cloth, 2 Leather, 0 other); weapons class 2 (7 One-Handed Swords, 15 Daggers, 16 Thrown). Thrown weapons have durability. Durability is readable per slot.
  - Vendors opened: only three, all in The Crossroads (bags, cloth armour with repairs, tailoring supplies). Vendor tooltips carry "Requires Level N" and "Requires Tailoring (N)". No food vendor, poison vendor, mount vendor, riding trainer or weapon master has been recorded yet, so those stay unconfirmed.
- **0.8.0** builds two Guide topics from those results: "Inns and rest" (home, hearthstone ready or minutes left, rest state and bonus left, whether rest is building now) and "Supplies" (food and drink, bandages and potions counted from the bags; the carried food's own "Use:" line is quoted, and no effect is stated that the game did not say).
- Seen after 0.8.0 (2026-11-11): both topics confirmed by screenshot. The user also opened Rekkul (Orgrimmar, Cleft of Shadow): rogues in Forever brew poisons from vendor reagents (vials, Dust of Decay, Essence of Pain, "Used by rogues to brew poison."), plus Flash Powder and Thieves' Tools. Still no mount vendor, riding trainer or weapon master on record.
- **0.9.0**: the Guide's **Gear** topic (armor kinds from the "Armor Proficiencies" skill lines, worn armor counted by the game's label, the most worn piece and its durability, empty slots; repair is advised under 25%, the same line Home uses; nothing is ranked or recommended). **Game check 8** adds: `words` (every global string whose key starts TUTORIAL or NEWBIE_TOOLTIP, or mentions durability, repair, riding, mount, XP loss, resurrect, death, ghost, reagents: the game's own new player texts), `mounts` (each mount journal entry with its source text and whether it is usable), `spelltips` (the top of each known ability's tooltip, for reagents), and guard menus: any menu of four or more choices is written to `TrailheadDB.visits` as kind "menu" (16 visits kept now). The Mount and Dying topics, and "what your abilities use up" in Supplies, wait on this check.
- **Game check 8 results** (level 21 orc rogue, Orgrimmar, 0 failed): a city guard offers a profession trainer, class trainer, battlemaster, officers' lounge, stable master, **weapon master**, zeppelin master, auction house, mailbox, inn, guild master, wind rider master, bank, transmogrifier and barbershop, but no riding trainer. 541 of the game's own strings were read; the death texts exist in several variants (10% and 25% durability, no penalty below level 10), so no figure is shipped. The mount journal lists 136 mounts with **no source text**, so it cannot say where a mount comes from. `C_TooltipInfo.GetSpellByID` works (Pick Lock shows "Tools: Thieves' Tools"). The game's own map IDs for the cities and starting zones were read (Orgrimmar 1454, Stormwind 1453, and so on).
- **0.10.0**: `Data/Known.lua` holds places taken from launch guides (section 9): 8 weapon masters and 16 riding trainers and mount vendors, with map, position, zone and a note. Find it gets **Weapon master** and **Riding trainer** buttons (own faction; riding shows the player's own race), a place the player has seen replaces the guide's entry at that spot, and a guard's "weapon master" answer is filed under it. The Guide gets **Mount** (level 40, 100 gold, 60%; level 60, 1,000 gold, 100%; the player's level and money set against it; own trainer and vendor named; no price for the mount itself because guides disagree) and **Dying** (corpse run against the Spirit Healer, state read live: dead, ghost, Resurrection Sickness, most worn piece). Weapon skills points to the weapon master. The skyborne riding trainer (Genn Fairweather, Zephras Isle) is left out until that race's file name is known. Positions and prices are from guides and unconfirmed in game.
- Confirmed by screenshot (0.6.1): "Open talents" leaves Trailhead open and puts it to the right of the talent window, shrunk to fit. 0.7.1 adds where the next talent sits ("Combat, row 1 from the top").
- Builds (0.6.0, needs a full game restart): the page for the rogue, "Follow this build", the next point (Efficient Strikes 2 of 2 for the test character, at level 22), "Open talents" putting Trailhead beside the talent window, and the page moving on when the point is spent.
- A city flight master's marker lands inside the city (0.5.0).
- The three new pages and the new Home, in all three looks (screenshots).
- "Open map", "Show on the minimap", "Open spellbook" and "Open talents" work when pressed from Trailhead, and talents can still be spent in a window opened that way.
- The search box takes and releases the keyboard properly.
- Places at an innkeeper, an auction house and a stable.

### Phase 2: filling it out

- **Side-by-side windows** (built in 0.3.0, `UI/Window.lua`; to confirm in game). When a button in Trailhead opens one of the game's windows (spellbook, talents, map; later bags and character), Trailhead moves next to that window instead of sitting on top of it, and goes back to its own place when that window closes. Rules: beside the game window on whichever side has room, tops lined up; if there is no room for the full window it switches to a narrow strip that shows only what belongs to that window (spells missing from the bars next to the spellbook, the next talent next to talents); a full-screen map hides Trailhead until the map closes. Never moves in combat; can be switched off in Settings. Built so far: beside the game window at full size, or shrunk as far as the smallest size setting when room is short; follows the game window when it moves or changes size; with no room at all it stays where it is. The narrow strip for small screens is not built yet. Trailhead is placed from the game window's measured edges and never anchored to it. To confirm in game: it lands beside `PlayerSpellsFrame` (1154 wide in Forever's files) and `WorldMapFrame` and returns when they close; each placement is written to the game check (`learned.dockLog`).
- **Build guides** (new page "Builds", per class). One to three ready-made ways to play each class, starting with "Easy levelling" and adding a tank or healer build where the class has one. Each build has: who it suits in two lines, the talents in the order to take them, what to press in a fight in three or four lines, which stats to look for on gear, and which spells belong on the bars. The player picks one; Home, Spells and the talent helper then follow it.
  - **Built in 0.6.0** (`Data/Builds/ROGUE.lua`, `Services/Builds.lua`, `Modules/Builds.lua`): the rogue "Easy levelling" build (31 Combat, 17 Assassination, then 3 more in Lightning Reflexes), written from the texts of game check 6 and marked as a draft until it has been played. The page shows the next point with its reason and the game's own words for that rank, the points after it, what to press in a fight (only abilities the character has), and points spent outside the build. Home's talent card and the Guide's Talents topic name the next point; a Home card offers a build to a class that has one. The addon never spends a point. The offline checks spend the build point by point on the real tree and fail if the game would refuse one. Not yet built: gear stats and bar suggestions for a build, the other classes.
  - Data is ours, in `Data/Builds/<CLASS>.lua`, keyed by the game's own talent and spell ids, and checked against the live talent tree when the addon loads. An entry that does not match the game is hidden, never guessed.
  - Forever's talents run on the newer trait system (`C_Traits`, `PlayerSpellsFrame`, plus a "legacy adventure tree" that can lower the level talents start), so builds cannot be copied from 2006 guides. Each class needs its tree read from the game first (a new game check section), then a build written and tried. Order: rogue first, then one class at a time.
- **Talent helper**. A strip beside the game's talent window showing the chosen build: the next point to spend ("Next: … 2/5") with one line on why, the points after it, and a warning when a point has gone somewhere the build does not. The "unspent talent points" card opens it. Points are spent by the player's own click in the game's window by default. A "spend it for me" button and build import by text are added only if the game check shows the game allows them without errors (`C_Traits.PurchaseRank` and `CommitConfig`; Blizzard's import dialog code is present in Forever but may be switched off).
- **"How to get there" on everything** (first version built in 0.4.0: `Services/Routes.lua`, `Modules/Route.lua`; to confirm in game). Every row in Find it, the search and Zones (places, flight points, zones, dungeons, raids) has a "How to get there" button. It opens a page of numbered steps from where the player stands, each with its own "Set marker": walk to the nearest flight master, fly to the flight point nearest the destination, walk the last stretch, with the compass direction and a walking time. Built from:
  - the game's flight points for the player's side, and which ones this character has. The game's maps do not say which are found (`isUndiscovered` is false for all 136 listed to a level 21 character), so Trailhead reads the list each time a flight master's map opens and keeps it per continent. Until then the flight step says "if the flight master does not list it, you have not found it yet";
  - where each zone sits on its continent (`C_Map.GetMapRectOnMap`) and the continent's size in yards (`C_Map.GetMapWorldSize`); both unconfirmed until game check 4 is read. Without them the page falls back to a single "follow the marker" step;
  - dungeon and raid entrances learned by walking in: the spot where the player last stood outside is kept (account-wide, most-used door wins; summons, battlegrounds and logging in inside are ignored). A dungeon nobody on the account has entered says so plainly.

  Not built yet, because nothing shipped may be guessed: sea crossings (the page says "cross the sea to X, ask a city guard" and continues from the nearest flight point on the far side), which zones border which, and shipped entrance positions. Game check 4 records map links and map points of interest to see whether the game itself can supply these.

- **Dungeons and raids**: a Raids list next to Dungeons on the Zones page and in search (built in 0.4.0; it reads the game's own list, which is empty until raids open on 2026-12-09, and says so). For each: level, the zone the entrance is in once learned, and "How to get there". Still to build: group size, and for dungeons the short "your job as tank, healer or damage" card. No raid names are shipped: none could be checked in the game.
- **Bags and gold**: one-click junk selling at vendors, repair reminder, mount and dual-spec savings goal.
- **Know-how: everything a new player would ask** (scope widened 2026-11-11). The Guide page stops being a glossary and becomes the place for every "nobody told me that" topic. Each topic has the same four parts, so the page reads the same everywhere: what it is in two lines, where *you* stand right now (read from the game, never a generic table), what to do next, and "How to get there". A topic that needs attention also raises a card on Home. Topics, in build order:
  - **Talents** (first version built in 0.5.1, `G.Talents`): points in each tree, points left to spend with an "Open talents" button, and the level of the next point, said only when the character's own count fits one point a level since level 10. The full talent helper and builds are separate items above.
  - **Weapon skills** (built in 0.5.0, `Modules/Guide.lua`, `G.Skills`, `G.Hands`): every weapon skill with its rank and limit, the ones in hand first and marked, "Low" from 25 points behind, a Home card from 50, and what the gap costs in the game's own figures. Not built: which weapon types the class can still learn and who teaches them (weapon masters are unconfirmed in Forever), and the game's own text for each skill (recorded by game check 5).
  - **Coming up** (built in 0.7.0, the first part of level milestones): the next levels that bring something, one line each, from what the game itself lists: abilities on the class trainer's saved list, and the levels the group finder gives dungeons and zones. The next step says how far the next level is, what the trainer will have and what it costs against the money carried. No fact in it is ours.
  - **Level milestones** (the rest): a "what unlocks when" strip for your class (first talent point, new spell ranks, class quests, mount, new armour types, dungeons opening up), with the next one shown on Home.
  - **Professions** (first version built in 0.5.0): what you have with skill against its limit, "Near its limit" within 10 points (not for Lockpicking, whose limit follows your level), and a button to Find it's profession trainers. That a trainer raises the limit is likely but unconfirmed, so the text only says to see the trainer. Still to build: the two-profession limit and the three everyone can take (First Aid, Cooking, Fishing), once checked.
  - **Mount**: the level and gold it needs, a savings goal, and the trainer and vendor for your race.
  - **Gear**: what armour and weapons your class can use, which stats matter for it in one line each, repair and durability, and a plain "this is better" hint on items in your bags.
  - **Supplies**: food, water, bandages, and class needs (ammo, poisons, reagents, soul shards), with a "stock up before you leave town" card when they run low.
  - **Hearthstone, inns and rested XP**: where the stone is set, when it is ready, why to log out in an inn.
  - **Dying**: corpse runs, the spirit healer and its cost, repair bills.
  - **Town services**: bank, auction house, mailbox, flight master, stable: what each is for, in one line, with a route.
  - **Grouping**: finding a group, your job as tank, healer or damage, need or greed, dungeon keys and entry quests.
  - **PvP and danger**: what flags you, contested zones, why a skull-level enemy cannot be fought.
  - **Reputation and money**: what reputation buys, and the safe ways to earn gold early.
  - **Words and chat**: searchable glossary (LFM, WTS, BoE, need or greed) and the chat channels.
  - **Forever's own systems**: Legacy, Camping, rulesets and the experience preset.
  - **Class notes**: hunter pets and ammo, warlock and paladin mount quests, mage portal trainers, druid Moonglade, shaman totems, warrior stances, rogue poisons and lockpicking.

  Every one of these is a 2006-era idea that Forever may have changed or dropped (weapon skills included), so each topic gets a game check first and ships only with what the check confirms. Nothing is written from memory of the old game.

### Phase 3: depth and release

- **Legacy tracker** (built in 0.11.0, `Modules/Legacy.lua`): points, how they are earned, the three perk trees and rewards, buttons into the game's own Legacy window. Perk numbers and thresholds are left out where sources gave none.
- **Weekly**: not built. Nothing weekly exists at launch (raids open 2026-12-09); revisit then.
- **First-run setup** (built in 0.11.0): a welcome shown once with doors into the main pages (`Modules/Welcome.lua`), and a **Screen setup** page (`Services/Interface.lua`, `Modules/Setup.lua`) with eleven game options a first character benefits from, each read from Blizzard's own settings panels for this build, switched on by one click and undone by one click; Edit Mode, more action bars, key bindings and the Classic or Enhanced preset are explained and, where safe, opened.
- **Vendors** (0.11.0, `Services/Merchant.lua`): the game has its own Sell All Junk and Repair buttons, so Trailhead only offers "sell grey items by itself" and "repair by itself" (both off) and an optional second pair of buttons that shows the price first (off).
- **Localization** scaffolding (built: `tools/gen_locale_keys.py`).
- **Release** on CurseForge and Wago: `.pkgmeta`, `tools/package.sh`, README, changelog and the MIT licence are ready; publishing waits for the user.

### What 0.11.0 built and what the review found

Shipped data, all generated by `tools/gen_*.py` so it can be rebuilt for a new game build:

- **Places** (`Data/Seed.lua`, `tools/gen_seed.py`): places for every Find it category, by faction and class, merged with the player's own finds in `Services/Places.lua`.
- **Quest hubs** (`Data/Hubs.lua`, `tools/gen_hubs.py`, `Services/Hubs.lua`): hubs per zone with faction, levels, inn and flight flags, and the start hub for each side; shown on Zones, searchable, and used as the end of a zone route.
- **Dungeon routes** (`Data/DungeonIndex.lua` from the game's tables, `Data/Dungeons/*.lua` hand-written, `Services/Dungeons.lua`, `Modules/Dungeon.lua`): doors, boss lists, step-by-step routes, live boss ticks from `BOSS_KILL` and `ENCOUNTER_END`. This build has no in-dungeon maps, so routes are words.
- **Builds** (`tools/builds/*.json` to `Data/Builds/*.lua`, `tools/gen_builds.py`): 15 builds over nine classes, each checked point by point against the real tree by the generator and the tests. Drafts until played.
- **Guide data** (`Data/GuideTopics.lua`, `Data/ClassSpells.lua` from `tools/gen_guide_data.py`).

The review (same day, five independent passes against Forever-specific pages, the game's tables and Blizzard's UI source) is summarised in the changelog under 0.11.0. Standing limits it could not remove: most positions are from 2006-era data and unconfirmed for Forever; builds are unplayed; the new pages are unseen in the game.

## 4. Architecture

```
Trailhead/
  Trailhead.toc          Interface 16001; SavedVariables TrailheadDB (account), TrailheadCharDB (character)
  Bindings.xml
  Core/      Init.lua (namespace, events, module registry, slash)  DB.lua (defaults, migrations)
             Compat.lua (feature detection, safe calls, secret-value guards)  Probe.lua
  UI/        Theme.lua  Widgets.lua (card, button, list, search, rail)  Window.lua  MinimapButton.lua  Toast.lua
  Services/  Locator.lua (result providers, waypoint)  Learn.lua (records found places)  Advisor.lua (card rules)
  Modules/   Home.lua  Find.lua  Spells.lua  Zones.lua            (Phase 1)
             Travel.lua  Dungeons.lua  Bags.lua  Guide.lua        (Phase 2)
             Legacy.lua  Weekly.lua  Setup.lua                    (Phase 3)
  Data/      Categories.lua  Seed.lua  Dungeons.lua  Milestones.lua  Routes.lua  Glossary.lua
  Locales/   enUS.lua
  Media/
tests/       Lua 5.1 harness with stubbed game API
tools/       deploy.sh (copies the addon into the game)  export-seed.lua
```

Rules that keep it safe and maintainable:

- **Feature-detect, never assume.** Every game call goes through `Compat`, which checks the function exists and wraps it in `pcall`. A missing API disables one card, not the addon.
- **Nothing runs in combat.** Scans are deferred until `PLAYER_REGEN_ENABLED`; the window can auto-hide in combat. No unit health, auras or combat log.
- **No libraries in Phase 1.** Own minimap button and options, so there is nothing to embed or keep updated.
- **One module per tab** with the same small contract (`OnInit`, `OnShow`, `Refresh`), so features can be added or dropped independently.
- **All text through the locale table** from the start.

## 5. Look and navigation

Own design, not modelled on any existing addon. Three looks ship from the start and can be switched at any time (Home, Settings, or `/th theme <name>`):

- **Night**: navy and gold, rounded cards, green main action.
- **Journal**: parchment page in a leather frame, wax-red main action, closest to classic Warcraft.
- **Ember** (default since 0.2.2, the user's choice): charcoal and orange, cut corners, headings in capitals.

How it is built:

- One window (920 x 600 before scaling): title bar, five tabs on a left rail, and a page for the current tab. A search box that searches everything joins the title bar with Find it.
- A theme is a table of colour roles, shapes and fonts (`UI/Theme.lua`). Widgets name a role, never a colour, so a theme switch restyles everything live and a fourth look is one more table.
- Shapes are white 64 px textures (rounded and cut-corner fills, borders, top highlights) drawn as nine slices at half size and tinted with the theme's colours. The banner landscape is one painted texture per theme. All of it is generated from the mockup sources by `tools/gen_media.py`, so art and mockups cannot drift apart.
- Text uses the game's own font files (looked up from its font objects), so every language renders correctly.
- Card meaning by colour: "do this now", "worth fixing", "optional".
- Opens from the minimap button, the addon compartment, a key binding or `/th`. Movable, scalable (70% to 140%), remembers its position, closes with Escape, hides in combat and comes back afterwards.
- Toasts (from Phase 1) are small, dismissible, rate-limited and never appear in combat.
- From Phase 2, Trailhead sits beside any game window it opens rather than over it (see "Side-by-side windows").

Limits of the game client to keep in mind: no blur, no letter spacing, and gradients only where they are painted into a texture.

## 6. Location data for Find it

The game API does not expose NPC positions, so this is the main risk.

- **Questie's database is not safe to reuse**: its licence file says historic content is all rights reserved, with only recent contributions under GPLv3, and it lists new Forever content as incomplete.
- **Waypoint Tracker** is MIT and ships a database covering the new zones. Its repository now names its sources (All The Things and pfQuest, both MIT, plus positions its users have seen in Forever) and includes their licences, so data derived from it can be shipped with those notices.

Plan:

1. Phase 1 ships with live game data, learning and nearby mode. Useful from the first minute in any town, with no licence exposure. **Built.**
2. A **record mode** (`/trailhead record`) lets you walk a city once and capture every service NPC. `tools/export-seed.lua` turns your saved file into `Data/Seed.lua`. Capitals and starter towns first.
3. Waypoints go through the TomTom-style API when Waypoint Tracker or TomTom is installed, so the addons cooperate.
4. Later, optionally: opt-in sharing of found places between users of the addon.
5. **Known places from published guides** (`Data/Known.lua`, from 0.10.0): a small hand-written list of facts (name, zone, position) for services the game cannot point to, each traceable to a source in section 9. No third-party database is copied.
6. **Shipped data** (decided by the user 2026-11-11: "it needs data already in the addon"). The addon ships with places for every Find it category, quest hubs per zone and faction, dungeon and raid entrances, boss lists and routes, so a brand-new character never starts with an empty list. What the player finds in game is added on top and wins over the shipped entry. Sources: the game's own tables for the installed build (wago.tools), Waypoint Tracker's database (MIT; it bundles All The Things and pfQuest, both MIT, and positions players have seen in Forever), and trainer name lists from the Warcraft wiki. The licence notices ship in `Trailhead/THIRD-PARTY-LICENSES.txt`. Generators live in `tools/gen_*.py` and take the source folders as arguments. Positions that come only from 2006-era data are the weak point: a place the player visits replaces them.

## 7. Testing and deployment

- **Offline**: `tools/check.sh` runs a `luac5.1 -p` syntax check on every file, then `tests/run.lua`, which loads the whole addon under Lua 5.1 against a strict fake of the game API (`tests/wowstub.lua`) and drives it like a player: opening the window, every tab, every theme, the advice cards, learning places from vendors, trainers and guards, search, markers, the spell and zone lists, the game check, combat, bad saved settings, a client with the optional APIs missing, secret values. It also checks that every texture the addon asks for exists.
- **In game**: `tools/deploy.sh` copies the addon to `_forever_/Interface/AddOns/Trailhead`; you `/reload` (restart the game when a version adds new files). A copy is used on purpose: an existing addon link in that folder (`ForeverSpeedroutes`) points at a deleted worktree and is broken.
- **Probe loop**: you run `/trailhead probe` and `/reload`; I read `WTF/Account/<account>/SavedVariables/Trailhead.lua` and adjust.
- **Errors**: `/console scriptErrors 1` during development.

## 8. Decisions

1. **Name: Trailhead** (decided 2026-11-11). No addon of that name on WoWInterface, Wago or GitHub; CurseForge could not be checked by script (it blocks automated requests) and a web search found nothing. Confirm when the project page is created.
2. **Look: all three themes ship**, Ember as the default (decided 2026-11-11; first Night, changed to Ember the same day).
3. **Location data: ship it** (decided by the user 2026-11-11). The addon carries built-in data from MIT-licensed sources and the game's own tables, with the licence notices included; see section 6, step 6. This replaces the earlier recommendation not to use a third-party database.
4. **Licence: MIT** (decided by the user 2026-11-11). `LICENSE` at the top of the repository and `Trailhead/LICENSE.txt` inside the addon; the notices for bundled data are in `Trailhead/THIRD-PARTY-LICENSES.txt`.
5. **Phase order.** Phases 0 and 1 built. Phase 2 starts with side-by-side windows, then "how to get there" with dungeon and raid locations, then the talent helper and build guides (all added 2026-11-11 at the user's request), then bags and the guide.
6. **Who writes the builds.** Open. Recommendation: drafted from the talent tree read out of the game, tried on a character, and only shipped for classes that have been checked; rogue first.

## 9. Sources

- Blizzard UI source, `forever` branch, build 1.60.1.70888: https://github.com/Gethe/wow-ui-source
- Blizzard starter guide: https://worldofwarcraft.blizzard.com/en-us/news/24315280
- Blizzard on PvP and seasons: https://news.blizzard.com/en-us/article/24303316
- Blizzard on Camping: https://news.blizzard.com/en-us/article/24301516
- Warcraft Wiki, Patch 1.60 and 1.60.1: https://warcraft.wiki.gg/wiki/Patch_1.60 , https://warcraft.wiki.gg/wiki/Patch_1.60.1
- Warcraft Wiki, TOC format: https://warcraft.wiki.gg/wiki/TOC_format
- Warcraft Tavern guides (class trainers, weapon skills, riding, experience, leveling): https://www.warcrafttavern.com/forever/guides/class-trainers/
- Warcraft Tavern, weapon masters: https://www.warcrafttavern.com/forever/guides/weapon-trainers/
- Warcraft Tavern, riding: https://www.warcrafttavern.com/forever/guides/riding/
- Icy Veins, class mounts and the riding fee: https://www.icy-veins.com/wow-forever/news/two-wow-forever-classes-can-skip-the-100-gold-riding-cost/
- Wowhead, death durability loss changed in beta: https://www.wowhead.com/forever/news/durability-loss-from-resurrection-penalty-reduced-in-wow-forever-beta-build-4-383325
- Blizzard, New Player's Starter Guide: https://news.blizzard.com/en-us/article/24315280/new-players-starter-guide-welcome-to-world-of-warcraft-forever
- Blizzard, Deep Dive panel recap: https://worldofwarcraft.blizzard.com/en-us/news/24303313/world-of-warcraft-forever-deep-dive-panel-recap
- Questie repository and licence: https://github.com/Questie/Questie
- Waypoint Tracker: https://www.curseforge.com/wow/addons/waypoint-tracker , https://github.com/sanjaygbhat/wowforever-waypoint-tracker
- Where's My Trainer: https://www.curseforge.com/wow/addons/wheres-my-trainer
- BigWigs packager: https://github.com/BigWigsMods/packager
- Forever addon API notes (fan site, used only as leads): https://wowforeverguides.com/addons/api-cheatsheet
- Added for 0.11.0 and its review: Warcraft Tavern's Forever guides (class and profession trainers, Legacy, dungeons, Zephras Isle, Riverglades): https://www.warcrafttavern.com/forever/ ; no group finder: https://www.warcrafttavern.com/forever/news/no-group-finder-or-summoning-stones-in-wow-forever/ ; Method's Forever levelling guides: https://www.method.gg/wow-forever/ ; the game's tables for build 1.60.1.70888: https://wago.tools/db2/ ; Waypoint Tracker's MIT location data (All The Things, pfQuest); wiki trainer and vendor categories: https://wowpedia.fandom.com

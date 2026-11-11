# CurseForge listing

Everything to paste into the CurseForge project form. Start at <https://www.curseforge.com/project/create> (or the Author Console, <https://authors.curseforge.com>), signed in with your own account.

## Project fields

| Field | Value |
|---|---|
| Game | World of Warcraft |
| Type | Addons |
| Name | Trailhead |
| Summary | The new player companion for WoW Forever: what to do next, where everything is, and how the game works, on the road to level 60. |
| Main category | Quests & Leveling |
| Other category | Map & Minimap (optional; pick only ones that fit, unrelated ones get a project sent back) |
| Licence | MIT License |
| Logo | `docs/images/logo.png` (512 x 512, our own artwork) |
| Source | https://github.com/pl0xuee/Trailhead |
| Issues | https://github.com/pl0xuee/Trailhead/issues |

Pictures for the project's image gallery: everything in `docs/images/` except the logo. Say in the captions that they are drawn outside the game, or replace them with screenshots from the game.

## First file

| Field | Value |
|---|---|
| File | `dist/Trailhead-0.12.0.zip` (built by `tools/package.sh`) |
| Display name | Trailhead 0.12.0 |
| Release type | Release (CurseForge only shows a project in its app once it has a Release file; Beta and Alpha files stay on the website) |
| Game version | Forever, 1.60.1 |
| Changelog | the 0.12.0 and 0.11.0 sections of `CHANGELOG.md` (Markdown) |

After the project is approved, add `## X-Curse-Project-ID: <the number on the project page>` to `Trailhead/Trailhead.toc` so the CurseForge app matches the addon to its page.

## Description (Markdown)

**Trailhead is the companion for your first character in World of Warcraft: Forever.** Open it with `/th` or the minimap button. It tells you what to do next, shows where things are, and explains the parts of the game nobody tells you about.

- **Home.** Up to three things worth doing right now: spells to train, talent points to spend, damaged gear, full bags, a dungeon that fits your level.
- **Find it.** Trainers, vendors, repair, inns, flight masters, mailboxes, banks, profession trainers, auction houses and more. About 1,800 places ship inside the addon, so it works on a brand-new character. They are listed closest first with the distance in yards, each with "How to get there" and a map marker.
- **Zones.** Which zones fit your level, where your side starts in each, and its quest hubs in order.
- **Dungeon routes.** For every dungeon and raid: where the door is, the way through, each boss and a tip. Inside a dungeon the page follows along and ticks bosses off.
- **Spells and Builds.** What your trainer teaches, which spells are not on your action bars, and ready-made talent builds for all nine classes. You place every point yourself; Trailhead shows where it goes.
- **Guide.** Short topics on how the game works (resting, dying, gear, weapon skills, professions, money, grouping), checked against your own character.
- **Screen setup.** A few game options that make the first hours easier, one click each and one click to undo.
- **Legacy.** Your Legacy Points, how to earn them and what they unlock.

Three looks: Ember, Journal and Night.

**What it does not do.** Trailhead never spends a talent point, buys, sells or travels for you without a click on a clearly labelled button, and it does nothing during a fight. It sends nothing anywhere: no network access, no accounts, no tracking.

**Commands.** `/th` opens it. `/th find bank` searches. `/th settings` opens the settings. `/th reset` moves the window back to the middle.

Trailhead needs no other addon. Source, issues and older versions: https://github.com/pl0xuee/Trailhead

local _, T = ...
local L = T.L
local C = T.Compat
local G = T.Game

-- Advisor: decides what the "What now?" cards on Home say. Each rule looks at the
-- character and either returns a card or nothing. Rules are listed most important first
-- and Home shows the first few.
--
-- A card: { id, tone ("go" do this now, "warn" worth fixing, "info" good to know), icon,
--           title, body, action (button text), run (what the button does),
--           key (what "dismiss" remembers; a new key brings the card back) }

local A = {}
T.Advisor = A

local dismissed = {} -- key -> true, until the next login

local function open(tab, arg)
	return function()
		T.Window:Open(tab, arg)
	end
end

local rules = {}

-- The game check, shown until it has been run with this version's questions.
rules[#rules + 1] = function()
	if A.checkedNow then
		return {
			id = "check", tone = "go", icon = "spark", keep = true,
			title = L["Check complete"],
			body = L["Reload the interface once so the results are saved."],
			action = L["Reload now"],
			run = function()
				local reload = C.Resolve("C_UI.Reload") or ReloadUI
				if reload then
					reload()
				end
			end,
		}
	end
	if T.Probe:IsCurrent() then
		return nil
	end
	local again = T.Probe:LastRun() ~= nil
	return {
		id = "check", tone = "go", icon = "spark", keep = true,
		title = again and L["Trailhead has new questions"] or L["Teach Trailhead about your game"],
		body = again and L["This version can learn more. Run the quick check once more."]
			or L["A quick check of what your game can tell Trailhead. It changes nothing."],
		action = L["Run check"],
		run = function()
			if T.Probe:Run() then
				A.checkedNow = true
			end
		end,
	}
end

-- Inside a dungeon or raid Trailhead knows: the route is one click away.
rules[#rules + 1] = function()
	local here = T.Dungeons and T.Dungeons.Current()
	if not here then
		return nil
	end
	local boss = T.Dungeons.Next(here.id)
	return {
		id = "indungeon", tone = "go", icon = "gate", key = "indungeon:" .. here.id,
		title = L["You are in %s"]:format(here.name),
		body = boss and L["Next boss: %s. Open the route to see the way and where each boss stands."]:format(boss.name)
			or L["Open the route to see the way and where each boss stands."],
		action = L["Open the route"],
		run = open("dungeon", here.name),
	}
end

rules[#rules + 1] = function()
	if not G.HasTalentPoints() then
		return nil
	end
	local progress = T.BuildGuide.Following()
	local nextPoint = progress and progress.next
	return {
		id = "talents", tone = "go", icon = "spark", key = "talents:" .. G.Level(),
		title = L["You have talent points to spend"],
		body = nextPoint and L["Next in your build: %s (%d of %d)."]:format(nextPoint.name, nextPoint.rank, nextPoint.max) .. "\n"
			.. L["Unspent points do nothing."]
			or L["Talents make your character stronger. Unspent points do nothing."],
		action = L["Open talents"],
		run = T.BuildGuide.Open,
	}
end

-- A ready-made build exists for this class and none is followed yet.
rules[#rules + 1] = function()
	if #T.BuildGuide.List() == 0 or T.BuildGuide.Chosen() or G.Level() < G.FIRST_TALENT_LEVEL or C.InCombat() or not T.BuildGuide.Usable() then
		return nil
	end
	return {
		id = "build", tone = "info", icon = "spark", key = "build",
		title = L["Not sure where talent points go?"],
		body = L["Trailhead has a ready-made build for your class.\nFollow it and every point has a place."],
		action = L["See builds"],
		run = open("builds"),
	}
end

rules[#rules + 1] = function()
	local training = G.Training()
	local count = #training.now
	if not training.source and G.Level() >= 2 and C.Has("GetNumTrainerServices") then
		-- Never been to the trainer on this character: the first visit is the advice.
		return {
			id = "train", tone = "go", icon = "cap", key = "train:first",
			title = L["Visit your class trainer"],
			body = L["Trainers sell your new spells as you level."] .. "\n"
				.. L["After one visit Trailhead lists them here with prices."],
			action = L["Find trainer"],
			run = open("find", "trainer"),
		}
	end
	if count == 0 then
		return nil
	end
	local body = G.NameList(training.now, 2)
	if training.cost > 0 then
		body = body .. "\n" .. L["Cost: about %s."]:format(G.MoneyText(training.cost))
	else
		body = body .. "\n" .. L["Your class trainer teaches them."]
	end
	return {
		id = "train", tone = "go", icon = "cap", key = "train:" .. G.Level() .. ":" .. count,
		title = count == 1 and L["1 new spell to train"] or L["%d new spells to train"]:format(count),
		body = body,
		action = L["Find trainer"],
		run = open("find", "trainer"),
	}
end

-- Several screen settings that suit a new player are not set: one card, gone once they are.
rules[#rules + 1] = function()
	local I = T.Interface
	if not I or C.InCombat() then
		return nil
	end
	local set, total = I.Counts()
	local left = total - set
	if left < 3 then
		return nil
	end
	return {
		id = "screen", tone = "info", icon = "gear", key = "screen",
		title = L["Set up your screen"],
		body = L["%d quick settings that make the game easier. You can undo each one."]:format(left),
		action = L["Set up my screen"],
		run = open("setup"),
	}
end

rules[#rules + 1] = function()
	local spells = G.SpellsOffBars()
	if #spells == 0 then
		return nil
	end
	return {
		id = "bars", tone = "warn", icon = "bars", key = "bars:" .. #spells .. ":" .. spells[1].name,
		title = #spells == 1 and L["1 spell is not on your action bars"]
			or L["%d spells are not on your action bars"]:format(#spells),
		body = G.NameList(spells, 2) .. "\n" .. L["Drag them from your spellbook to a bar."],
		action = L["Show me"],
		run = open("spells"),
	}
end

rules[#rules + 1] = function()
	local worst = G.LowestDurability()
	if not worst or worst >= 0.25 then
		return nil
	end
	return {
		id = "repair", tone = "warn", icon = "hammer", key = "repair",
		title = worst <= 0 and L["Some of your gear is broken"] or L["Your gear is nearly broken"],
		body = L["Any vendor with an anvil sign can repair it for a few coins."],
		action = L["Find repair"],
		run = open("find", "repair"),
	}
end

-- A weapon in hand whose skill is far behind its limit.
rules[#rules + 1] = function()
	local skill = G.WeaponsBehind(G.SKILL_FAR_BEHIND)[1]
	if not skill then
		return nil
	end
	return {
		id = "weapon", tone = "warn", icon = "hammer", key = "weapon:" .. skill.id,
		title = L["Your %s skill is low"]:format(skill.name),
		body = L["%d of %d: about %.1f%% less chance to hit and to crit."]:format(skill.rank, skill.max, G.SkillCost(skill)) .. "\n"
			.. L["It rises as you fight with that kind of weapon."],
		action = L["Open guide"],
		run = open("guide", "weapons"),
	}
end

rules[#rules + 1] = function()
	local free = G.FreeBagSlots()
	if free >= 4 or not C.Has("C_Container.GetContainerNumFreeSlots") then
		return nil
	end
	return {
		id = "bags", tone = "warn", icon = "bag", key = "bags",
		title = free == 0 and L["Your bags are full"] or L["Your bags are nearly full"],
		body = L["Sell grey items to any vendor: they are junk."],
		action = L["Find a vendor"],
		run = open("find", "vendor"),
	}
end

rules[#rules + 1] = function()
	local zone = G.CurrentZone()
	local level = G.Level()
	if not zone or not zone.lo or level < 1 then
		return nil
	end
	local state = G.RangeState(zone.lo, zone.hi, level)
	if state == "hard" then
		return {
			id = "zone", tone = "warn", icon = "mtn", key = "zone:" .. zone.map,
			title = L["%s is above your level"]:format(zone.name),
			body = L["It is meant for levels %d to %d. Monsters here are much stronger than you."]:format(zone.lo, zone.hi),
			action = L["See zones"],
			run = open("zones", "fit"),
		}
	elseif state == "done" and level < G.MaxLevel() then
		return {
			id = "zone", tone = "info", icon = "mtn", key = "zone:" .. zone.map,
			title = L["You have outgrown %s"]:format(zone.name),
			body = L["It is meant for levels %d to %d and gives little experience now."]:format(zone.lo, zone.hi),
			action = L["See zones"],
			run = open("zones", "fit"),
		}
	end
	return nil
end

rules[#rules + 1] = function()
	local level = G.Level()
	local fits = {}
	for _, dungeon in ipairs(G.World().dungeons) do
		if level >= dungeon.lo and level <= dungeon.hi then
			fits[#fits + 1] = dungeon
		end
	end
	if #fits == 0 then
		return nil
	end
	-- The one that opened most recently is the best match.
	table.sort(fits, function(a, b)
		return a.lo > b.lo
	end)
	local best = fits[1]
	return {
		id = "dungeon", tone = "info", icon = "gate", key = "dungeon:" .. best.name,
		title = L["A dungeon fits your level"],
		body = L["%s, levels %d to %d."]:format(best.name, best.lo, best.hi) .. "\n"
			.. L["Dungeons need a group of five."],
		action = L["See dungeons"],
		run = open("zones", "dungeons"),
	}
end

rules[#rules + 1] = function()
	if G.BindLocation() or not C.Has("GetBindLocation") then
		return nil
	end
	return {
		id = "home", tone = "info", icon = "bed", key = "home",
		title = L["Your hearthstone has no home"],
		body = L["Ask an innkeeper to make their inn your home."],
		action = L["Find an inn"],
		run = open("find", "inn"),
	}
end

-- The cards to show, most important first, at most `most` of them. With nothing to say,
-- one card says so.
function A.Cards(most)
	local out = {}
	local off = T.db.cardsOff or {}
	for _, rule in ipairs(rules) do
		local ok, card = pcall(rule)
		if not ok then
			T:LogError("advisor", card)
		elseif card and not off[card.id] and not (card.key and dismissed[card.key]) then
			out[#out + 1] = card
			if #out >= (most or 3) then
				break
			end
		end
	end
	if #out == 0 then
		out[1] = {
			id = "clear", tone = "go", icon = "check", keep = true,
			title = L["You are all set"],
			body = L["Nothing needs your attention right now. Trailhead will speak up when something does."],
		}
	end
	return out
end

-- Hides a card until what it is about changes, or until the next login.
function A.Dismiss(card)
	if card and card.key then
		dismissed[card.key] = true
		T:Fire("TH_ADVICE_CHANGED")
	end
end

function A.Reset()
	dismissed = {}
	T.db.cardsOff = {}
	T:Fire("TH_ADVICE_CHANGED")
end

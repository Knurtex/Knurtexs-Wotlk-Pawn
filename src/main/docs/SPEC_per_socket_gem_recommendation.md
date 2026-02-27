# Implementation Spec: Per-Socket-Color Gem Recommendation with Socket Bonus Evaluation

**Date:** 2026-02-27  
**Status:** Draft  
**Module owner:** `src/main/lua/wotlk-pawn.core.lua`  
**Frontend consumer:** `src/main/lua/wotlk-pawn.frontend.lua` → `AddEPToTooltip`  
**Depends on:** Cap-Aware Dynamic Gem Recommendation (implemented)

---

## 1. Problem Statement

The addon recommends a single BiS gem for all sockets, ignoring socket colors and socket bonuses. In WotLK 3.3.5a, matching all socket colors activates a socket bonus (e.g., "+6 Strength"). In many cases—especially with strong bonuses on items with 2–3 sockets—matching colors with hybrid gems and collecting the bonus yields more total EP than stacking the pure BiS gem everywhere.

The current system:
- Counts empty sockets but does not track per-socket color
- Does not parse socket bonus text
- Has no hybrid gem candidate pool
- Cannot compare "ignore colors" vs "match colors + bonus" strategies

---

## 2. Design Answers

### Q1: Most robust way to parse socket bonus text in WotLK 3.3.5a (enUS + deDE)?

**Tooltip line regex** is the only option—`GetSocketItemInfo()` requires the socketing UI to be open and is unavailable during tooltip hover.

**Approach:** Scan tooltip lines for the localized prefix, then extract the stat amount and stat name. Map the stat name to the addon's stat key using a reverse-lookup table.

**enUS pattern:**
```
"Socket Bonus: +(%d+) (.+)"
```
Example: `"Socket Bonus: +6 Strength"` → amount=6, statName=`"Strength"`

**deDE pattern:**
```
"Sockelbonus: +(%d+) (.+)"
```
Example: `"Sockelbonus: +6 Stärke"` → amount=6, statName=`"Stärke"`

**Edge cases in bonus text:**
- Multi-word stat names: `"Critical Strike Rating"`, `"Spell Power"`, `"Attack Power"`, `"Armor Penetration Rating"`, `"Defense Rating"` — the `(.+)` capture handles these naturally.
- The tooltip line is green (active bonus) or gray (inactive bonus) — we don't need to distinguish; we always parse the text and compute EP to evaluate the *hypothetical* bonus value.
- No known WotLK socket bonus uses multiple stats; they are always `"+X StatName"`.

**Stat name → stat key mapping table** (must cover all stat names that appear in WotLK socket bonuses):

```lua
local socketBonusStatMap = {
    -- enUS
    ["Strength"]                = "ITEM_MOD_STR_SHORT",
    ["Agility"]                 = "ITEM_MOD_AGILITY_SHORT",
    ["Stamina"]                 = "ITEM_MOD_STAMINA_SHORT",
    ["Intellect"]               = "ITEM_MOD_INTELLECT_SHORT",
    ["Spirit"]                  = "ITEM_MOD_SPIRIT_SHORT",
    ["Spell Power"]             = "ITEM_MOD_SPELL_POWER_SHORT",
    ["Attack Power"]            = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["Hit Rating"]              = "ITEM_MOD_HIT_RATING_SHORT",
    ["Critical Strike Rating"]  = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Haste Rating"]            = "ITEM_MOD_HASTE_RATING_SHORT",
    ["Expertise Rating"]        = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["Dodge Rating"]            = "ITEM_MOD_DODGE_RATING_SHORT",
    ["Parry Rating"]            = "ITEM_MOD_PARRY_RATING_SHORT",
    ["Defense Rating"]          = "ITEM_MOD_DEFENSE_RATING_SHORT",
    ["Resilience Rating"]       = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["Armor Penetration Rating"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["Spell Penetration"]       = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    ["Mana per 5 Seconds"]      = "ITEM_MOD_MANA_REGEN_SHORT",
    ["mana per 5 sec."]         = "ITEM_MOD_MANA_REGEN_SHORT",
    ["Mana per 5 sec."]         = "ITEM_MOD_MANA_REGEN_SHORT",

    -- deDE
    ["Stärke"]                      = "ITEM_MOD_STR_SHORT",
    ["Beweglichkeit"]               = "ITEM_MOD_AGILITY_SHORT",
    ["Ausdauer"]                    = "ITEM_MOD_STAMINA_SHORT",
    ["Intelligenz"]                 = "ITEM_MOD_INTELLECT_SHORT",
    ["Willenskraft"]                = "ITEM_MOD_SPIRIT_SHORT",
    ["Zaubermacht"]                 = "ITEM_MOD_SPELL_POWER_SHORT",
    ["Angriffskraft"]               = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["Trefferwertung"]              = "ITEM_MOD_HIT_RATING_SHORT",
    ["Kritische Trefferwertung"]    = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Tempowertung"]                = "ITEM_MOD_HASTE_RATING_SHORT",
    ["Waffenkundewertung"]          = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["Ausweichwertung"]             = "ITEM_MOD_DODGE_RATING_SHORT",
    ["Parierwertung"]               = "ITEM_MOD_PARRY_RATING_SHORT",
    ["Verteidigungswertung"]        = "ITEM_MOD_DEFENSE_RATING_SHORT",
    ["Abhärtungswertung"]           = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["Rüstungsdurchschlagswertung"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["Zauberdurchschlagskraft"]     = "ITEM_MOD_SPELL_PENETRATION_SHORT",
    ["Mana alle 5 Sek."]           = "ITEM_MOD_MANA_REGEN_SHORT",
    ["Mana pro 5 Sek."]            = "ITEM_MOD_MANA_REGEN_SHORT",
}
```

**Why a flat table with both locales?** Socket bonuses in WotLK always use a single stat. Stat name strings don't collide across enUS/deDE. One flat lookup avoids locale branching. If a future locale is added, append entries. This matches the addon's existing pattern of combining enUS+deDE in a single scan (see socket text scanning in `AddEPToTooltip`).

**Uncertainty:** The exact German wording for `"Mana per 5 Seconds"` socket bonuses varies across items (`"Mana alle 5 Sek."` vs `"Mana pro 5 Sek."`). Both variants are included. This should be verified in-game for completeness. All other stat names are well-established WotLK strings.

---

### Q2: Should we extend gemCandidates or build a separate hybrid gem pool?

**Build a separate `hybridGemCandidates` pool.** Rationale:

1. **Different purpose.** `gemCandidates` answers "what single gem goes in every socket?" — pure single-stat gems only. The hybrid pool answers "what gem best matches *this socket color*?" — a per-socket question.
2. **Different structure.** Hybrid gems have two stats and must be tagged with their gem color (which socket colors they satisfy). The existing `gemCandidates` entries have a single `stat`/`amount` pair.
3. **Scoring differs.** Hybrid gems use `ScoreGem` (multi-stat EP) from the cap-aware spec, not the single-stat `ScoreGemCandidate`.
4. **No pollution.** Adding 60+ hybrid gems to `gemCandidates` would slow the forward-simulation loop for the single-gem recommendation (which doesn't need hybrids).

The hybrid pool includes both **epic** (Phase 3+) and **rare** (Phase 1+) tiers, mirroring bis/budget:

```lua
local hybridGemPool = {
    bis = {
        -- Ametrine (Orange: red, yellow)
        { id = 40142, color = "orange", stats = { ITEM_MOD_STR_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 10 },
          name = { enUS = "Inscribed Ametrine", deDE = "Gravierte Ametrine" } },
        -- ... all epic orange, purple, green gems
    },
    budget = {
        -- Monarch Topaz (Orange: red, yellow)
        { id = 40037, color = "orange", stats = { ITEM_MOD_STR_SHORT = 8, ITEM_MOD_CRIT_RATING_SHORT = 8 },
          name = { enUS = "Inscribed Monarch Topaz", deDE = "Gravierter Monarchtopas" } },
        -- ... all rare orange, purple, green gems
    },
}
```

Pure gems also participate in color-matching (a red gem matches a red socket). The pool therefore includes both hybrid and pure gems, each tagged with their color. See Section 4 for the complete classification.

---

### Q3: For "match colors" strategy — how to pick which hybrid gem per socket?

**Per-socket independent maximization with cap-aware scoring.**

For each non-meta socket color `c` in the item:
1. Collect all gems whose color is compatible with `c` (see color compatibility in Section 4).
2. Score each gem using `ScoreGem()` (the existing multi-stat, cap-aware scoring function from the cap-aware spec).
3. Pick the gem with highest EP for that socket.

The socket bonus EP is added to the total only when **all** non-meta sockets have a color-compatible gem assigned.

**Greedy per-socket selection is optimal here** because:
- Each socket is filled independently; the gem in socket 1 doesn't constrain socket 2's candidates.
- The only coupling is the socket bonus, which is all-or-nothing (activate if all match). The algorithm evaluates the fully-matched scenario and compares against the fully-unmatched (all-BiS) scenario.
- There is no partial-match benefit in WotLK — you either match all sockets or the bonus is inactive.

**Forward simulation:** The per-socket gem picks should use the same `capCtx` (player stat snapshot) as the all-BiS recommendation. We do **not** forward-simulate each socket sequentially (socketing gem 1, then re-evaluating gem 2 with gem 1's stats added). Rationale:
- The tooltip recommendation is for a single item. Adding one hybrid gem's stats to the player snapshot before evaluating the next socket would overweight cap interactions within a single item.
- The cap-aware forward-simulation in `ResolveGemRecommendation` already handles the "global" cap state. Per-item socket fills are small enough (≤3 gems, ≤10 stat each) that intra-item simulation is unnecessary.
- Keeping it simple avoids O(n!) permutation problems for 3-socket items.

---

### Q4: How should the tooltip display change?

**Two modes** based on which strategy wins:

#### Mode A: "Ignore Colors" wins (or item has only one socket color)

Display unchanged from current behavior — single BiS + Budget gem recommendation:

```
--- Gem Recommendation ---
* BiS: Bold Cardinal Ruby (+20 Strength) +36.00 EP if socketed
* Budget: Bold Scarlet Ruby (+16 Strength) +28.80 EP if socketed
```

#### Mode B: "Match Colors" wins

Show per-socket recommendations with the bonus, and a summary EP comparison:

```
--- Gem Recommendation ---
* Red: Inscribed Ametrine (+10 Str/+10 Crit) +30.00 EP
* Yellow: Rigid King's Amber (+20 Hit) +36.00 EP
* Bonus: +6 Strength = +10.80 EP
* Total: +76.80 EP (vs +72.00 ignoring colors)
```

**Localization keys to add:**

```lua
-- enUS
SocketRedLabel    = "Red",
SocketYellowLabel = "Yellow",
SocketBlueLabel   = "Blue",
SocketBonusLabel  = "Bonus",
SocketTotalLabel  = "Total",
SocketVsIgnore    = "vs %s ignoring colors",

-- deDE
SocketRedLabel    = "Rot",
SocketYellowLabel = "Gelb",
SocketBlueLabel   = "Blau",
SocketBonusLabel  = "Bonus",
SocketTotalLabel  = "Gesamt",
SocketVsIgnore    = "gg. %s Farben ignorieren",
```

**Display rules:**
- If the item has a meta socket, skip it entirely in the recommendation (meta gem recommendation is out of scope).
- If the color-match strategy wins by < 0.01 EP, prefer the simpler "ignore colors" display.
- Budget tier: show per-socket budget gems only if the color-match also wins in the budget tier. Otherwise show the single budget gem line.
- When a pure gem happens to match its socket color (e.g., BiS is a red gem and the socket is red), note this implicitly — no need to call it out specially.

**Color coding:**
- Red socket gems: `|cffFF4444` (red tint)
- Yellow socket gems: `|cffFFFF00` (yellow tint)
- Blue socket gems: `|cff4488FF` (blue tint)
- Bonus line: `|cff00FF96` (green, same as BiS)
- Total line: `|cffFFD700` (gold)

---

### Q5: What about items with only one socket?

**Trivial case — socket bonus comparison still runs, but the outcome is usually "ignore colors."**

With one socket, color matching means using a gem that matches that single socket's color. If the BiS gem already matches (e.g., red socket and BiS is Bold Cardinal Ruby, a red gem), the bonus is free. If the BiS gem doesn't match (e.g., yellow socket and BiS is Bold Cardinal Ruby), the color-match option would use a hybrid or a pure yellow gem. Since single-socket bonuses in WotLK are typically small (e.g., +4 stat), the pure BiS gem almost always wins.

**Algorithm handles this naturally** — no special case needed. The comparison produces a clear winner, and the display follows Mode A or Mode B accordingly.

---

## 3. Gem Color Classification

### 3.1 Color Types

```lua
local GEM_COLOR = {
    RED    = "red",
    YELLOW = "yellow",
    BLUE   = "blue",
    ORANGE = "orange",  -- matches red OR yellow
    PURPLE = "purple",  -- matches red OR blue
    GREEN  = "green",   -- matches yellow OR blue
}
```

### 3.2 Socket Color Compatibility

A gem "matches" a socket if the gem's color overlaps with the socket's color:

```lua
local gemColorMatchesSocket = {
    red    = { red = true },
    yellow = { yellow = true },
    blue   = { blue = true },
    orange = { red = true, yellow = true },
    purple = { red = true, blue = true },
    green  = { yellow = true, blue = true },
}
```

Usage: `gemColorMatchesSocket[gem.color][socketColor]` → true/nil.

### 3.3 Gem ID → Color Classification

Rather than tagging every gem ID individually, derive color from the base gem type. The `gemData` table is already organized by gem family with comments. Add a parallel `gemColorMap` that maps gem ID ranges to colors:

```lua
local gemColorMap = {}

-- Classification function: called once at load time to populate gemColorMap
local function BuildGemColorMap()
    -- Epic gems
    -- Cardinal Ruby (Red): 40111-40118
    for id = 40111, 40118 do gemColorMap[id] = "red" end
    -- King's Amber (Yellow): 40119-40120, 40124-40125, 40128
    for _, id in ipairs({40119, 40120, 40124, 40125, 40128}) do gemColorMap[id] = "yellow" end
    -- Majestic Zircon (Blue): 40121-40123, 40126
    for _, id in ipairs({40121, 40122, 40123, 40126}) do gemColorMap[id] = "blue" end
    -- Ametrine (Orange): 40142-40162
    for id = 40142, 40162 do gemColorMap[id] = "orange" end
    -- Dreadstone (Purple): 40129-40141
    for id = 40129, 40141 do gemColorMap[id] = "purple" end
    -- Eye of Zul (Green): 40165-40182
    for id = 40165, 40182 do gemColorMap[id] = "green" end

    -- Dragon's Eye (JC-only, excluded from recommendation but classified for completeness)
    -- Red: 42142-42144, 42151-42154
    for _, id in ipairs({42142, 42143, 42144, 42151, 42152, 42153, 42154}) do gemColorMap[id] = "red" end
    -- Yellow: 42148-42150, 42156-42158
    for _, id in ipairs({42148, 42149, 42150, 42156, 42157, 42158}) do gemColorMap[id] = "yellow" end
    -- Blue: 36766, 36767, 42145-42146, 42155
    for _, id in ipairs({36766, 36767, 42145, 42146, 42155}) do gemColorMap[id] = "blue" end

    -- Rare gems
    -- Scarlet Ruby (Red): 39996-40003
    for id = 39996, 40003 do gemColorMap[id] = "red" end
    -- Autumn's Glow (Yellow): 40013-40017
    for id = 40013, 40017 do gemColorMap[id] = "yellow" end
    -- Sky Sapphire (Blue): 40008-40011
    for id = 40008, 40011 do gemColorMap[id] = "blue" end
    -- Monarch Topaz (Orange): 40037-40057
    for id = 40037, 40057 do gemColorMap[id] = "orange" end
    -- Twilight Opal (Purple): 40022-40034
    for id = 40022, 40034 do gemColorMap[id] = "purple" end
    -- Forest Emerald (Green): 40058-40075
    for id = 40058, 40075 do gemColorMap[id] = "green" end
end
```

**Why a build function instead of inline table?** The ID ranges are contiguous for most families, making `for` loops cleaner than 100+ explicit entries. Called once at addon load; the lookup table is O(1) thereafter.

---

## 4. Hybrid Gem Candidate Pool

### 4.1 Structure

Each hybrid candidate entry:

```lua
{
    id    = 40142,
    color = "orange",
    stats = { ITEM_MOD_STR_SHORT = 10, ITEM_MOD_CRIT_RATING_SHORT = 10 },
    name  = { enUS = "Inscribed Ametrine", deDE = "Gravierte Ametrine" },
}
```

### 4.2 Pool Construction

Rather than duplicating the entire `gemData` table, the hybrid pool is built dynamically from `gemData` + `gemColorMap` at load time:

```lua
local function BuildHybridGemPool()
    local pool = { bis = {}, budget = {} }

    -- Epic hybrid gems (Ametrine, Dreadstone, Eye of Zul)
    -- Plus epic pure gems (Cardinal Ruby, King's Amber, Majestic Zircon)
    local epicRanges = {
        -- Pure
        {40111, 40118}, {40119, 40128}, {40121, 40126},
        -- Hybrid
        {40129, 40141}, {40142, 40162}, {40165, 40182},
    }

    -- Rare hybrid gems (Monarch Topaz, Twilight Opal, Forest Emerald)
    -- Plus rare pure gems (Scarlet Ruby, Autumn's Glow, Sky Sapphire)
    local rareRanges = {
        -- Pure
        {39996, 40003}, {40008, 40017},
        -- Hybrid
        {40022, 40034}, {40037, 40057}, {40058, 40075},
    }

    for _, range in ipairs(epicRanges) do
        for id = range[1], range[2] do
            local stats = gemData[id]
            local color = gemColorMap[id]
            if stats and color then
                pool.bis[#pool.bis + 1] = {
                    id = id, color = color, stats = stats,
                    name = { enUS = "", deDE = "" },  -- populated from gem name table
                }
            end
        end
    end

    for _, range in ipairs(rareRanges) do
        for id = range[1], range[2] do
            local stats = gemData[id]
            local color = gemColorMap[id]
            if stats and color then
                pool.budget[#pool.budget + 1] = {
                    id = id, color = color, stats = stats,
                    name = { enUS = "", deDE = "" },
                }
            end
        end
    end

    return pool
end
```

**Gem names:** The existing `gemData` table doesn't store names. Two options:
1. Add a parallel `gemNameMap` table (id → `{enUS, deDE}`).
2. Use `GetItemInfo(id)` at runtime to get the localized name.

**Recommended:** Use `GetItemInfo(id)` for display names. It's already available at tooltip time and avoids maintaining a 100+ entry name table. Cache results lazily:

```lua
local gemNameCache = {}
local function GetGemName(gemID)
    if gemNameCache[gemID] then return gemNameCache[gemID] end
    local name = GetItemInfo(gemID)
    if name then gemNameCache[gemID] = name end
    return name or ("Gem #" .. gemID)
end
```

**Uncertainty:** `GetItemInfo(id)` may return nil on first call if the item isn't cached by the client. WotLK Classic `GetItemInfo` is synchronous for items already seen; for items never encountered by the player, the first call returns nil and fires `GET_ITEM_INFO_RECEIVED` when data arrives. Since gem IDs are for common gems the player has likely seen, this should work in practice. **Risk mitigation:** fall back to `"Gem #" .. id` if nil; the recommendation still functions with an ugly name for one tooltip hover, and the cache fills on subsequent hovers.

---

## 5. Algorithm: `ResolveSocketAwareGemRecommendation`

### 5.1 Signature

```lua
function addon.ResolveSocketAwareGemRecommendation(socketColors, socketBonusStat, socketBonusAmount)
```

**Parameters:**
- `socketColors`: list of non-meta socket colors, e.g., `{"red", "yellow", "blue"}`. Parsed in frontend, passed to core.
- `socketBonusStat`: stat key string, e.g., `"ITEM_MOD_STR_SHORT"`. nil if unparseable.
- `socketBonusAmount`: number, e.g., `6`. 0 if unparseable.

**Returns:**

```lua
-- Strategy A wins (ignore colors):
{
    strategy = "ignore",
    totalEP  = 108.0,
    gem      = { ... },  -- same as ResolveGemRecommendation().bis
}

-- Strategy B wins (match colors):
{
    strategy = "match",
    totalEP  = 114.8,
    ignoreEP = 108.0,  -- for "vs X ignoring colors" display
    bonusEP  = 10.8,
    sockets  = {
        { color = "red",    gem = { id=40142, name="...", stats={...}, ep=30.0 } },
        { color = "yellow", gem = { id=40125, name="...", stats={...}, ep=36.0 } },
        { color = "blue",   gem = { id=40130, name="...", stats={...}, ep=28.0 } },
    },
    bonus    = { stat = "ITEM_MOD_STR_SHORT", amount = 6 },
}
```

### 5.2 Algorithm Pseudocode

```
function ResolveSocketAwareGemRecommendation(socketColors, bonusStat, bonusAmount):
    if socketColors is empty then return nil
    
    capCtx = BuildCapContext()  -- reuse from cap-aware spec
    weights = addon.GetCurrentWeights()
    if not weights then return nil
    
    -- === Strategy A: Ignore colors ===
    bisResult = addon.ResolveGemRecommendation()  -- existing function
    if not bisResult then return nil
    
    ignoreEP = bisResult.bis.computedEP * #socketColors
    
    -- === Strategy B: Match colors ===
    matchEP = 0
    socketPicks = {}
    allMatched = true
    
    for i, socketColor in ipairs(socketColors) do
        bestGem = nil
        bestScore = -inf
        
        for _, gem in ipairs(hybridGemPool.bis) do
            if gemColorMatchesSocket[gem.color][socketColor] then
                score = ScoreGemMultiStat(gem.stats, weights, capCtx)
                if score > bestScore then
                    bestScore = score
                    bestGem = gem
                end
            end
        end
        
        if bestGem then
            socketPicks[i] = { color = socketColor, gem = bestGem, ep = bestScore }
            matchEP = matchEP + bestScore
        else
            allMatched = false
            break
        end
    end
    
    -- Add socket bonus EP
    bonusEP = 0
    if allMatched and bonusStat and bonusAmount > 0 then
        bonusWeight = weights[bonusStat] or 0
        bonusEP = bonusAmount * bonusWeight
        -- Apply cap awareness to bonus stat too
        bonusEP = ScoreStatWithCaps(bonusStat, bonusAmount, weights, capCtx)
        matchEP = matchEP + bonusEP
    end
    
    -- === Compare ===
    if allMatched and matchEP > ignoreEP + 0.01 then
        return {
            strategy = "match",
            totalEP  = matchEP,
            ignoreEP = ignoreEP,
            bonusEP  = bonusEP,
            sockets  = socketPicks,
            bonus    = { stat = bonusStat, amount = bonusAmount },
        }
    else
        return {
            strategy = "ignore",
            totalEP  = ignoreEP,
            gem      = bisResult.bis,
        }
    end
```

### 5.3 `ScoreGemMultiStat` — multi-stat cap-aware scoring

Reuse the existing `ScoreGem` function from the cap-aware spec (Section 3.5 of `SPEC_cap_aware_gem_recommendation.md`). It already handles:
- Multi-stat gems (iterates `gem.stats`)
- Hard cap prorating (hit, expertise)
- Soft cap partial splitting

The only difference: the current `ScoreGemCandidate` in the implemented code uses `candidate.stat` (singular). The hybrid pool entries use `candidate.stats` (table). A new scoring function (or a refactored existing one) must iterate the stats table:

```lua
local function ScoreGemMultiStat(stats, weights, playerStats, hitCap, expCap, hitType, softCaps)
    local totalEP = 0
    for stat, amount in pairs(stats) do
        -- Reuse per-stat scoring logic from ScoreGemCandidate
        local weight = weights[stat]
        if not weight or weight <= 0 then
            -- skip
        else
            local effective = amount
            -- Hard cap: hit
            if stat == "ITEM_MOD_HIT_RATING_SHORT" and hitCap > 0 then
                local cur = playerStats["ITEM_MOD_HIT_RATING_SHORT"] or 0
                if cur >= hitCap then effective = 0
                else effective = math.min(amount, hitCap - cur) end
            -- Hard cap: expertise
            elseif stat == "ITEM_MOD_EXPERTISE_RATING_SHORT" and expCap > 0 then
                local cur = playerStats["ITEM_MOD_EXPERTISE_RATING_SHORT"] or 0
                if cur >= expCap then effective = 0
                else effective = math.min(amount, expCap - cur) end
            -- Soft cap
            elseif stat ~= "ITEM_MOD_HIT_RATING_SHORT" and stat ~= "ITEM_MOD_EXPERTISE_RATING_SHORT" then
                local soft = softCaps[stat]
                if soft and type(soft.cap) == "number" and soft.cap > 0 then
                    local cur = playerStats[stat] or 0
                    local mult = type(soft.multiplier) == "number" and math.max(0, soft.multiplier) or 1
                    if cur >= soft.cap then
                        weight = weight * mult
                    elseif cur + amount > soft.cap then
                        local below = soft.cap - cur
                        local above = amount - below
                        totalEP = totalEP + below * weight + above * weight * mult
                        effective = 0  -- already added
                    end
                end
            end
            if effective > 0 then
                totalEP = totalEP + effective * weight
            end
        end
    end
    return totalEP
end
```

### 5.4 Socket Bonus Cap Awareness

The socket bonus stat itself must be evaluated with cap awareness. Example: if the bonus is "+8 Hit Rating" and the player is 3 below hit cap, only 3 hit rating is effective.

```lua
local function ScoreStatWithCaps(stat, amount, weights, playerStats, hitCap, expCap, softCaps)
    -- Same logic as a single-stat score from ScoreGemMultiStat
    -- Extracted for reuse with socket bonus
    local weight = weights[stat] or 0
    if weight <= 0 then return 0 end

    if stat == "ITEM_MOD_HIT_RATING_SHORT" and hitCap > 0 then
        local cur = playerStats["ITEM_MOD_HIT_RATING_SHORT"] or 0
        local effective = math.min(amount, math.max(0, hitCap - cur))
        return effective * weight
    elseif stat == "ITEM_MOD_EXPERTISE_RATING_SHORT" and expCap > 0 then
        local cur = playerStats["ITEM_MOD_EXPERTISE_RATING_SHORT"] or 0
        local effective = math.min(amount, math.max(0, expCap - cur))
        return effective * weight
    else
        local soft = softCaps[stat]
        if soft and type(soft.cap) == "number" and soft.cap > 0 then
            local cur = playerStats[stat] or 0
            local mult = type(soft.multiplier) == "number" and math.max(0, soft.multiplier) or 1
            if cur >= soft.cap then
                return amount * weight * mult
            elseif cur + amount > soft.cap then
                local below = soft.cap - cur
                local above = amount - below
                return below * weight + above * weight * mult
            end
        end
        return amount * weight
    end
end
```

---

## 6. Frontend Changes (`AddEPToTooltip`)

### 6.1 Socket Color Tracking

Replace the current socket counting loop:

```lua
-- CURRENT:
local emptySocketCount = 0
for i = 1, tooltip:NumLines() do
    local line = _G[tooltip:GetName() .. "TextLeft" .. i]
    local text = line and line:GetText()
    if text then
        if text:find("Red Socket") or ... then
            emptySocketCount = emptySocketCount + 1
        end
    end
end
```

With color-tracking:

```lua
-- NEW:
local emptySocketColors = {}  -- list of "red"/"yellow"/"blue", excluding meta
local emptySocketCount = 0
local socketBonusStat, socketBonusAmount = nil, 0

for i = 1, tooltip:NumLines() do
    local line = _G[tooltip:GetName() .. "TextLeft" .. i]
    local text = line and line:GetText()
    if text then
        -- Socket color detection
        if text:find("Red Socket") or text:find("Roter Sockel") then
            emptySocketColors[#emptySocketColors + 1] = "red"
            emptySocketCount = emptySocketCount + 1
        elseif text:find("Yellow Socket") or text:find("Gelber Sockel") then
            emptySocketColors[#emptySocketColors + 1] = "yellow"
            emptySocketCount = emptySocketCount + 1
        elseif text:find("Blue Socket") or text:find("Blauer Sockel") then
            emptySocketColors[#emptySocketColors + 1] = "blue"
            emptySocketCount = emptySocketCount + 1
        end
        -- Meta sockets: detected but NOT added to emptySocketColors
        -- (kept for emptySocketCount for backward compat with existing display logic)
        if text:find("Meta Socket") or text:find("Meta%-Sockel") then
            emptySocketCount = emptySocketCount + 1
        end

        -- Socket bonus parsing
        local amount, statName = text:match("Socket Bonus: %+(%d+) (.+)")
        if not amount then
            amount, statName = text:match("Sockelbonus: %+(%d+) (.+)")
        end
        if amount and statName then
            socketBonusAmount = tonumber(amount) or 0
            socketBonusStat = socketBonusStatMap[statName]
        end
    end
end
```

**Key change:** Meta sockets increment `emptySocketCount` (for display/warning purposes) but are NOT added to `emptySocketColors` (not passed to the recommendation engine).

### 6.2 Calling the Socket-Aware Recommendation

After parsing, when `#emptySocketColors >= 2` and `socketBonusStat` is non-nil, call the socket-aware engine:

```lua
local socketRecs = nil
if #emptySocketColors >= 2 and socketBonusStat then
    socketRecs = addon.ResolveSocketAwareGemRecommendation(
        emptySocketColors, socketBonusStat, socketBonusAmount
    )
end
```

**Why >= 2?** With a single non-meta socket, color matching is trivially handled by the existing single-gem recommendation. The per-socket display adds complexity but no meaningful value for 1-socket items. However, the algorithm itself would still work for 1 socket — this is a display optimization, not a correctness requirement.

**When socketBonusStat is nil** (unparseable bonus), fall back to the existing single-gem recommendation. The bonus text in the tooltip may have been modified by another addon or use an unrecognized locale string.

### 6.3 Rendering Logic

```lua
if socketRecs and socketRecs.strategy == "match" then
    -- Per-socket display (Mode B)
    tooltip:AddLine("|cff888888--- " .. L("GemRecommendationHeader") .. " ---|r")
    
    local colorTint = {
        red = "|cffFF4444",
        yellow = "|cffFFFF00",
        blue = "|cff4488FF",
    }
    local colorLabel = {
        red = L("SocketRedLabel"),
        yellow = L("SocketYellowLabel"),
        blue = L("SocketBlueLabel"),
    }
    
    for _, pick in ipairs(socketRecs.sockets) do
        local tint = colorTint[pick.color] or "|cff888888"
        local gemName = GetGemName(pick.gem.id)
        tooltip:AddLine(string.format(
            "%s* %s: %s +%s EP|r",
            tint, colorLabel[pick.color], gemName,
            FormatLocalizedNumber(pick.ep, 2)
        ))
    end
    
    -- Bonus line
    if socketRecs.bonusEP > 0 then
        local bonusLabel = "+" .. socketRecs.bonus.amount .. " " 
            .. GetLocalizedStatLabel(socketRecs.bonus.stat)
        tooltip:AddLine(string.format(
            "|cff00FF96* %s: %s = +%s EP|r",
            L("SocketBonusLabel"), bonusLabel,
            FormatLocalizedNumber(socketRecs.bonusEP, 2)
        ))
    end
    
    -- Total line
    tooltip:AddLine(string.format(
        "|cffFFD700* %s: +%s EP (%s)|r",
        L("SocketTotalLabel"),
        FormatLocalizedNumber(socketRecs.totalEP, 2),
        string.format(L("SocketVsIgnore"),
            FormatLocalizedNumber(socketRecs.ignoreEP, 2))
    ))
else
    -- Existing single-gem display (Mode A) — unchanged
    ...
end
```

---

## 7. Edge Cases

| Scenario | Behavior |
|---|---|
| **Meta socket only** | `emptySocketColors` is empty. No socket-aware recommendation. Existing single-gem rec still shows. |
| **Meta + 1 red socket** | `emptySocketColors = {"red"}`. Single socket → existing rec. Color match is trivially correct if BiS is red. |
| **Item with no socket bonus text** | `socketBonusStat = nil`. Falls back to single-gem rec. All items with sockets in WotLK have a bonus, but parsing might fail. |
| **Socket bonus stat has weight 0** | `bonusEP = 0`. Color match strategy unlikely to win (hybrid gems lose EP vs pure). Algorithm handles correctly. |
| **Socket bonus stat is at hard cap** | E.g., bonus is "+8 Hit Rating" but player is hit capped. `ScoreStatWithCaps` returns 0. Color match loses. |
| **All sockets same color** | E.g., 3× red. Color match uses the best red-compatible gem for each socket (same gem ×3). If that gem = BiS pure gem, strategies tie and "ignore" wins (simpler display). |
| **Partially socketed items** | Only **empty** sockets appear in tooltip as "Red Socket" text. Already-socketed gems show as gem names instead. `emptySocketColors` only contains unsocketed positions. If 1 of 3 sockets is filled, only 2 remain in `emptySocketColors`. **Problem:** we lose the bonus evaluation context (was the filled socket correctly color-matched?). **Mitigation:** Only show per-socket recommendations when **all** non-meta sockets are empty. If any are filled, fall back to single-gem rec. |
| **Bonus stat not in socketBonusStatMap** | `socketBonusStat = nil`. Falls back to single-gem rec. Log to debug channel if available. |
| **Non-English/German locale** | Socket text won't match. `emptySocketColors` stays empty, `emptySocketCount` stays 0. Feature degrades gracefully to no gem recommendation display. |
| **Dragon's Eye gems** | Excluded from hybrid pool (JC-only with 3-gem equip limit). A JC player should use Dragon's Eyes in the sockets that preserve the most EP, but this requires profession detection (out of scope). |
| **Color-match wins by < 0.01 EP** | Treat as tie → show "ignore colors" display for simplicity. |

---

## 8. Performance Analysis

**Per-tooltip overhead for socket-aware recommendation:**

- Socket color parsing: already scanning tooltip lines (no extra pass needed — augment existing loop).
- Socket bonus parsing: one additional regex per tooltip line during the same pass.
- Strategy A (ignore colors): `ResolveGemRecommendation()` already called → **0 extra cost**.
- Strategy B (match colors): for each socket color, iterate the hybrid pool.
  - Epic hybrid pool size: ~60 gems (13 red + 5 yellow + 4 blue + 21 orange + 13 purple + 18 green).
  - Per gem: 1–2 stat multiplications + cap checks.
  - Per socket: ~60 iterations × ~3 operations = ~180 ops.
  - 3 sockets max: ~540 ops.
  - Plus bonus scoring: 1 operation.
  - Plus one comparison with Strategy A.
- **Total: ~550 trivial arithmetic operations per tooltip.** Negligible.

**Memory:** `gemColorMap` ~110 entries, `hybridGemPool` ~120 entries (60 bis + 60 budget). Both built once at load. Minimal footprint.

---

## 9. Module Ownership

| Change | Module | Rationale |
|---|---|---|
| `socketBonusStatMap` table | `wotlk-pawn.core.lua` | Stat mapping is core data |
| `gemColorMap` + `BuildGemColorMap()` | `wotlk-pawn.core.lua` | Gem classification is core data |
| `hybridGemPool` + `BuildHybridGemPool()` | `wotlk-pawn.core.lua` | Gem candidate pools live in core |
| `ScoreGemMultiStat()` | `wotlk-pawn.core.lua` | EP math is core concern |
| `ScoreStatWithCaps()` | `wotlk-pawn.core.lua` | EP math is core concern |
| `addon.ResolveSocketAwareGemRecommendation()` | `wotlk-pawn.core.lua` | Recommendation logic is core |
| Socket color parsing in `AddEPToTooltip` | `wotlk-pawn.frontend.lua` | Tooltip scanning is frontend |
| Socket bonus parsing in `AddEPToTooltip` | `wotlk-pawn.frontend.lua` | Tooltip scanning is frontend |
| Per-socket tooltip rendering | `wotlk-pawn.frontend.lua` | UI output is frontend |
| New localization keys | `wotlk-pawn.frontend.lua` | L10n strings live in frontend |

---

## 10. File Changes Summary

| File | Change |
|---|---|
| `wotlk-pawn.core.lua` | Add: `socketBonusStatMap`, `GEM_COLOR`, `gemColorMatchesSocket`, `gemColorMap`, `BuildGemColorMap()`, `BuildHybridGemPool()`, `ScoreGemMultiStat()`, `ScoreStatWithCaps()`, `addon.ResolveSocketAwareGemRecommendation()`. Call `BuildGemColorMap()` at load. |
| `wotlk-pawn.frontend.lua` | Modify `AddEPToTooltip`: replace socket counting with color tracking + bonus parsing. Add conditional call to `ResolveSocketAwareGemRecommendation`. Add Mode B rendering. Add localization keys for socket labels. |
| `wotlk-pawn.lua` | No changes. |
| `wotlk-pawn.persistence.lua` | No changes. |
| `src/main/resources/todos` | Update status of per-socket-color task. |

---

## 11. Validation Criteria

### PASS:

1. **2-socket item (red+yellow), strong bonus (+8 Str):** Tooltip shows per-socket recommendation with matched gems and bonus EP breakdown. Total EP > ignore-colors EP.
2. **2-socket item (red+yellow), weak bonus (+2 Resilience):** Tooltip shows single BiS gem recommendation (ignore colors wins).
3. **3-socket item (red+yellow+blue), moderate bonus (+6 Spell Power):** Correct per-socket or single recommendation based on EP comparison.
4. **1-socket item:** Standard single-gem recommendation (no per-socket display).
5. **Meta + 1 socket:** Only the non-meta socket appears in `emptySocketColors`. Single-gem rec shown.
6. **Player at hit cap, bonus is hit rating:** Bonus EP is 0 or reduced. Color match less likely to win.
7. **All sockets same color:** Compares pure BiS × N vs matched gem × N + bonus. Usually ignore wins.
8. **Partially socketed item (1 of 2 filled):** Falls back to single-gem rec (can't evaluate bonus fully).
9. **German client:** Socket text and bonus text parsed correctly in deDE.
10. **No lua errors:** All tooltip paths wrapped in existing `pcall` safety.

### FAIL:

1. Per-socket recommendation shown when all sockets are the same color and pure BiS already matches.
2. Socket bonus EP ignores caps (shows full hit bonus when player is hit capped).
3. Meta socket included in `emptySocketColors` or recommendation.
4. Lua error on tooltip hover for items with sockets.
5. Hybrid gem shown that doesn't actually match the socket color.
6. `socketBonusStatMap` missing a common WotLK bonus stat.

---

## 12. Future Work (Out of Scope)

- **Meta gem recommendations:** Different evaluation system (requires meta gem activation conditions).
- **Dragon's Eye / JC-specific:** Requires profession detection API.
- **Partially socketed optimization:** Recommending which remaining sockets to fill given already-socketed gems. Requires tracking filled socket colors.
- **Multi-item gem planning:** Optimizing gem distribution across all equipped items simultaneously.
- **Budget tier per-socket:** Currently spec'd for BiS tier only. Budget tier per-socket can be added later using the same algorithm with `hybridGemPool.budget`.

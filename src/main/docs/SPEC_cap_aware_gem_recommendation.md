# Implementation Spec: Cap-Aware Dynamic Gem Recommendation with Forward-Simulation

**Date:** 2026-02-27  
**Status:** Draft  
**Module owner:** `src/main/lua/wotlk-pawn.core.lua`  
**Frontend consumer:** `src/main/lua/wotlk-pawn.frontend.lua` → `AddEPToTooltip`

---

## 1. Problem Statement

The current `addon.GetGemRecommendation(className, specName)` maps each spec to a static archetype (`PhysicalDPS`, `SpellDPS`, `Healer`, `Tank`) and returns a hardcoded gem. This ignores:

- **Hard caps**: A Fury Warrior at 263 hit rating still sees Rigid King's Amber (hit 20) valued at full EP.
- **Soft caps**: A Feral Druid with ArP soft cap at 1400 (multiplier 0) still receives a Fractured Cardinal Ruby recommendation.
- **Partial-cap waste**: A player 8 hit below cap would waste 12 of the 20 hit from a Rigid gem.
- **Instability**: Naively using cap-aware scoring can flip-flop — recommending ArP until the simulated gem pushes ArP past its soft cap, switching to Str, which no longer pushes ArP past, switching back to ArP, etc.

---

## 2. Design Answers to Posed Questions

### Q1: Should the function handle partial-cap scenarios?

**Yes.** For hard caps (hit, expertise), the gem's stat contribution that exceeds the cap is wasted. The effective value should be prorated:

```
effectiveAmount = min(gemAmount, max(0, cap - currentValue))
```

This means a 20-hit gem when the player is 8 short of cap yields `effectiveAmount = 8`, and EP = `8 * hitWeight`. This is critical for accurate ranking — without it, a hit gem that wastes 60% of its budget can still outrank a crit gem.

For soft caps, partial-cap prorating is also applied: the portion of stat below the cap uses the full weight, and the portion above uses the reduced weight:

```
belowCap = max(0, min(gemAmount, softCap - currentValue))
aboveCap = gemAmount - belowCap
effectiveEP = belowCap * fullWeight + aboveCap * (fullWeight * softMultiplier)
```

### Q2: Forward-simulation stability — max iterations?

**Max 3 iterations** (configurable constant `MAX_SIM_ITERATIONS = 3`). Rationale:

- Iteration 0: Score all gems at current player stats → pick winner W₀.
- Iteration 1: Add W₀'s stats to player totals, rescore → pick W₁.
- Iteration 2: If W₁ ≠ W₀, add W₁'s stats instead, rescore → pick W₂.
- If W₂ = W₁, we have convergence. If W₂ ≠ W₁ (rare oscillation), fall back to the gem with the **highest minimum EP across iterations** (conservative choice).

In practice, convergence happens in 1–2 iterations for WotLK stat budgets. The 3-iteration cap is a safety net. Oscillation is most likely with ArP near a 0-multiplier soft cap — the fallback picks the stable non-ArP winner.

### Q3: Should AP (2:1 ratio to Str) ever be recommended?

**Yes, include it in the candidate pool but let EP weights decide.** AP gems give 40 rating vs 20 Str. Since most endgame weight tables define `ITEM_MOD_STR_SHORT` ≈ 2.0 and `ITEM_MOD_ATTACK_POWER_SHORT` ≈ 1.0: `20 * 2.0 = 40 EP` for Str vs `40 * 1.0 = 40 EP` for AP — a tie, with Str usually winning due to Kings/talents. Filtering AP out would be wrong for any spec whose weight table gives AP > Str/2 (some leveling profiles, Enhancement). The system should be generic; all single-stat gems in the pool compete on EP.

### Q4: Stats with weight 0 or very low weight?

Gems whose **only** stat has weight ≤ 0 in the current spec produce EP ≤ 0 and are naturally excluded by the max-EP ranking. No special filtering needed. If **all** candidates produce 0 EP (degenerate case — e.g., no weights loaded), the function returns `nil` and the frontend falls back to the existing static recommendation.

---

## 3. Algorithm: `ResolveGemRecommendation`

### 3.1 Signature

```lua
function addon.ResolveGemRecommendation()
```

Parameterless — reads all needed state from addon internals:
- `addon.GetCurrentWeights()` → current merged weight table
- `addon.GetClassData()` → HitCap, ExpCap, HitRatingType
- `addon.GetCurrentCapSettings()` → hitCap, expCap (with overrides applied)
- `addon.GetCurrentSoftCaps()` → generic soft cap table
- `addon.GetCurrentPlayerStatValue(stat)` → live player stat totals
- `addon.class`, `addon.GetCurrentSpecName()`

### 3.2 Return Value

```lua
-- Success:
{
    bis = {
        name     = { enUS = "Bold Cardinal Ruby", deDE = "Kühner Kardinalrubin" },
        id       = 40111,
        ep_stat  = "ITEM_MOD_STR_SHORT",    -- primary stat key
        ep_amount = 20,                      -- raw stat amount
        computedEP = 40.0,                   -- effective EP after cap awareness
        stats    = { ITEM_MOD_STR_SHORT = 20 }
    },
    budget = {
        name     = { enUS = "Bold Scarlet Ruby", deDE = "Kühner Scharlachrubin" },
        id       = 39996,
        ep_stat  = "ITEM_MOD_STR_SHORT",
        ep_amount = 16,
        computedEP = 32.0,
        stats    = { ITEM_MOD_STR_SHORT = 16 }
    }
}

-- Failure (no weights, all zero):
nil
```

The `ep_stat` field is set to the stat key that contributes the most EP for that gem (for single-stat gems, it's the only stat). This is used by the frontend for display labels.

### 3.3 Pseudocode

```
function ResolveGemRecommendation():
    weights = addon.GetCurrentWeights()
    if weights is empty then return nil

    capCtx = BuildCapContext()  -- snapshot current player stats + cap settings

    -- Phase 1: Score each candidate gem in both pools
    bisWinner  = SimulateAndResolve(bisCandidates, weights, capCtx)
    budgetWinner = SimulateAndResolve(budgetCandidates, weights, capCtx)

    if bisWinner is nil and budgetWinner is nil then return nil

    return { bis = bisWinner, budget = budgetWinner }
```

### 3.4 `BuildCapContext` — snapshot current player state

```lua
local function BuildCapContext()
    local classData = addon.GetClassData()
    local hitCap, expCap = addon.GetCurrentCapSettings()
    local hitType = classData and classData["HitRatingType"]
    local softCaps = addon.GetCurrentSoftCaps()

    -- Snapshot current player stat values for all stats that appear
    -- in any candidate gem or that have caps
    local statSnapshot = {}
    local statsToSnapshot = {
        "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_EXPERTISE_RATING_SHORT",
        -- Plus any stat that has a soft cap
    }
    for statKey, _ in pairs(softCaps) do
        statsToSnapshot[#statsToSnapshot + 1] = statKey
    end
    for _, stat in ipairs(statsToSnapshot) do
        statSnapshot[stat] = addon.GetCurrentPlayerStatValue(stat)
    end
    -- For hard-capped stats, use GetCombatRating for precision
    if hitType then
        statSnapshot["ITEM_MOD_HIT_RATING_SHORT"] = GetCombatRating(hitType)
    end
    statSnapshot["ITEM_MOD_EXPERTISE_RATING_SHORT"] = GetCombatRating(CR_EXPERTISE)

    return {
        hitCap = hitCap,
        expCap = expCap,
        softCaps = softCaps,
        statSnapshot = statSnapshot,
    }
end
```

### 3.5 `ScoreGem` — cap-aware EP for a single gem

```lua
local function ScoreGem(gem, weights, capCtx, statDeltas)
    -- statDeltas: table of stat adjustments from forward-simulation
    --             (e.g., if we're simulating "after socketing gem X")
    local totalEP = 0

    for stat, amount in pairs(gem.stats) do
        local weight = weights[stat]
        if not weight or weight <= 0 then
            -- Skip: stat has no value for this spec
        else
            local currentValue = (capCtx.statSnapshot[stat] or 0)
                               + (statDeltas and statDeltas[stat] or 0)

            -- Hard cap check (hit)
            if stat == "ITEM_MOD_HIT_RATING_SHORT" and capCtx.hitCap > 0 then
                local room = math.max(0, capCtx.hitCap - currentValue)
                local effective = math.min(amount, room)
                totalEP = totalEP + effective * weight
            -- Hard cap check (expertise)
            elseif stat == "ITEM_MOD_EXPERTISE_RATING_SHORT" and capCtx.expCap > 0 then
                local room = math.max(0, capCtx.expCap - currentValue)
                local effective = math.min(amount, room)
                totalEP = totalEP + effective * weight
            -- Soft cap check (generic, excludes hit/exp)
            elseif stat ~= "ITEM_MOD_HIT_RATING_SHORT"
               and stat ~= "ITEM_MOD_EXPERTISE_RATING_SHORT" then
                local soft = capCtx.softCaps[stat]
                if soft and type(soft.cap) == "number" and soft.cap > 0 then
                    local cap = soft.cap
                    local mult = type(soft.multiplier) == "number"
                                 and math.max(0, soft.multiplier) or 1

                    if currentValue >= cap then
                        -- Fully above soft cap
                        totalEP = totalEP + amount * weight * mult
                    elseif currentValue + amount > cap then
                        -- Partial: some below, some above
                        local belowPortion = cap - currentValue
                        local abovePortion = amount - belowPortion
                        totalEP = totalEP + belowPortion * weight
                                          + abovePortion * weight * mult
                    else
                        -- Fully below soft cap
                        totalEP = totalEP + amount * weight
                    end
                else
                    -- No soft cap for this stat
                    totalEP = totalEP + amount * weight
                end
            else
                -- Hit/Exp with no cap configured — full value
                totalEP = totalEP + amount * weight
            end
        end
    end

    return totalEP
end
```

### 3.6 `SimulateAndResolve` — forward-simulation with convergence

```lua
local MAX_SIM_ITERATIONS = 3

local function SimulateAndResolve(candidatePool, weights, capCtx)
    if not candidatePool or #candidatePool == 0 then return nil end

    local function ScoreAll(statDeltas)
        local best = nil
        local bestEP = -math.huge
        for _, gem in ipairs(candidatePool) do
            local ep = ScoreGem(gem, weights, capCtx, statDeltas)
            if ep > bestEP then
                bestEP = ep
                best = gem
            end
        end
        if best then
            best = ShallowCopy(best)  -- avoid mutating pool
            best.computedEP = bestEP
        end
        return best
    end

    -- Iteration 0: Score at current stats (no deltas)
    local winner = ScoreAll(nil)
    if not winner or winner.computedEP <= 0 then return nil end

    -- Forward-simulation iterations
    local prevWinnerID = winner.id
    for iter = 1, MAX_SIM_ITERATIONS do
        -- Build stat deltas as if this gem were socketed
        local deltas = {}
        for stat, amount in pairs(winner.stats) do
            deltas[stat] = amount
        end

        local newWinner = ScoreAll(deltas)
        if not newWinner or newWinner.computedEP <= 0 then
            return winner  -- previous winner is best we can do
        end

        if newWinner.id == winner.id then
            -- Converged: the gem still wins after simulating itself
            winner.computedEP = newWinner.computedEP
            return winner
        end

        -- Winner changed — try the new winner next iteration
        winner = newWinner
        if winner.id == prevWinnerID then
            -- Oscillation detected (A→B→A): break tie
            break
        end
        prevWinnerID = winner.id
    end

    -- If we exit the loop without convergence, do a final conservative
    -- tiebreak: score all candidates with their own stats as deltas,
    -- pick the one whose self-simulated EP is highest.
    local stableWinner = nil
    local stableEP = -math.huge
    for _, gem in ipairs(candidatePool) do
        local selfDeltas = {}
        for stat, amount in pairs(gem.stats) do
            selfDeltas[stat] = amount
        end
        local ep = ScoreGem(gem, weights, capCtx, selfDeltas)
        if ep > stableEP then
            stableEP = ep
            stableWinner = gem
        end
    end
    if stableWinner then
        stableWinner = ShallowCopy(stableWinner)
        stableWinner.computedEP = stableEP
    end
    return stableWinner
end
```

---

## 4. Candidate Gem Data Structures

### 4.1 Location

New local tables in `wotlk-pawn.core.lua`, placed after the existing `gemData` table.

### 4.2 Structure

```lua
-- Each entry: { id, name, stats, ep_stat, ep_amount }
-- ep_stat/ep_amount are the "primary" stat for display labeling
-- stats is the full stat table (same format as gemData entries)

local bisGemCandidates = {
    { id = 40111, name = { enUS = "Bold Cardinal Ruby",      deDE = "Kühner Kardinalrubin" },
      stats = { ITEM_MOD_STR_SHORT = 20 },
      ep_stat = "ITEM_MOD_STR_SHORT", ep_amount = 20 },

    { id = 40112, name = { enUS = "Delicate Cardinal Ruby",  deDE = "Geschliffener Kardinalrubin" },
      stats = { ITEM_MOD_AGILITY_SHORT = 20 },
      ep_stat = "ITEM_MOD_AGILITY_SHORT", ep_amount = 20 },

    { id = 40113, name = { enUS = "Runed Cardinal Ruby",     deDE = "Runenverzierter Kardinalrubin" },
      stats = { ITEM_MOD_SPELL_POWER_SHORT = 23 },
      ep_stat = "ITEM_MOD_SPELL_POWER_SHORT", ep_amount = 23 },

    { id = 40114, name = { enUS = "Bright Cardinal Ruby",    deDE = "Glänzender Kardinalrubin" },
      stats = { ITEM_MOD_ATTACK_POWER_SHORT = 40 },
      ep_stat = "ITEM_MOD_ATTACK_POWER_SHORT", ep_amount = 40 },

    { id = 40117, name = { enUS = "Fractured Cardinal Ruby", deDE = "Frakturierter Kardinalrubin" },
      stats = { ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 20 },
      ep_stat = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", ep_amount = 20 },

    { id = 40124, name = { enUS = "Smooth King's Amber",     deDE = "Glatter Königsamber" },
      stats = { ITEM_MOD_CRIT_RATING_SHORT = 20 },
      ep_stat = "ITEM_MOD_CRIT_RATING_SHORT", ep_amount = 20 },

    { id = 40125, name = { enUS = "Rigid King's Amber",      deDE = "Starrer Königsamber" },
      stats = { ITEM_MOD_HIT_RATING_SHORT = 20 },
      ep_stat = "ITEM_MOD_HIT_RATING_SHORT", ep_amount = 20 },

    { id = 40128, name = { enUS = "Quick King's Amber",      deDE = "Schneller Königsamber" },
      stats = { ITEM_MOD_HASTE_RATING_SHORT = 20 },
      ep_stat = "ITEM_MOD_HASTE_RATING_SHORT", ep_amount = 20 },

    { id = 40121, name = { enUS = "Solid Majestic Zircon",   deDE = "Gediegener Majestätischer Zirkon" },
      stats = { ITEM_MOD_STAMINA_SHORT = 30 },
      ep_stat = "ITEM_MOD_STAMINA_SHORT", ep_amount = 30 },
}

local budgetGemCandidates = {
    { id = 39996, name = { enUS = "Bold Scarlet Ruby",       deDE = "Kühner Scharlachrubin" },
      stats = { ITEM_MOD_STR_SHORT = 16 },
      ep_stat = "ITEM_MOD_STR_SHORT", ep_amount = 16 },

    { id = 39997, name = { enUS = "Delicate Scarlet Ruby",   deDE = "Geschliffener Scharlachrubin" },
      stats = { ITEM_MOD_AGILITY_SHORT = 16 },
      ep_stat = "ITEM_MOD_AGILITY_SHORT", ep_amount = 16 },

    { id = 39998, name = { enUS = "Runed Scarlet Ruby",      deDE = "Runenverzierter Scharlachrubin" },
      stats = { ITEM_MOD_SPELL_POWER_SHORT = 19 },
      ep_stat = "ITEM_MOD_SPELL_POWER_SHORT", ep_amount = 19 },

    { id = 39999, name = { enUS = "Bright Scarlet Ruby",     deDE = "Glänzender Scharlachrubin" },
      stats = { ITEM_MOD_ATTACK_POWER_SHORT = 32 },
      ep_stat = "ITEM_MOD_ATTACK_POWER_SHORT", ep_amount = 32 },

    { id = 40002, name = { enUS = "Fractured Scarlet Ruby",  deDE = "Frakturierter Scharlachrubin" },
      stats = { ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = 16 },
      ep_stat = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT", ep_amount = 16 },

    { id = 40013, name = { enUS = "Smooth Autumn's Glow",    deDE = "Glatter Herbstglanz" },
      stats = { ITEM_MOD_CRIT_RATING_SHORT = 16 },
      ep_stat = "ITEM_MOD_CRIT_RATING_SHORT", ep_amount = 16 },

    { id = 40015, name = { enUS = "Rigid Autumn's Glow",     deDE = "Starrer Herbstglanz" },
      stats = { ITEM_MOD_HIT_RATING_SHORT = 16 },
      ep_stat = "ITEM_MOD_HIT_RATING_SHORT", ep_amount = 16 },

    { id = 40017, name = { enUS = "Quick Autumn's Glow",     deDE = "Schneller Herbstglanz" },
      stats = { ITEM_MOD_HASTE_RATING_SHORT = 16 },
      ep_stat = "ITEM_MOD_HASTE_RATING_SHORT", ep_amount = 16 },

    { id = 40008, name = { enUS = "Solid Sky Sapphire",      deDE = "Gediegener Himmelsaphir" },
      stats = { ITEM_MOD_STAMINA_SHORT = 24 },
      ep_stat = "ITEM_MOD_STAMINA_SHORT", ep_amount = 24 },
}
```

### 4.3 Why Single-Stat Only?

The BiS/budget gem pools contain only **pure single-stat gems**. Reasoning:
- The recommendation answers "what one gem should I put in every socket?" — the single-stat gem that gives maximum EP per socket.
- Hybrid gems exist for socket-color matching, which is a separate feature (queued: "Per-socket-color gem recommendation with socket bonus evaluation").
- Including hybrids here would clutter the output with dozens of candidates for marginal gains; the socket-bonus feature will handle them properly.

Dragon's Eye gems are excluded because they are JC-only with a 3-gem equip limit — recommending them generically would be wrong for non-JC players.

---

## 5. Forward-Simulation Stability Logic (Detailed)

### 5.1 Why Instability Happens

Consider a Fury Warrior with:
- ArP soft cap at 1400, multiplier 0
- Current ArP: 1388
- Weight: ArP 2.0, Str 1.8

**Without simulation:**  
Fractured Cardinal Ruby (ArP 20): `20 * 2.0 = 40 EP` → wins over Bold (Str 20): `20 * 1.8 = 36 EP`.

**But after socketing:** ArP becomes 1408, which is ≥ 1400 soft cap with multiplier 0. The next socket evaluation scores ArP at 0 EP. Str becomes the winner. But if we recommend Str, ArP stays at 1388 (below cap), and ArP wins again → oscillation.

### 5.2 Resolution via Self-Simulation

The forward-simulation scores each gem **as if it itself were already socketed**. This means:

- Fractured: simulate current ArP + 20 = 1408 ≥ 1400 cap → partial cap applies.  
  `belowCap = 1400 - 1388 = 12 rating at full weight: 12 * 2.0 = 24 EP`  
  `aboveCap = 8 rating at mult 0: 8 * 2.0 * 0 = 0 EP`  
  `Total: 24 EP`

- Bold (Str): simulate: Str has no cap → `20 * 1.8 = 36 EP`

After simulation, Str wins (36 > 24). Re-simulating Str: Str still wins (36 EP, stable). **Convergence in 1 iteration.**

### 5.3 Oscillation Fallback

If after `MAX_SIM_ITERATIONS` the winner keeps changing (theoretically possible with exotic weight/cap configurations), the **self-simulated tiebreak** resolves it: for every candidate, compute EP assuming its own stats are added, and pick the highest. This is guaranteed to be self-consistent — the recommended gem remains the winner even after you socket it.

### 5.4 Performance

- BiS pool: 9 candidates × 1–3 iterations × 1 stat each = 9–27 `ScoreGem` calls.
- Budget pool: same.
- Total: ≤54 trivial arithmetic operations. Negligible even in tooltip-hot-path.

---

## 6. Edge Cases

| Scenario | Behavior |
|---|---|
| **No weights loaded** (spec not detected) | `ResolveGemRecommendation()` returns `nil`. Frontend falls back to static archetype recommendation (existing `GetGemRecommendation`). |
| **All candidates produce ≤ 0 EP** (e.g., Tank spec with 0 weight on everything except Stam, but Stam gem somehow scores 0) | Returns `nil`. Frontend falls back to static. |
| **Player exactly at hard cap** | `room = max(0, cap - current) = 0`. Hit/exp gems score 0. Non-capped gems win. |
| **Player above hard cap** (e.g., hit overcapped from gear swap) | Same as at-cap: hit gems score 0. |
| **Soft cap multiplier = 1** (no reduction) | Behaves as if no soft cap — full weight applied. |
| **Soft cap multiplier = 0** (hard cutoff) | Above-cap portion contributes 0 EP. Partial prorating still values the below-cap portion. |
| **Soft cap on a stat no gem provides** (e.g., Dodge soft cap) | No impact — no candidate gem has Dodge as its stat. |
| **Multiple soft caps active** | Each stat's soft cap is evaluated independently per gem stat. |
| **BiS and Budget produce different winners** | Expected and correct. E.g., BiS might be Str (20×1.8=36) while Budget might be Hit (16×2.5=40) if the player still needs hit. Each pool is resolved independently. |
| **Leveling bracket** | `ResolveGemRecommendation` still functions, but the frontend already gates gem display with a low-level warning. The function can be called at any level. |

---

## 7. Integration with Frontend (`wotlk-pawn.frontend.lua`)

### 7.1 Changes to `AddEPToTooltip`

Replace the current static lookup:

```lua
-- CURRENT (to be replaced):
local recs = addon.GetGemRecommendation and addon.GetGemRecommendation(class, currentSpecName)
```

With:

```lua
-- NEW:
local recs = addon.ResolveGemRecommendation and addon.ResolveGemRecommendation()
if not recs then
    -- Fallback to static archetype recommendation
    recs = addon.GetGemRecommendation and addon.GetGemRecommendation(class, currentSpecName)
end
```

### 7.2 Return Format Compatibility

The new return structure is a superset of the old one:

| Old field | New field | Notes |
|---|---|---|
| `bis.name` | `bis.name` | Same `{enUS=..., deDE=...}` format |
| `bis.ep_stat` | `bis.ep_stat` | Same stat key string |
| `bis.ep_amount` | `bis.ep_amount` | Same raw number |
| *(not present)* | `bis.computedEP` | New: cap-aware EP value |
| *(not present)* | `bis.id` | New: item ID |
| *(not present)* | `bis.stats` | New: full stat table |

Existing frontend code that reads `recs.bis.ep_stat`, `recs.bis.ep_amount`, `recs.bis.name` continues to work unchanged. The `computedEP` field enables the frontend to display the actual effective EP instead of `ep_amount * weight`.

### 7.3 EP Display Update

The current frontend computes display EP as:

```lua
local bisWeight = currentWeights[recs.bis.ep_stat] or 0
local bisEP = recs.bis.ep_amount * bisWeight
```

This should be updated to prefer `computedEP` when available:

```lua
local bisEP = recs.bis.computedEP
    or (recs.bis.ep_amount * (currentWeights[recs.bis.ep_stat] or 0))
```

This gives accurate cap-aware EP in the tooltip while maintaining backward compatibility with the static fallback path.

### 7.4 Non-BiS Gem Detection Update

The existing non-BiS gem check compares socketed gem names against `bisName`. Since the dynamic recommendation can change the BiS gem per player state, this comparison now naturally reflects cap-aware choices. No structural change needed — `addon.GetLocalizedGemName(recs.bis)` will return the dynamically-chosen gem's name.

---

## 8. Existing Code to Preserve

The following existing structures are **kept but deprecated** (used only as fallback):
- `gemRecommendations` table (static archetype → gem mapping)
- `specArchetypeMap` table (class/spec → archetype mapping)  
- `addon.GetGemRecommendation(className, specName)` function

These remain as the fallback path when `ResolveGemRecommendation` returns `nil`.

---

## 9. Helper Utility

A shallow-copy utility is needed to avoid mutating the candidate pool arrays:

```lua
local function ShallowCopyGem(gem)
    return {
        id        = gem.id,
        name      = gem.name,        -- shared ref is fine (read-only)
        stats     = gem.stats,        -- shared ref is fine (read-only)
        ep_stat   = gem.ep_stat,
        ep_amount = gem.ep_amount,
        computedEP = gem.computedEP,
    }
end
```

---

## 10. Summary of File Changes

| File | Change |
|---|---|
| `wotlk-pawn.core.lua` | Add: `bisGemCandidates`, `budgetGemCandidates` tables. Add: `BuildCapContext()`, `ScoreGem()`, `SimulateAndResolve()`, `ShallowCopyGem()` local functions. Add: `addon.ResolveGemRecommendation()` public function. |
| `wotlk-pawn.frontend.lua` | Update `AddEPToTooltip`: call `ResolveGemRecommendation()` first, fall back to `GetGemRecommendation()`. Use `computedEP` when available for display EP. |
| `wotlk-pawn.lua` | No changes. |
| `wotlk-pawn.persistence.lua` | No changes. |
| `src/main/resources/todos` | Update queued item status for this feature. |

---

## 11. Validation Criteria

### PASS criteria:

1. **At hit cap**: Hover an item with empty sockets. Gem recommendation is NOT a hit gem. Rigid King's Amber shows 0 EP or is absent.
2. **Below hit cap (partial)**: Player is 8 hit below cap. Rigid King's Amber shows EP based on 8 hit (not 20).
3. **ArP soft cap**: Player at 1388 ArP with soft cap 1400 (mult 0). Recommendation is NOT Fractured Cardinal Ruby; it's the next-best stat gem. The partial ArP EP (12 × weight) is correctly computed.
4. **No caps active**: Recommendation matches expected weight-based ranking (e.g., highest-weighted stat gem wins).
5. **Forward-simulation convergence**: In scenarios where the naive winner would push past a cap, the system converges in ≤3 iterations and doesn't oscillate.
6. **Fallback**: When spec is undetected, the static archetype recommendation still appears.
7. **Display EP accuracy**: Tooltip shows cap-aware EP value, not naive raw-weight EP.
8. **Budget gem**: Budget pool winner is independently computed (can differ from BiS winner).

### FAIL criteria:

1. Gem recommendation shows a hit gem when player is at/above hit cap.
2. EP value displayed ignores cap/soft-cap reductions.
3. Forward-simulation loops indefinitely or takes >3 iterations.
4. Addon errors (`pcall` safety not maintained in tooltip path).
5. Static fallback broken when `ResolveGemRecommendation` returns `nil`.

---

## 12. Future Work (Out of Scope)

- **Per-socket-color recommendations** (queued separately): evaluate socket bonus vs ignoring colors.
- **Hybrid gem candidates**: only relevant with socket-color awareness.
- **Dragon's Eye / JC-specific recommendations**: requires profession detection.
- **Meta gem recommendations**: different evaluation criteria entirely.

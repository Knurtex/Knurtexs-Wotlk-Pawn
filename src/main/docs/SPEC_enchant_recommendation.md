# Implementation Spec: Per-Slot Enchant Recommendation System

**Date:** 2026-02-27  
**Status:** Draft  
**Module owner:** `src/main/lua/wotlk-pawn.core.lua`  
**Frontend consumer:** `src/main/lua/wotlk-pawn.frontend.lua` → `AddEPToTooltip`  
**Depends on:** Enchant stat data (implemented), Cap-aware EP calculation (implemented)

---

## 1. Problem Statement

The addon merges enchant stats into EP calculations via `GetEnchantStats(link)` and `GetItemStatsWithEnchantAndGems(link)`, but it never tells the user **which enchant to apply**. Users must manually look up enchant stat values and cross-reference with their spec weights — exactly the kind of work the gem recommendation system already automates.

The enchant recommendation system should:
- Score all candidate enchants for an equipment slot using current cap-aware weights
- Show the BiS enchant in the tooltip for each unenchanted item
- Show whether the current enchant is BiS, or show the upgrade delta if it's not
- Support enUS and deDE localization for enchant display names

---

## 2. Design Decisions

### D1: Slot mapping — use equip-location strings, not inventory slot IDs

**Decision:** Map `itemEquipLoc` strings (from `GetItemInfo`) to enchant slot categories via a new `enchantSlotMap` table in `core.lua`. The categories are abstract groupings (e.g., `"Head"`, `"Weapon"`) rather than raw inventory slot IDs.

**Rationale:** The frontend already resolves `itemEquipLoc` from `GetItemInfo`. Using the same strings avoids a second lookup. The enchant slot categories don't map 1:1 to inventory slots — weapon enchants depend on whether the item is a 1H weapon, 2H weapon, or shield, and the `itemEquipLoc` already encodes this distinction. Inventory slot IDs (1–18) are ambiguous: slot 16 can hold a 1H or 2H, and the enchant pool differs.

```lua
local enchantSlotMap = {
    -- Maps itemEquipLoc → enchant slot category key
    ["INVTYPE_HEAD"]            = "Head",
    ["INVTYPE_SHOULDER"]        = "Shoulder",
    ["INVTYPE_CLOAK"]           = "Cloak",
    ["INVTYPE_CHEST"]           = "Chest",
    ["INVTYPE_ROBE"]            = "Chest",
    ["INVTYPE_WRIST"]           = "Wrist",
    ["INVTYPE_HAND"]            = "Hands",
    ["INVTYPE_LEGS"]            = "Legs",
    ["INVTYPE_FEET"]            = "Feet",
    ["INVTYPE_WEAPON"]          = "Weapon",
    ["INVTYPE_WEAPONMAINHAND"]  = "Weapon",
    ["INVTYPE_WEAPONOFFHAND"]   = "Weapon",
    ["INVTYPE_2HWEAPON"]        = "2HWeapon",
    ["INVTYPE_SHIELD"]          = "Shield",
    ["INVTYPE_RANGED"]          = "Ranged",
    ["INVTYPE_RANGEDRIGHT"]     = "Ranged",
    ["INVTYPE_THROWN"]          = "Ranged",
    ["INVTYPE_HOLDABLE"]        = nil,      -- Off-hand frills: no enchants in WotLK
    ["INVTYPE_FINGER"]          = "Ring",
    -- INVTYPE_NECK, INVTYPE_TRINKET, INVTYPE_WAIST, INVTYPE_RELIC: no standard enchants
}
```

**Note on 2H weapons:** `INVTYPE_2HWEAPON` maps to `"2HWeapon"` which contains only 2H-specific enchants (Massacre, Scourgebane). The 1H `"Weapon"` category contains Berserking, Black Magic, etc. This prevents recommending a 1H enchant on a 2H weapon or vice versa. However, 2H weapons can *also* use the 1H weapon enchants (Berserking, Black Magic, Blade Ward, Mongoose). The scored candidate pool for 2H should be the **union** of `"Weapon"` and `"2HWeapon"` pools. See §3.2 for implementation.

**Note on Rings:** Ring enchants require the Enchanting profession. Include them in the pool — the system should show them if they produce EP. A future enhancement could filter by detected profession, but for now simplicity wins: a non-Enchanter sees the recommendation and knows it's Enchanting-only from context.

**Note on off-hand frills/holdables:** Holdable off-hands (e.g., Tome of the Dead) cannot be enchanted in WotLK. `INVTYPE_HOLDABLE` maps to `nil`, so no recommendation is shown.

### D2: Dynamic scoring, not archetype-based

**Decision:** Score all candidate enchants for the slot using current cap-aware weights, identical to `ScoreGemCandidate` logic. No archetype mapping.

**Rationale:** Enchants have more stat variety per slot than gems (multi-stat enchants are the norm), and the "correct" enchant depends heavily on current cap state. A Berserking weapon enchant (AP) might beat Black Magic (SP) for Enhancement Shaman but not Elemental. Dynamic scoring handles this automatically.

### D3: Enchant candidate data structure

Each enchant candidate is stored as:

```lua
{
    enchantID = 3817,
    stats = { ITEM_MOD_ATTACK_POWER_SHORT = 50, ITEM_MOD_CRIT_RATING_SHORT = 20 },
    name = {
        enUS = "Arcanum of Torment",
        deDE = "Arkanum der Qual",
    },
}
```

The `stats` table is identical to the existing `enchantData[id]` format. Rather than duplicating stats, the candidate entries reference stats from `enchantData` at recommendation time, but include `name` for display. This is a design tradeoff:

**Option A:** Candidate table has its own `stats` copy → self-contained, no lookups.  
**Option B:** Candidate table references `enchantData` by ID → avoid duplication, but requires a lookup.

**Chosen: Option A.** Stats are small (2-3 entries per enchant), duplication is trivial (~68 entries), and self-containment makes the scoring loop cleaner. This mirrors the gem candidate pattern.

### D4: No "budget" tier for enchants

Unlike gems (where epic vs rare quality creates a BiS/budget split), enchants don't have a universal quality tiering. Some slots have a clear "lesser" option (e.g., Lesser Inscription vs Greater Inscription for shoulders), but this is inconsistent. The recommendation shows one best enchant per slot. If a user hovers an item with a non-BiS enchant, the delta vs BiS is shown — this effectively communicates the upgrade path without requiring a separate budget line.

If we later want to show a budget option (e.g., BoA shoulder enchants vs exalted-rep ones), it can be added as a second scoring pass. For now, one BiS recommendation per slot is sufficient.

### D5: Profession-locked enchants — include all

Include all enchants in the candidate pool regardless of profession requirements. Ring enchants (Enchanting-only), Fur Lining (Leatherworking), Socket Bracer (Blacksmithing) inscription replacements — all participate in scoring. The highest-EP enchant wins regardless.

**Rationale:** Profession-locked enchants are always BiS for their profession. Excluding them would require profession detection (no reliable API in WotLK 3.3.5a) and would produce wrong recommendations for players who *do* have the profession. Players who see an Enchanting ring enchant recommended and don't have Enchanting can ignore it — the recommendation is still correct *advice*.

**Future:** If profession detection is added, filter the pool to show "BiS (profession)" and "BiS (no profession)" separately.

### D6: Scoring reuses existing `ScoreGemCandidate`-like logic

The existing `ScoreGemCandidate(candidate, weights, playerStats, hitCap, expCap, hitType, softCaps)` handles single-stat candidates. For multi-stat enchants, we need the equivalent of `ScoreGemEntry` from the per-socket gem system:

```lua
local function ScoreEnchantCandidate(enchant, weights, playerStats, hitCap, expCap, hitType, softCaps)
    local total = 0
    for stat, amount in pairs(enchant.stats) do
        local pseudo = { stat = stat, amount = amount }
        total = total + ScoreGemCandidate(pseudo, weights, playerStats, hitCap, expCap, hitType, softCaps)
    end
    return total
end
```

This delegates all cap/soft-cap logic to the proven `ScoreGemCandidate` function. No forward-simulation is needed for enchants — unlike gems (where you might socket many of the same gem), you apply one enchant per slot, so the "would this push me past a cap?" instability doesn't arise.

**Why no forward-simulation?** Gems have global competition: you're choosing one gem type to fill N sockets, so socketing it N times could push past a cap. Enchants are per-slot: one enchant per slot, evaluated independently. The stat contribution is evaluated once, and partial-cap prorating in `ScoreGemCandidate` handles the edge case where the enchant would push past a cap.

---

## 3. Data Structures

### 3.1 Slot-to-Enchants Mapping

New local table in `wotlk-pawn.core.lua`, placed after `enchantData`:

```lua
local slotEnchants = {
    ["Head"] = {
        { enchantID = 3817, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 50, ITEM_MOD_CRIT_RATING_SHORT = 20 },
          name = { enUS = "Arcanum of Torment", deDE = "Arkanum der Qual" } },
        { enchantID = 3818, stats = { ITEM_MOD_STAMINA_SHORT = 37, ITEM_MOD_DEFENSE_RATING_SHORT = 20 },
          name = { enUS = "Arcanum of the Stalwart Protector", deDE = "Arkanum des standhaften Beschützers" } },
        { enchantID = 3819, stats = { ITEM_MOD_SPELL_POWER_SHORT = 30, ITEM_MOD_MANA_REGEN_SHORT = 10 },
          name = { enUS = "Arcanum of Blissful Mending", deDE = "Arkanum der glückseligen Heilung" } },
        { enchantID = 3820, stats = { ITEM_MOD_SPELL_POWER_SHORT = 30, ITEM_MOD_CRIT_RATING_SHORT = 20 },
          name = { enUS = "Arcanum of Burning Mysteries", deDE = "Arkanum der brennenden Mysterien" } },
    },

    ["Shoulder"] = {
        -- Greater Inscriptions (Exalted Sons of Hodir / Aldor / Scryer equivalent)
        { enchantID = 3808, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 40, ITEM_MOD_CRIT_RATING_SHORT = 15 },
          name = { enUS = "Greater Inscription of the Axe", deDE = "Große Inschrift der Axt" } },
        { enchantID = 3809, stats = { ITEM_MOD_SPELL_POWER_SHORT = 24, ITEM_MOD_MANA_REGEN_SHORT = 8 },
          name = { enUS = "Greater Inscription of the Storm", deDE = "Große Inschrift des Sturms" } },
        { enchantID = 3810, stats = { ITEM_MOD_SPELL_POWER_SHORT = 24, ITEM_MOD_CRIT_RATING_SHORT = 15 },
          name = { enUS = "Greater Inscription of the Crag", deDE = "Große Inschrift der Klippe" } },
        { enchantID = 3811, stats = { ITEM_MOD_DODGE_RATING_SHORT = 20, ITEM_MOD_DEFENSE_RATING_SHORT = 15 },
          name = { enUS = "Greater Inscription of the Pinnacle", deDE = "Große Inschrift des Gipfels" } },
        -- Inscription-profession master inscriptions
        { enchantID = 3835, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 120, ITEM_MOD_CRIT_RATING_SHORT = 15 },
          name = { enUS = "Master's Inscription of the Axe", deDE = "Meisterhafte Inschrift der Axt" } },
        { enchantID = 3836, stats = { ITEM_MOD_SPELL_POWER_SHORT = 70, ITEM_MOD_CRIT_RATING_SHORT = 15 },
          name = { enUS = "Master's Inscription of the Storm", deDE = "Meisterhafte Inschrift des Sturms" } },
        { enchantID = 3837, stats = { ITEM_MOD_SPELL_POWER_SHORT = 70, ITEM_MOD_MANA_REGEN_SHORT = 8 },
          name = { enUS = "Master's Inscription of the Crag", deDE = "Meisterhafte Inschrift der Klippe" } },
        { enchantID = 3838, stats = { ITEM_MOD_DODGE_RATING_SHORT = 60, ITEM_MOD_DEFENSE_RATING_SHORT = 15 },
          name = { enUS = "Master's Inscription of the Pinnacle", deDE = "Meisterhafte Inschrift des Gipfels" } },
        -- Lesser Inscriptions (Honored Sons of Hodir)
        { enchantID = 3793, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 30, ITEM_MOD_CRIT_RATING_SHORT = 10 },
          name = { enUS = "Lesser Inscription of the Axe", deDE = "Geringe Inschrift der Axt" } },
        { enchantID = 3794, stats = { ITEM_MOD_SPELL_POWER_SHORT = 18, ITEM_MOD_CRIT_RATING_SHORT = 10 },
          name = { enUS = "Lesser Inscription of the Crag", deDE = "Geringe Inschrift der Klippe" } },
        { enchantID = 3795, stats = { ITEM_MOD_SPELL_POWER_SHORT = 18, ITEM_MOD_MANA_REGEN_SHORT = 5 },
          name = { enUS = "Lesser Inscription of the Storm", deDE = "Geringe Inschrift des Sturms" } },
        -- PvP
        { enchantID = 3852, stats = { ITEM_MOD_STAMINA_SHORT = 30 },
          name = { enUS = "Greater Inscription of the Gladiator", deDE = "Große Inschrift des Gladiators" } },
    },

    ["Cloak"] = {
        { enchantID = 3722, stats = { ITEM_MOD_AGILITY_SHORT = 22 },
          name = { enUS = "Enchant Cloak - Superior Agility", deDE = "Umhang verzaubern - Überlegene Beweglichkeit" } },
        { enchantID = 3243, stats = { ITEM_MOD_HASTE_RATING_SHORT = 23 },
          name = { enUS = "Enchant Cloak - Speed", deDE = "Umhang verzaubern - Geschwindigkeit" } },
        { enchantID = 1099, stats = { ITEM_MOD_DEFENSE_RATING_SHORT = 16 },
          name = { enUS = "Enchant Cloak - Greater Defense", deDE = "Umhang verzaubern - Große Verteidigung" } },
        { enchantID = 3831, stats = { ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_SPIRIT_SHORT = 10 },
          name = { enUS = "Enchant Cloak - Wisdom", deDE = "Umhang verzaubern - Weisheit" } },
    },

    ["Chest"] = {
        { enchantID = 3832, stats = { ITEM_MOD_STR_SHORT = 10, ITEM_MOD_AGILITY_SHORT = 10, ITEM_MOD_STAMINA_SHORT = 10, ITEM_MOD_INTELLECT_SHORT = 10, ITEM_MOD_SPIRIT_SHORT = 10 },
          name = { enUS = "Enchant Chest - Powerful Stats", deDE = "Brustschutz verzaubern - Kraftvolle Werte" } },
        { enchantID = 2381, stats = { ITEM_MOD_STR_SHORT = 6, ITEM_MOD_AGILITY_SHORT = 6, ITEM_MOD_STAMINA_SHORT = 6, ITEM_MOD_INTELLECT_SHORT = 6, ITEM_MOD_SPIRIT_SHORT = 6 },
          name = { enUS = "Enchant Chest - Greater Stats", deDE = "Brustschutz verzaubern - Große Werte" } },
        { enchantID = 1953, stats = { ITEM_MOD_DEFENSE_RATING_SHORT = 22 },
          name = { enUS = "Enchant Chest - Greater Defense", deDE = "Brustschutz verzaubern - Große Verteidigung" } },
    },

    ["Wrist"] = {
        { enchantID = 3850, stats = { ITEM_MOD_SPELL_POWER_SHORT = 30 },
          name = { enUS = "Enchant Bracers - Superior Spellpower", deDE = "Armschienen verzaubern - Überlegene Zaubermacht" } },
        { enchantID = 3845, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 50 },
          name = { enUS = "Enchant Bracers - Greater Assault", deDE = "Armschienen verzaubern - Großer Angriff" } },
        { enchantID = 3757, stats = { ITEM_MOD_STAMINA_SHORT = 40 },
          name = { enUS = "Enchant Bracers - Major Stamina", deDE = "Armschienen verzaubern - Erhebliche Ausdauer" } },
        { enchantID = 2332, stats = { ITEM_MOD_SPELL_POWER_SHORT = 23 },
          name = { enUS = "Enchant Bracers - Spellpower", deDE = "Armschienen verzaubern - Zaubermacht" } },
        { enchantID = 3758, stats = { ITEM_MOD_INTELLECT_SHORT = 16 },
          name = { enUS = "Enchant Bracers - Exceptional Intellect", deDE = "Armschienen verzaubern - Außergewöhnliche Intelligenz" } },
        { enchantID = 3756, stats = { ITEM_MOD_SPIRIT_SHORT = 18 },
          name = { enUS = "Enchant Bracers - Major Spirit", deDE = "Armschienen verzaubern - Erhebliche Willenskraft" } },
        { enchantID = 2661, stats = { ITEM_MOD_STR_SHORT = 12 },
          name = { enUS = "Enchant Bracers - Brawn", deDE = "Armschienen verzaubern - Muskelkraft" } },
        { enchantID = 1600, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 38 },
          name = { enUS = "Enchant Bracers - Assault", deDE = "Armschienen verzaubern - Angriff" } },
        -- Profession-locked (Leatherworking)
        { enchantID = 3231, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 130 },
          name = { enUS = "Fur Lining - Attack Power", deDE = "Pelzfutter - Angriffskraft" } },
        { enchantID = 3234, stats = { ITEM_MOD_SPELL_POWER_SHORT = 76 },
          name = { enUS = "Fur Lining - Spell Power", deDE = "Pelzfutter - Zaubermacht" } },
        { enchantID = 3763, stats = { ITEM_MOD_STAMINA_SHORT = 102 },
          name = { enUS = "Fur Lining - Stamina", deDE = "Pelzfutter - Ausdauer" } },
    },

    ["Hands"] = {
        { enchantID = 3246, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 44 },
          name = { enUS = "Enchant Gloves - Greater Assault", deDE = "Handschuhe verzaubern - Großer Angriff" } },
        { enchantID = 3249, stats = { ITEM_MOD_SPELL_POWER_SHORT = 28 },
          name = { enUS = "Enchant Gloves - Major Spellpower", deDE = "Handschuhe verzaubern - Erhebliche Zaubermacht" } },
        { enchantID = 3253, stats = { ITEM_MOD_AGILITY_SHORT = 20 },
          name = { enUS = "Enchant Gloves - Superior Agility", deDE = "Handschuhe verzaubern - Überlegene Beweglichkeit" } },
        { enchantID = 3222, stats = { ITEM_MOD_HIT_RATING_SHORT = 20 },
          name = { enUS = "Enchant Gloves - Precision", deDE = "Handschuhe verzaubern - Präzision" } },
        { enchantID = 3829, stats = { ITEM_MOD_EXPERTISE_RATING_SHORT = 15 },
          name = { enUS = "Enchant Gloves - Expertise", deDE = "Handschuhe verzaubern - Waffenkunde" } },
    },

    ["Legs"] = {
        -- Leg armor (Leatherworking crafted, tradeable)
        { enchantID = 3822, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 75, ITEM_MOD_CRIT_RATING_SHORT = 22 },
          name = { enUS = "Icescale Leg Armor", deDE = "Eisschuppenbeinrüstung" } },
        { enchantID = 3823, stats = { ITEM_MOD_STAMINA_SHORT = 55, ITEM_MOD_AGILITY_SHORT = 22 },
          name = { enUS = "Frosthide Leg Armor", deDE = "Frostfellbeinrüstung" } },
        { enchantID = 3325, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 55, ITEM_MOD_CRIT_RATING_SHORT = 15 },
          name = { enUS = "Nerubian Leg Armor", deDE = "Nerubische Beinrüstung" } },
        { enchantID = 3326, stats = { ITEM_MOD_STAMINA_SHORT = 40, ITEM_MOD_AGILITY_SHORT = 12 },
          name = { enUS = "Jormungar Leg Armor", deDE = "Jormungarbeinrüstung" } },
        -- Spellthread (Tailoring crafted, tradeable)
        { enchantID = 3719, stats = { ITEM_MOD_SPELL_POWER_SHORT = 50, ITEM_MOD_SPIRIT_SHORT = 20 },
          name = { enUS = "Brilliant Spellthread", deDE = "Glänzendes Zauberfaden" } },
        { enchantID = 3721, stats = { ITEM_MOD_SPELL_POWER_SHORT = 50, ITEM_MOD_STAMINA_SHORT = 30 },
          name = { enUS = "Sapphire Spellthread", deDE = "Saphirzauberfaden" } },
        { enchantID = 3720, stats = { ITEM_MOD_SPELL_POWER_SHORT = 35, ITEM_MOD_SPIRIT_SHORT = 20 },
          name = { enUS = "Shining Spellthread", deDE = "Scheinender Zauberfaden" } },
        { enchantID = 3718, stats = { ITEM_MOD_SPELL_POWER_SHORT = 35, ITEM_MOD_STAMINA_SHORT = 20 },
          name = { enUS = "Azure Spellthread", deDE = "Azurzauberfaden" } },
    },

    ["Feet"] = {
        { enchantID = 3232, stats = { ITEM_MOD_STAMINA_SHORT = 15 },
          name = { enUS = "Enchant Boots - Tuskarr's Vitality", deDE = "Stiefel verzaubern - Vitalität der Tuskarr" } },
        { enchantID = 1075, stats = { ITEM_MOD_AGILITY_SHORT = 12 },
          name = { enUS = "Enchant Boots - Greater Agility", deDE = "Stiefel verzaubern - Große Beweglichkeit" } },
        { enchantID = 3824, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 32 },
          name = { enUS = "Enchant Boots - Greater Assault", deDE = "Stiefel verzaubern - Großer Angriff" } },
        { enchantID = 1147, stats = { ITEM_MOD_STAMINA_SHORT = 22 },
          name = { enUS = "Enchant Boots - Greater Fortitude", deDE = "Stiefel verzaubern - Große Seelenstärke" } },
    },

    ["Weapon"] = {
        { enchantID = 3834, stats = { ITEM_MOD_HIT_RATING_SHORT = 25, ITEM_MOD_CRIT_RATING_SHORT = 25 },
          name = { enUS = "Enchant Weapon - Accuracy", deDE = "Waffe verzaubern - Genauigkeit" } },
        { enchantID = 3830, stats = { ITEM_MOD_SPELL_POWER_SHORT = 63 },
          name = { enUS = "Enchant Weapon - Black Magic", deDE = "Waffe verzaubern - Schwarze Magie" } },
        { enchantID = 3844, stats = { ITEM_MOD_SPIRIT_SHORT = 45 },
          name = { enUS = "Enchant Weapon - Spirit", deDE = "Waffe verzaubern - Willenskraft" } },
        { enchantID = 3225, stats = { ITEM_MOD_AGILITY_SHORT = 26 },
          name = { enUS = "Enchant Weapon - Mongoose", deDE = "Waffe verzaubern - Mungo" } },
        { enchantID = 2673, stats = { ITEM_MOD_SPELL_POWER_SHORT = 40 },
          name = { enUS = "Enchant Weapon - Spellpower", deDE = "Waffe verzaubern - Zaubermacht" } },
    },

    ["2HWeapon"] = {
        { enchantID = 3827, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 110 },
          name = { enUS = "Enchant 2H Weapon - Massacre", deDE = "Zweihandwaffe verzaubern - Massaker" } },
        { enchantID = 3828, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 85 },
          name = { enUS = "Enchant 2H Weapon - Scourgebane", deDE = "Zweihandwaffe verzaubern - Geißelbann" } },
    },

    ["Shield"] = {
        { enchantID = 1952, stats = { ITEM_MOD_DEFENSE_RATING_SHORT = 20 },
          name = { enUS = "Enchant Shield - Defense", deDE = "Schild verzaubern - Verteidigung" } },
        { enchantID = 1071, stats = { ITEM_MOD_INTELLECT_SHORT = 25 },
          name = { enUS = "Enchant Shield - Greater Intellect", deDE = "Schild verzaubern - Große Intelligenz" } },
    },

    ["Ranged"] = {
        { enchantID = 3843, stats = { ITEM_MOD_CRIT_RATING_SHORT = 40 },
          name = { enUS = "Heartseeker Scope", deDE = "Herzsuchervisier" } },
        { enchantID = 3608, stats = { ITEM_MOD_HIT_RATING_SHORT = 40 },
          name = { enUS = "Sun Scope", deDE = "Sonnenvisier" } },
    },

    ["Ring"] = {
        { enchantID = 3839, stats = { ITEM_MOD_ATTACK_POWER_SHORT = 40 },
          name = { enUS = "Enchant Ring - Assault", deDE = "Ring verzaubern - Angriff" } },
        { enchantID = 3840, stats = { ITEM_MOD_SPELL_POWER_SHORT = 23 },
          name = { enUS = "Enchant Ring - Greater Spellpower", deDE = "Ring verzaubern - Große Zaubermacht" } },
        { enchantID = 3791, stats = { ITEM_MOD_STAMINA_SHORT = 30 },
          name = { enUS = "Enchant Ring - Stamina", deDE = "Ring verzaubern - Ausdauer" } },
    },
}
```

### 3.2 2H Weapon Candidate Pool Merging

2H weapons can use both `"2HWeapon"` and `"Weapon"` enchants. The scoring function should merge both pools when the slot category is `"2HWeapon"`:

```lua
local function GetEnchantCandidatesForSlot(slotCategory)
    local candidates = slotEnchants[slotCategory]
    if slotCategory == "2HWeapon" then
        -- 2H weapons can also use 1H weapon enchants
        local weaponCandidates = slotEnchants["Weapon"]
        if weaponCandidates then
            local merged = {}
            if candidates then
                for _, e in ipairs(candidates) do
                    merged[#merged + 1] = e
                end
            end
            for _, e in ipairs(weaponCandidates) do
                merged[#merged + 1] = e
            end
            return merged
        end
    end
    return candidates
end
```

### 3.3 Enchant Name Table

Enchant names are embedded directly in the `slotEnchants` candidate entries (matching the gem recommendation pattern from `gemColorData` and `gemCandidates`). No separate name lookup table is needed.

Localization follows the same `{ enUS = "...", deDE = "..." }` pattern. The localized name is resolved via:

```lua
function addon.GetLocalizedEnchantName(enchant)
    local locale = GetLocale and GetLocale() or "enUS"
    return enchant.name[locale] or enchant.name["enUS"]
end
```

This is structurally identical to `addon.GetLocalizedGemName`.

---

## 4. Algorithm: `addon.ResolveEnchantRecommendation`

### 4.1 Signature

```lua
function addon.ResolveEnchantRecommendation(itemEquipLoc)
```

**Input:** `itemEquipLoc` string from `GetItemInfo`.  
**Output:**

```lua
-- Success:
{
    enchantID  = 3817,
    name       = { enUS = "Arcanum of Torment", deDE = "Arkanum der Qual" },
    stats      = { ITEM_MOD_ATTACK_POWER_SHORT = 50, ITEM_MOD_CRIT_RATING_SHORT = 20 },
    computedEP = 70.0,
}

-- Failure (no candidates for slot, no weights loaded):
nil
```

### 4.2 Pseudocode

```
function addon.ResolveEnchantRecommendation(itemEquipLoc):
    slotCategory = enchantSlotMap[itemEquipLoc]
    if not slotCategory then return nil

    candidates = GetEnchantCandidatesForSlot(slotCategory)
    if not candidates or #candidates == 0 then return nil

    weights = addon.GetCurrentWeights()
    if not weights or not next(weights) then return nil

    -- Build cap context (same as gem recommendation)
    classData = addon.GetClassData()
    hitCap, expCap = addon.GetCurrentCapSettings()
    hitType = classData and classData["HitRatingType"]
    softCaps = addon.GetCurrentSoftCaps()

    playerStats = BuildPlayerStatsSnapshot(weights, hitCap, expCap, hitType, softCaps)

    -- Score all candidates
    bestEnchant = nil
    bestEP = 0
    for each enchant in candidates:
        ep = ScoreEnchantCandidate(enchant, weights, playerStats, hitCap, expCap, hitType, softCaps)
        if ep > bestEP then
            bestEP = ep
            bestEnchant = enchant

    if not bestEnchant then return nil

    return {
        enchantID  = bestEnchant.enchantID,
        name       = bestEnchant.name,
        stats      = bestEnchant.stats,
        computedEP = bestEP,
    }
```

### 4.3 `ScoreEnchantCandidate`

```lua
local function ScoreEnchantCandidate(enchant, weights, playerStats, hitCap, expCap, hitType, softCaps)
    local total = 0
    for stat, amount in pairs(enchant.stats) do
        local pseudo = { stat = stat, amount = amount }
        total = total + ScoreGemCandidate(pseudo, weights, playerStats, hitCap, expCap, hitType, softCaps)
    end
    return total
end
```

This reuses the existing `ScoreGemCandidate` function, which already handles:
- Hard caps (hit, expertise) with partial prorating
- Soft caps with configurable multiplier
- Zero-weight stats returning 0

### 4.4 `BuildPlayerStatsSnapshot`

Identical to the pattern in `ResolveGemRecommendation`:

```lua
local function BuildPlayerStatsSnapshot(weights, hitCap, expCap, hitType, softCaps)
    local playerStats = {}
    for stat, _ in pairs(weights) do
        playerStats[stat] = addon.GetCurrentPlayerStatValue(stat) or 0
    end
    if hitCap > 0 and hitType then
        playerStats["ITEM_MOD_HIT_RATING_SHORT"] = playerStats["ITEM_MOD_HIT_RATING_SHORT"]
            or (GetCombatRating and GetCombatRating(hitType) or 0)
    end
    if expCap > 0 then
        playerStats["ITEM_MOD_EXPERTISE_RATING_SHORT"] = playerStats["ITEM_MOD_EXPERTISE_RATING_SHORT"]
            or (GetCombatRating and GetCombatRating(CR_EXPERTISE) or 0)
    end
    for stat, _ in pairs(softCaps) do
        if not playerStats[stat] then
            playerStats[stat] = addon.GetCurrentPlayerStatValue(stat) or 0
        end
    end
    return playerStats
end
```

**Note:** This snapshot code is duplicated from `ResolveGemRecommendation`. Refactoring into a shared helper is recommended during implementation to avoid divergence.

---

## 5. Frontend Integration

### 5.1 Detecting the Current Enchant

The item link already encodes the enchant ID in field 2: `item:12345:ENCHANTID:...`. The existing `addon.GetEnchantStats(link)` extracts this. To detect "is this item enchanted?" and "what EP does the current enchant provide?":

```lua
local currentEnchantID = tonumber(link:match("item:%d+:(%d+)"))
local hasEnchant = currentEnchantID and currentEnchantID > 0
local currentEnchantStats = addon.GetEnchantStats(link)
local currentEnchantEP = 0
if currentEnchantStats and currentWeights then
    for stat, amount in pairs(currentEnchantStats) do
        local pseudo = { stat = stat, amount = amount }
        currentEnchantEP = currentEnchantEP + ScoreGemCandidate(pseudo, currentWeights, playerStats, hitCap, expCap, hitType, softCaps)
    end
end
```

However, scoring the current enchant's EP with cap-awareness requires the same `playerStats`, `hitCap`, `expCap`, `hitType`, and `softCaps` context. To avoid rebuilding this context twice (once for the enchant recommendation, once for scoring the current enchant), the `ResolveEnchantRecommendation` function should return the current enchant's score as well, or the frontend should call a separate helper:

**Chosen approach:** Add a second public function `addon.ScoreEnchantByStats(stats)` that scores arbitrary enchant stats using current weights/caps. This is useful for both the current-enchant scoring and potential future use:

```lua
function addon.ScoreEnchantByStats(stats)
    if not stats then return 0 end
    local currentWeights = addon.GetCurrentWeights()
    if not currentWeights or not next(currentWeights) then return 0 end

    local classData = addon.GetClassData()
    local hitCap, expCap = addon.GetCurrentCapSettings()
    local hitType = classData and classData["HitRatingType"]
    local softCaps = addon.GetCurrentSoftCaps and addon.GetCurrentSoftCaps() or {}
    local playerStats = BuildPlayerStatsSnapshot(currentWeights, hitCap, expCap, hitType, softCaps)

    local total = 0
    for stat, amount in pairs(stats) do
        local pseudo = { stat = stat, amount = amount }
        total = total + ScoreGemCandidate(pseudo, currentWeights, playerStats, hitCap, expCap, hitType, softCaps)
    end
    return total
end
```

### 5.2 Tooltip Display Logic

Add an enchant recommendation section in `AddEPToTooltip`, after the gem recommendation section. The display follows three scenarios:

**Scenario 1: No enchant applied, enchant candidates exist for this slot**
```
--- Enchant Recommendation ---
* BiS: Arcanum of Torment (+50 AP, +20 Crit) +70.00 EP if enchanted
```

**Scenario 2: Enchant applied, it IS the BiS enchant**
```
--- Enchant Recommendation ---
* BiS: Arcanum of Torment (+50 AP, +20 Crit) - BiS enchanted
```

**Scenario 3: Enchant applied, it is NOT the BiS enchant**
```
--- Enchant Recommendation ---
* BiS: Arcanum of Torment (+50 AP, +20 Crit) +12.50 EP upgrade
```

### 5.3 Tooltip Integration Code

```lua
-- After gem recommendation section in AddEPToTooltip:

-- Enchant recommendation section
local enchantSlotCategory = addon.GetEnchantSlotCategory and addon.GetEnchantSlotCategory(itemEquipLoc)
if enchantSlotCategory then
    local bracketKey = addon.GetLevelBracketKey()
    local _, _, _, _, minLevel = GetItemInfo(link)
    minLevel = minLevel or 0

    if bracketKey ~= "leveling" and minLevel >= 80 then
        local enchantRec = addon.ResolveEnchantRecommendation(itemEquipLoc)
        if enchantRec then
            local currentEnchantID = tonumber(link:match("item:%d+:(%d+)"))
            local hasEnchant = currentEnchantID and currentEnchantID > 0

            tooltip:AddLine("|cff888888--- " .. L("EnchantRecommendationHeader") .. " ---|r")

            local bisName = addon.GetLocalizedEnchantName(enchantRec)
            local bisEP = enchantRec.computedEP or 0

            -- Build stat summary string
            local statParts = {}
            for stat, amount in pairs(enchantRec.stats) do
                table.insert(statParts, "+" .. amount .. " " .. GetLocalizedStatLabel(stat))
            end
            local statSummary = table.concat(statParts, ", ")

            if hasEnchant and currentEnchantID == enchantRec.enchantID then
                -- Scenario 2: BiS already enchanted
                tooltip:AddLine(string.format(
                    "|cff888888* " .. L("EnchantBiSLabel") .. ": %s (%s) - " .. L("EnchantBiSAlready") .. "|r",
                    bisName, statSummary
                ))
            elseif hasEnchant then
                -- Scenario 3: Non-BiS enchant, show upgrade delta
                local currentEnchantStats = addon.GetEnchantStats(link)
                local currentEnchantEP = addon.ScoreEnchantByStats(currentEnchantStats) or 0
                local deltaEP = bisEP - currentEnchantEP
                if deltaEP > 0.01 then
                    tooltip:AddLine(string.format(
                        "|cff00FF96* " .. L("EnchantBiSLabel") .. ": %s (%s) +%s EP " .. L("EnchantUpgrade") .. "|r",
                        bisName, statSummary, FormatLocalizedNumber(deltaEP, 2)
                    ))
                else
                    -- Current enchant is equal or better than computed BiS (edge case)
                    tooltip:AddLine(string.format(
                        "|cff888888* " .. L("EnchantBiSLabel") .. ": %s (%s) - " .. L("EnchantBiSAlready") .. "|r",
                        bisName, statSummary
                    ))
                end
            else
                -- Scenario 1: No enchant, show full EP
                tooltip:AddLine(string.format(
                    "|cff00FF96* " .. L("EnchantBiSLabel") .. ": %s (%s) +%s EP " .. L("EnchantIfApplied") .. "|r",
                    bisName, statSummary, FormatLocalizedNumber(bisEP, 2)
                ))
            end
        end
    end
end
```

### 5.4 Public Helper for Slot Category

Thin wrapper exposed to the frontend:

```lua
function addon.GetEnchantSlotCategory(itemEquipLoc)
    return enchantSlotMap[itemEquipLoc]
end
```

### 5.5 Localization Strings

Add to `localizedUiText` in `wotlk-pawn.frontend.lua`:

```lua
-- enUS:
EnchantRecommendationHeader = "Enchant Recommendation",
EnchantBiSLabel = "BiS",
EnchantBiSAlready = "BiS enchanted",
EnchantUpgrade = "upgrade",
EnchantIfApplied = "if enchanted",

-- deDE:
EnchantRecommendationHeader = "Verzauberungs-Empfehlung",
EnchantBiSLabel = "BiS",
EnchantBiSAlready = "BiS verzaubert",
EnchantUpgrade = "Aufwertung",
EnchantIfApplied = "wenn verzaubert",
```

---

## 6. Edge Cases

| Scenario | Behavior |
|---|---|
| **No weights loaded** (spec undetected) | `ResolveEnchantRecommendation` returns `nil`. No enchant section shown. |
| **Slot has no enchant candidates** (Neck, Trinket, Waist, Relic) | `enchantSlotMap` returns `nil`. No section shown. |
| **All candidates produce 0 EP** (degenerate weights) | Returns `nil`. No section shown. |
| **Item below level 80** | Frontend gates display with bracket/minLevel check, same as gems. |
| **2H weapon** | Candidate pool merges `"2HWeapon"` + `"Weapon"` entries. E.g., a DK 2H could see Massacre (AP) vs Black Magic (SP) vs Accuracy (Hit+Crit), and the highest-EP wins. |
| **1H weapon in main-hand vs off-hand** | Both `INVTYPE_WEAPON`, `INVTYPE_WEAPONMAINHAND`, and `INVTYPE_WEAPONOFFHAND` map to `"Weapon"` category. Same enchant pool. |
| **Off-hand frill (INVTYPE_HOLDABLE)** | Maps to `nil`. No enchant recommendation. Correct — holdables can't be enchanted in WotLK. |
| **Ring without Enchanting profession** | Shows ring enchant recommendation. Player can ignore if not Enchanter. |
| **Player has an unknown enchant (not in enchantData)** | `GetEnchantStats` returns `nil`, so `currentEnchantEP = 0`. The delta shown might overstate the upgrade. This matches existing behavior for unknown enchants. |
| **Multiple enchant stats, one at cap** | `ScoreGemCandidate` prorates the capped stat to 0 (or partial), while the other stat(s) contribute fully. E.g., Accuracy (Hit 25 + Crit 25) at hit cap: hit portion = 0, crit portion = 25 × crit weight. |
| **Tuskarr's Vitality** | Enchant data only captures the +15 Stamina; the run speed bonus is not modeled in EP. It may lose to +22 Stamina (Fortitude) or +32 AP (Greater Assault) in EP terms. This is correct behavior — the EP system evaluates stats only, and users who value run speed can ignore the recommendation. |
| **Enchant applied but matching the BiS exactly** | `currentEnchantID == enchantRec.enchantID` → shows "BiS enchanted". |
| **Two enchants with identical EP** | First one in the candidate list wins (deterministic). Consider ordering candidates within each slot by "most generally useful" first, but this is cosmetic. |

---

## 7. Summary of File Changes

| File | Change |
|---|---|
| `wotlk-pawn.core.lua` | Add: `enchantSlotMap` table, `slotEnchants` table (all 68 enchants with localized names), `GetEnchantCandidatesForSlot()`, `ScoreEnchantCandidate()`, `addon.ResolveEnchantRecommendation(itemEquipLoc)`, `addon.ScoreEnchantByStats(stats)`, `addon.GetEnchantSlotCategory(itemEquipLoc)`, `addon.GetLocalizedEnchantName(enchant)`. Refactor `BuildPlayerStatsSnapshot()` into shared local helper (currently duplicated in gem code). |
| `wotlk-pawn.frontend.lua` | Add: enchant recommendation tooltip section in `AddEPToTooltip` (after gem section). Add: 5 new `localizedUiText` entries (enUS + deDE) for enchant display strings. |
| `wotlk-pawn.lua` | No changes. |
| `wotlk-pawn.persistence.lua` | No changes. |
| `src/main/resources/todos` | Update status of enchant recommendation TODO from "queued" to "implemented" once done. |

---

## 8. Validation Criteria

### PASS criteria:

1. **Unenchanted head item at level 80**: Hover shows "--- Enchant Recommendation ---" with BiS arcanum and EP value.
2. **Already-BiS enchant**: Item with Arcanum of Torment for a physical DPS spec shows "BiS enchanted" in gray.
3. **Non-BiS enchant**: Item with Arcanum of the Stalwart Protector on a DPS spec shows upgrade delta to Arcanum of Torment.
4. **Hit-capped player, gloves slot**: Precision (Hit 20) should not win. Greater Assault (AP 44) or Major Spellpower (SP 28) should win depending on spec.
5. **2H weapon**: Shows candidates from both 2H and 1H pools. Massacre competes with Berserking/Black Magic/Mongoose.
6. **Shield**: Protection Warrior/Paladin sees Defense enchant recommended.
7. **Ring**: Show ring enchant recommendation (Assault for physical, Spellpower for caster).
8. **Level < 80 item**: No enchant section shown.
9. **Neck/Trinket/Waist/Relic**: No enchant section shown (no candidates exist).
10. **deDE locale**: Enchant names and UI strings display in German.

### FAIL criteria:

1. Enchant recommendation shows a capped stat as BiS (e.g., hit enchant when at hit cap).
2. Tooltip errors or addon crashes on any enchantable slot.
3. 2H weapon shows only 2H-specific enchants, missing 1H options like Mongoose.
4. Enchant recommendation appears on items below level 80 in the leveling bracket.
5. Enchant matching (BiS already enchanted) fails due to wrong ID comparison.

---

## 9. Refactoring Opportunities

### 9.1 Shared `BuildPlayerStatsSnapshot`

The player stats snapshot logic is currently duplicated between `ResolveGemRecommendation` and the proposed `ResolveEnchantRecommendation`. Extract into a shared local helper:

```lua
local function BuildPlayerStatsSnapshot(weights, hitCap, expCap, hitType, softCaps)
    -- ... (same body as §4.4)
end
```

Both gem and enchant recommendation functions call this.

### 9.2 Shared `ScoreMultiStatCandidate`

`ScoreEnchantCandidate` and `ScoreGemEntry` (from per-socket code) do the same thing: iterate stats and sum `ScoreGemCandidate` results. Consolidate:

```lua
local function ScoreMultiStatCandidate(statsTable, weights, playerStats, hitCap, expCap, hitType, softCaps)
    local total = 0
    for stat, amount in pairs(statsTable) do
        total = total + ScoreGemCandidate({ stat = stat, amount = amount }, weights, playerStats, hitCap, expCap, hitType, softCaps)
    end
    return total
end
```

Used by both gem color matching and enchant scoring.

---

## 10. Future Work (Out of Scope)

- **Profession detection**: Filter enchant pool based on player professions. Would allow showing "BiS (Leatherworking)" vs "BiS (no profession)" separately.
- **Proc-based enchant modeling**: Berserking, Mongoose, Black Magic have proc effects beyond static stats. The current system only evaluates the static stat equivalent from `enchantData`. Proc modeling would require DPS-sim-level complexity.
- **Budget enchant tier**: Show a "budget" alternative (e.g., Lesser Inscription instead of Greater Inscription). Requires defining tier boundaries per slot.
- **Enchant cost/availability info**: Show material cost or reputation requirements alongside recommendations.

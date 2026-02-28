local addonName, addon = ...
local class = addon.class

local configPanel = nil
local configRows = {}
local hardCapRows = {}
local softCapModal = nil
local softCapModalRows = {}

local localizedStatLabels = {
    ["enUS"] = {
        ITEM_MOD_INTELLECT_SHORT = "Intellect",
        ITEM_MOD_SPELL_POWER_SHORT = "Spell Power",
        ITEM_MOD_HIT_RATING_SHORT = "Hit Rating",
        ITEM_MOD_CRIT_RATING_SHORT = "Crit Rating",
        ITEM_MOD_HASTE_RATING_SHORT = "Haste Rating",
        ITEM_MOD_STAMINA_SHORT = "Stamina",
        ITEM_MOD_SPIRIT_SHORT = "Spirit",
        ITEM_MOD_STR_SHORT = "Strength",
        ITEM_MOD_ATTACK_POWER_SHORT = "Attack Power",
        ITEM_MOD_DEFENSE_RATING_SHORT = "Defense Rating",
        ITEM_MOD_EXPERTISE_RATING_SHORT = "Expertise Rating",
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Armor Penetration Rating",
        ITEM_MOD_DODGE_RATING_SHORT = "Dodge Rating",
        ITEM_MOD_PARRY_RATING_SHORT = "Parry Rating",
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Spell Damage",
        ITEM_MOD_MANA_REGEN_SHORT = "Mana Regen",
        ITEM_MOD_AGILITY_SHORT = "Agility",
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "Feral Attack Power",
        ITEM_MOD_BLOCK_RATING_SHORT = "Block Rating",
        ITEM_MOD_BLOCK_VALUE_SHORT = "Block Value",
        RES_ARMOR = "Armor"
    },
    ["deDE"] = {
        ITEM_MOD_INTELLECT_SHORT = "Intelligenz",
        ITEM_MOD_SPELL_POWER_SHORT = "Zaubermacht",
        ITEM_MOD_HIT_RATING_SHORT = "Trefferwertung",
        ITEM_MOD_CRIT_RATING_SHORT = "Kritische Trefferwertung",
        ITEM_MOD_HASTE_RATING_SHORT = "Tempowertung",
        ITEM_MOD_STAMINA_SHORT = "Ausdauer",
        ITEM_MOD_SPIRIT_SHORT = "Willenskraft",
        ITEM_MOD_STR_SHORT = "Stärke",
        ITEM_MOD_ATTACK_POWER_SHORT = "Angriffskraft",
        ITEM_MOD_DEFENSE_RATING_SHORT = "Verteidigungswertung",
        ITEM_MOD_EXPERTISE_RATING_SHORT = "Waffenkundewertung",
        ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT = "Rüstungsdurchschlagwertung",
        ITEM_MOD_DODGE_RATING_SHORT = "Ausweichwertung",
        ITEM_MOD_PARRY_RATING_SHORT = "Parierwertung",
        ITEM_MOD_SPELL_DAMAGE_DONE_SHORT = "Zauberschaden",
        ITEM_MOD_MANA_REGEN_SHORT = "Manaregeneration",
        ITEM_MOD_AGILITY_SHORT = "Beweglichkeit",
        ITEM_MOD_FERAL_ATTACK_POWER_SHORT = "Wilde Angriffskraft",
        ITEM_MOD_BLOCK_RATING_SHORT = "Blockwertung",
        ITEM_MOD_BLOCK_VALUE_SHORT = "Blockwert",
        RES_ARMOR = "Rüstung"
    }
}

local localizedUiText = {
    ["enUS"] = {
        AddonTitle = "WOTLK Pawn",
        Subtitle = "Manual EP Weights (current class/spec and level bracket)",
        ResetToDefaults = "Reset to Defaults",
        Unknown = "Unknown",
        ContextFormat = "Class: %s    Spec: %s    Bracket: %s",
        SelectionOverrides = "Selection Overrides",
        ForceSpecialization = "Force specialization",
        ForceWeightBracket = "Force weight bracket",
        AutoDetected = "Auto",
        AutoByLevel = "Auto (by level)",
        LevelingBracket = "Leveling (1-79)",
        EndgameBracket = "Endgame (80)",
        ForcedSuffix = "forced",
        Clear = "Clear",
        OverridesHint = "Overrides only spec/bracket selection. Stat and cap values below stay editable.",
        GeneralVariables = "General Variables",
        HardCaps = "Hard Caps",
        SoftCaps = "Soft Caps",
        CustomValue = "custom value",
        HitCap = "Hit Rating Cap",
        ExpCap = "Expertise Cap",
        HitSoftCap = "Hit Rating Soft Cap",
        ExpSoftCap = "Expertise Soft Cap",
        HitSoftMultiplier = "Hit Soft Cap Multiplier",
        ExpSoftMultiplier = "Expertise Soft Cap Multiplier",
        SoftCapsManageButton = "Manage Soft Caps",
        SoftCapsModalTitle = "Soft Cap Manager",
        SoftCapsStat = "Stat",
        SoftCapsThreshold = "Threshold",
        SoftCapsMultiplier = "Multiplier",
        SoftCapsAdd = "Add",
        SoftCapsUpdate = "Update",
        SoftCapsEdit = "Edit",
        SoftCapsRemove = "Remove",
        SoftCapsClose = "Close",
        SoftCapsAutoThresholdHint = "Threshold can be set manually. Default is your current equipped/player stat value.",
        SoftCapsNoRows = "No generic soft-cap entries yet.",
        SoftCapsSummaryLineFormat = "%s: %s x%s",
        SoftCapsSummaryEmpty = "No active soft caps.",
        TooltipValueInputBody = "Enter a numeric value. Press Enter to save or Escape to cancel.",
        TooltipStatWeightBody = "Changes EP value per 1 point of this stat for the active class/spec/bracket.",
        TooltipHitCapBody = "Items stop gaining EP from hit rating once your total hit rating reaches this cap.",
        TooltipExpCapBody = "Items stop gaining EP from expertise rating once your total expertise reaches this cap.",
        TooltipResetBody = "Clears current spec overrides (weights/caps and forced selection overrides) and restores defaults.",
        TooltipForceSpecToggleBody = "Enable to force a specialization instead of talent auto-detection.",
        TooltipForceSpecDropdownBody = "Select which specialization should be forced when override is enabled.",
        TooltipForceBracketToggleBody = "Enable to force leveling/endgame bracket instead of automatic level-based selection.",
        TooltipForceBracketDropdownBody = "Select which weight bracket should be forced when override is enabled.",
        TooltipSoftCapsManageBody = "Open the soft-cap manager to add, edit, or remove per-stat soft-cap rules.",
        TooltipSoftCapStatDropdownBody = "Select the stat for which the soft-cap rule should apply.",
        TooltipSoftCapThresholdBody = "The soft-cap starts at this stat value. Values above this use the soft-cap multiplier.",
        TooltipSoftCapMultiplierBody = "Multiplier applied to this stat after reaching the soft-cap threshold.",
        TooltipSoftCapActionAddBody = "Add a new soft-cap rule using selected stat, threshold, and multiplier.",
        TooltipSoftCapActionUpdateBody = "Update the currently edited soft-cap rule with the entered values.",
        TooltipSoftCapEditBody = "Load this row into the editor for changes.",
        TooltipSoftCapRemoveBody = "Remove this soft-cap rule.",
        TooltipSoftCapCloseBody = "Close the soft-cap manager window.",
        GemRecommendationHeader = "Gem Recommendation",
        GemBiSLabel = "BiS",
        GemBudgetLabel = "Budget",
        GemWarningLowLevel = "Not recommended to gem before level 80",
        GemWarningNonBiS = "Non-BiS gem detected",
        GemIfSocketed = "if socketed",
        GemUpgrade = "upgrade",
        GemBiSAlready = "BiS socketed",
        GemSocketColor_r = "Red",
        GemSocketColor_y = "Yellow",
        GemSocketColor_b = "Blue",
        GemSocketBonus = "Socket Bonus",
        GemMatchColors = "Match colors",
        GemIgnoreColors = "Ignore colors",
        EnchantRecommendationHeader = "Enchant Recommendation",
        EnchantBiSLabel = "BiS",
        EnchantBiSAlready = "BiS enchanted",
        EnchantUpgrade = "upgrade",
        EnchantIfApplied = "if applied",
        ProjectedEPHeader = "Projected EP",
        ProjectedEPFormat = "with recommended gems/enchant"
    },
    ["deDE"] = {
        AddonTitle = "WOTLK Pawn",
        Subtitle = "Manuelle EP-Gewichte (aktuelle Klasse/Spezialisierung und Level-Bereich)",
        ResetToDefaults = "Zurücksetzen",
        Unknown = "Unbekannt",
        ContextFormat = "Klasse: %s    Spezialisierung: %s    Bereich: %s",
        SelectionOverrides = "Auswahl-Überschreibungen",
        ForceSpecialization = "Spezialisierung erzwingen",
        ForceWeightBracket = "Gewichtungsbereich erzwingen",
        AutoDetected = "Auto",
        AutoByLevel = "Auto (nach Stufe)",
        LevelingBracket = "Levelbereich (1-79)",
        EndgameBracket = "Endgame (80)",
        ForcedSuffix = "erzwungen",
        Clear = "Zurück",
        OverridesHint = "Überschreibt nur Spezialisierung/Bereich. Werte und Caps unten bleiben bearbeitbar.",
        GeneralVariables = "Allgemeine Variablen",
        HardCaps = "Hard Caps",
        SoftCaps = "Soft Caps",
        CustomValue = "eigener Wert",
        HitCap = "Trefferwertung Cap",
        ExpCap = "Waffenkunde Cap",
        HitSoftCap = "Trefferwertung Soft Cap",
        ExpSoftCap = "Waffenkunde Soft Cap",
        HitSoftMultiplier = "Treffer Soft-Cap Multiplikator",
        ExpSoftMultiplier = "Waffenkunde Soft-Cap Multiplikator",
        SoftCapsManageButton = "Manage Soft Caps",
        SoftCapsModalTitle = "Soft Cap Manager",
        SoftCapsStat = "Wert",
        SoftCapsThreshold = "Schwelle",
        SoftCapsMultiplier = "Multiplikator",
        SoftCapsAdd = "Hinzufügen",
        SoftCapsUpdate = "Aktualisieren",
        SoftCapsEdit = "Bearbeiten",
        SoftCapsRemove = "Entfernen",
        SoftCapsClose = "Schließen",
        SoftCapsAutoThresholdHint = "Die Schwelle kann manuell gesetzt werden. Standard ist dein aktueller ausgerüsteter/Spielerwert.",
        SoftCapsNoRows = "Noch keine generischen Soft-Cap-Einträge.",
        SoftCapsSummaryLineFormat = "%s: %s x%s",
        SoftCapsSummaryEmpty = "Keine aktiven Soft Caps.",
        TooltipValueInputBody = "Gib einen numerischen Wert ein. Enter speichert, Escape verwirft.",
        TooltipStatWeightBody = "Ändert den EP-Wert pro 1 Punkt dieses Stats für die aktive Klasse/Spezialisierung/Bereich.",
        TooltipHitCapBody = "Items erhalten keinen EP-Gewinn mehr aus Trefferwertung, sobald dein Gesamtwert dieses Cap erreicht.",
        TooltipExpCapBody = "Items erhalten keinen EP-Gewinn mehr aus Waffenkunde, sobald dein Gesamtwert dieses Cap erreicht.",
        TooltipResetBody = "Löscht Überschreibungen der aktuellen Spezialisierung (Werte/Caps und erzwungene Auswahl) und stellt Standardwerte wieder her.",
        TooltipForceSpecToggleBody = "Aktivieren, um eine Spezialisierung zu erzwingen statt Talent-Autoerkennung.",
        TooltipForceSpecDropdownBody = "Wähle die Spezialisierung, die bei aktiver Überschreibung erzwungen wird.",
        TooltipForceBracketToggleBody = "Aktivieren, um den Bereich zu erzwingen statt automatischer Auswahl nach Stufe.",
        TooltipForceBracketDropdownBody = "Wähle den Bereich, der bei aktiver Überschreibung erzwungen wird.",
        TooltipSoftCapsManageBody = "Öffnet den Soft-Cap-Manager zum Hinzufügen, Bearbeiten oder Entfernen von Soft-Cap-Regeln.",
        TooltipSoftCapStatDropdownBody = "Wähle den Stat, für den die Soft-Cap-Regel gelten soll.",
        TooltipSoftCapThresholdBody = "Ab diesem Stat-Wert startet der Soft-Cap. Werte darüber nutzen den Soft-Cap-Multiplikator.",
        TooltipSoftCapMultiplierBody = "Multiplikator für diesen Stat nach Erreichen der Soft-Cap-Schwelle.",
        TooltipSoftCapActionAddBody = "Fügt eine neue Soft-Cap-Regel mit gewähltem Stat, Schwelle und Multiplikator hinzu.",
        TooltipSoftCapActionUpdateBody = "Aktualisiert die aktuell bearbeitete Soft-Cap-Regel mit den eingegebenen Werten.",
        TooltipSoftCapEditBody = "Lädt diese Zeile in den Editor zur Bearbeitung.",
        TooltipSoftCapRemoveBody = "Entfernt diese Soft-Cap-Regel.",
        TooltipSoftCapCloseBody = "Schließt das Soft-Cap-Manager-Fenster.",
        GemRecommendationHeader = "Edelstein-Empfehlung",
        GemBiSLabel = "BiS",
        GemBudgetLabel = "Budget",
        GemWarningLowLevel = "Edelsteine vor Stufe 80 nicht empfohlen",
        GemWarningNonBiS = "Nicht-BiS-Edelstein erkannt",
        GemIfSocketed = "wenn gesockelt",
        GemUpgrade = "Aufwertung",
        GemBiSAlready = "BiS gesockelt",
        GemSocketColor_r = "Rot",
        GemSocketColor_y = "Gelb",
        GemSocketColor_b = "Blau",
        GemSocketBonus = "Sockelbonus",
        GemMatchColors = "Farben anpassen",
        GemIgnoreColors = "Farben ignorieren",
        EnchantRecommendationHeader = "Verzauberungs-Empfehlung",
        EnchantBiSLabel = "BiS",
        EnchantBiSAlready = "BiS verzaubert",
        EnchantUpgrade = "Aufwertung",
        EnchantIfApplied = "wenn angewandt",
        ProjectedEPHeader = "Voraussichtliche EP",
        ProjectedEPFormat = "mit empfohlenen Edelsteinen/Verzauberung"
    }
}

local function L(key)
    local locale = GetLocale and GetLocale() or "enUS"
    local localeMap = localizedUiText[locale] or localizedUiText["enUS"]
    return localeMap[key] or key
end

local socketBonusStatMap = {
    -- enUS
    ["Strength"] = "ITEM_MOD_STR_SHORT",
    ["Agility"] = "ITEM_MOD_AGILITY_SHORT",
    ["Stamina"] = "ITEM_MOD_STAMINA_SHORT",
    ["Intellect"] = "ITEM_MOD_INTELLECT_SHORT",
    ["Spirit"] = "ITEM_MOD_SPIRIT_SHORT",
    ["Spell Power"] = "ITEM_MOD_SPELL_POWER_SHORT",
    ["Attack Power"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["Hit Rating"] = "ITEM_MOD_HIT_RATING_SHORT",
    ["Critical Strike Rating"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Crit Rating"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Haste Rating"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["Expertise Rating"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["Armor Penetration Rating"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["Dodge Rating"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["Parry Rating"] = "ITEM_MOD_PARRY_RATING_SHORT",
    ["Defense Rating"] = "ITEM_MOD_DEFENSE_RATING_SHORT",
    ["Block Rating"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["Block Value"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    ["Resilience Rating"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["Mana per 5 sec."] = "ITEM_MOD_MANA_REGEN_SHORT",
    ["Mana per 5 Sec."] = "ITEM_MOD_MANA_REGEN_SHORT",
    ["mana per 5 sec."] = "ITEM_MOD_MANA_REGEN_SHORT",
    -- deDE
    ["Stärke"] = "ITEM_MOD_STR_SHORT",
    ["Beweglichkeit"] = "ITEM_MOD_AGILITY_SHORT",
    ["Ausdauer"] = "ITEM_MOD_STAMINA_SHORT",
    ["Intelligenz"] = "ITEM_MOD_INTELLECT_SHORT",
    ["Willenskraft"] = "ITEM_MOD_SPIRIT_SHORT",
    ["Zaubermacht"] = "ITEM_MOD_SPELL_POWER_SHORT",
    ["Angriffskraft"] = "ITEM_MOD_ATTACK_POWER_SHORT",
    ["Trefferwertung"] = "ITEM_MOD_HIT_RATING_SHORT",
    ["Kritische Trefferwertung"] = "ITEM_MOD_CRIT_RATING_SHORT",
    ["Tempowertung"] = "ITEM_MOD_HASTE_RATING_SHORT",
    ["Waffenkundewertung"] = "ITEM_MOD_EXPERTISE_RATING_SHORT",
    ["Rüstungsdurchschlagwertung"] = "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
    ["Ausweichwertung"] = "ITEM_MOD_DODGE_RATING_SHORT",
    ["Parierwertung"] = "ITEM_MOD_PARRY_RATING_SHORT",
    ["Verteidigungswertung"] = "ITEM_MOD_DEFENSE_RATING_SHORT",
    ["Blockwertung"] = "ITEM_MOD_BLOCK_RATING_SHORT",
    ["Blockwert"] = "ITEM_MOD_BLOCK_VALUE_SHORT",
    ["Abhärtungswertung"] = "ITEM_MOD_RESILIENCE_RATING_SHORT",
    ["Mana alle 5 Sek."] = "ITEM_MOD_MANA_REGEN_SHORT",
    ["Mana pro 5 Sek."] = "ITEM_MOD_MANA_REGEN_SHORT",
}

local function ParseSocketBonus(text)
    if not text then return nil, 0 end
    -- enUS: "Socket Bonus: +6 Strength"
    -- deDE: "Sockelbonus: +6 Stärke"
    local amount, statName = text:match("Socket Bonus: %+(%d+) (.+)")
    if not amount then
        amount, statName = text:match("Sockelbonus: %+(%d+) (.+)")
    end
    if not amount or not statName then return nil, 0 end
    statName = statName:gsub("|r$", ""):gsub("%s+$", "")
    local statKey = socketBonusStatMap[statName]
    return statKey, tonumber(amount) or 0
end

local function GetLocalizedStatLabel(statName)
    local locale = GetLocale and GetLocale() or "enUS"
    local localeMap = localizedStatLabels[locale] or localizedStatLabels["enUS"]
    if localeMap and localeMap[statName] then
        return localeMap[statName]
    end
    if _G[statName] and type(_G[statName]) == "string" and _G[statName] ~= "" then
        return _G[statName]
    end
    return statName
end




local function ResolveTooltipValue(value)
    if type(value) == "function" then
        return value()
    end
    return value
end

local function AttachTooltip(control, titleValue, bodyValue)
    if not control then return end

    control:SetScript("OnEnter", function(self)
        if not GameTooltip then return end

        local title = ResolveTooltipValue(titleValue)
        local body = ResolveTooltipValue(bodyValue)

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title and title ~= "" then
            GameTooltip:SetText(title, 1, 0.82, 0, 1)
        end
        if body and body ~= "" then
            GameTooltip:AddLine(body, 0.95, 0.95, 0.95, 1)
        end
        GameTooltip:Show()
    end)

    control:SetScript("OnLeave", function()
        if GameTooltip then
            GameTooltip:Hide()
        end
    end)
end

local function GetDecimalSeparator()
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "deDE" then
        return ","
    end
    return "."
end

local function GetMaxDecimalsFromFormat(formatString)
    local decimals = string.match(tostring(formatString or ""), "%%%.(%d+)f")
    return tonumber(decimals) or 0
end

local function ParseNumericInput(text)
    local value = tostring(text or "")
    value = value:gsub(",", ".")
    if value == "" or value == "-" or value == "." or value == "-." then
        return nil
    end
    return tonumber(value)
end

local function FormatLocalizedNumber(value, maxDecimals)
    local numericValue = tonumber(value) or 0
    local decimals = tonumber(maxDecimals) or 0
    if decimals < 0 then
        decimals = 0
    end

    local text = string.format("%." .. decimals .. "f", numericValue)
    if decimals > 0 then
        text = text:gsub("(%..-)0+$", "%1")
        text = text:gsub("%.$", "")
    end

    if GetDecimalSeparator() == "," then
        text = text:gsub("%.", ",")
    end

    return text
end

local function SanitizeNumericInput(text)
    local value = tostring(text or "")
    if value == "" then return "" end

    local decimalSeparator = GetDecimalSeparator()
    if decimalSeparator == "," then
        value = value:gsub("%.", ",")
    else
        value = value:gsub(",", ".")
    end

    local sign = ""
    if value:sub(1, 1) == "-" then
        sign = "-"
    end

    value = value:gsub("%-", "")

    local hasDot = false
    local cleaned = {}
    for i = 1, #value do
        local c = value:sub(i, i)
        if c:match("%d") then
            table.insert(cleaned, c)
        elseif c == decimalSeparator and not hasDot then
            hasDot = true
            table.insert(cleaned, c)
        end
    end

    return sign .. table.concat(cleaned)
end

local function EnsureNumericRow(rowTable, index, parent)
    local row = rowTable[index]
    if row then return row end

    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)
    row:SetPoint("LEFT", parent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    row.input = CreateFrame("EditBox", nil, row)
    row.input:SetSize(90, 18)
    row.input:SetPoint("RIGHT", -8, 0)
    row.input:SetAutoFocus(false)
    row.input:SetJustifyH("RIGHT")
    row.input:SetFontObject("GameFontHighlightSmall")
    row.input:SetTextInsets(4, 4, 0, 0)
    row.input:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    row.input:SetBackdropColor(0, 0, 0, 0.7)
    row.input:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)

    row.label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.label:SetPoint("LEFT", 0, 0)
    row.label:SetPoint("RIGHT", row.input, "LEFT", -10, 0)
    row.label:SetJustifyH("LEFT")

    local function RevertText(self)
        self:SetText(FormatLocalizedNumber(row.currentValue or 0, row.maxDecimals or 3))
    end

    local function CommitOrRevert(self)
        local value = ParseNumericInput(self:GetText())
        if value and row.onCommit then
            row.onCommit(value)
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
        else
            RevertText(self)
        end
    end

    row.input:SetScript("OnEnterPressed", function(self)
        CommitOrRevert(self)
        self:ClearFocus()
    end)
    row.input:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local current = self:GetText() or ""
        local sanitized = SanitizeNumericInput(current)
        if sanitized ~= current then
            local cursor = self:GetCursorPosition() or #current
            self:SetText(sanitized)
            local newCursor = cursor - (#current - #sanitized)
            if newCursor < 0 then
                newCursor = 0
            end
            self:SetCursorPosition(newCursor)
        end
    end)
    row.input:SetScript("OnEditFocusLost", CommitOrRevert)
    row.input:SetScript("OnEscapePressed", function(self)
        RevertText(self)
        self:ClearFocus()
    end)

    rowTable[index] = row
    return row
end

local function PlaceRow(row, parent, y)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    row:SetPoint("RIGHT", parent, "RIGHT", -16, 0)
end

local function IsDifferentFromDefault(currentValue, defaultValue)
    local current = tonumber(currentValue) or 0
    local baseline = tonumber(defaultValue) or 0
    return math.abs(current - baseline) > 0.0001
end

local function GetStatRowLabel(statName, currentValue, defaultValue)
    local label = GetLocalizedStatLabel(statName)
    if IsDifferentFromDefault(currentValue, defaultValue) then
        return string.format("%s |cffff4040(%s)|r", label, L("CustomValue"))
    end
    return label
end

local AUTO_SPEC_VALUE = "__auto_spec__"
local AUTO_BRACKET_VALUE = "__auto_bracket__"
local SECTION_HEADER_TOP_GAP = 8

local function GetNaturalLevelBracketKey()
    return UnitLevel("player") < 80 and "leveling" or "endgame"
end

local function GetBracketLabel(bracketKey)
    if bracketKey == "leveling" then
        return L("LevelingBracket")
    end
    return L("EndgameBracket")
end

local function GetLocalizedClassName(classToken)
    if not classToken or classToken == "" then
        return L("Unknown")
    end

    if LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classToken] then
        return LOCALIZED_CLASS_NAMES_MALE[classToken]
    end
    if LOCALIZED_CLASS_NAMES_FEMALE and LOCALIZED_CLASS_NAMES_FEMALE[classToken] then
        return LOCALIZED_CLASS_NAMES_FEMALE[classToken]
    end

    return classToken
end

local function RefreshSelectionOverrideControls()
    if not configPanel then return end
    if not configPanel.forceSpecCheck or not configPanel.forceSpecDropdown then return end

    local forcedSpec = addon.GetForcedSpecOverride and addon.GetForcedSpecOverride() or nil
    local forcedBracket = addon.GetForcedBracketOverride and addon.GetForcedBracketOverride() or nil

    local specIsForced = forcedSpec and forcedSpec ~= ""
    local bracketIsForced = forcedBracket and forcedBracket ~= ""

    configPanel.forceSpecCheck:SetChecked(specIsForced and true or false)
    configPanel.forceBracketCheck:SetChecked(bracketIsForced and true or false)

    UIDropDownMenu_SetSelectedValue(configPanel.forceSpecDropdown, specIsForced and forcedSpec or AUTO_SPEC_VALUE)
    UIDropDownMenu_SetText(configPanel.forceSpecDropdown, specIsForced and forcedSpec or L("AutoDetected"))
    UIDropDownMenu_SetSelectedValue(configPanel.forceBracketDropdown, bracketIsForced and forcedBracket or AUTO_BRACKET_VALUE)
    UIDropDownMenu_SetText(configPanel.forceBracketDropdown, bracketIsForced and GetBracketLabel(forcedBracket) or L("AutoByLevel"))

    if specIsForced then
        UIDropDownMenu_EnableDropDown(configPanel.forceSpecDropdown)
    else
        UIDropDownMenu_DisableDropDown(configPanel.forceSpecDropdown)
    end

    if bracketIsForced then
        UIDropDownMenu_EnableDropDown(configPanel.forceBracketDropdown)
    else
        UIDropDownMenu_DisableDropDown(configPanel.forceBracketDropdown)
    end
end

local function SetupRow(row, labelText, value, valueFormat, onCommit)
    row.label:SetText(labelText)
    row.currentValue = value or 0
    row.valueFormat = valueFormat or "%.3f"
    row.maxDecimals = GetMaxDecimalsFromFormat(row.valueFormat)
    row.onCommit = onCommit
    row.input:SetText(FormatLocalizedNumber(row.currentValue, row.maxDecimals))
    AttachTooltip(row.input,
        function()
            if row.statName then
                return GetLocalizedStatLabel(row.statName)
            end
            if row.capKey == "HitCap" then
                return L("HitCap")
            end
            if row.capKey == "ExpCap" then
                return L("ExpCap")
            end
            return row.label and row.label:GetText() or ""
        end,
        function()
            if row.statName then
                return L("TooltipStatWeightBody")
            end
            if row.capKey == "HitCap" then
                return L("TooltipHitCapBody")
            end
            if row.capKey == "ExpCap" then
                return L("TooltipExpCapBody")
            end
            return L("TooltipValueInputBody")
        end
    )
    row:Show()
end

local function IsManagedSoftCapStat(statKey)
    return statKey ~= "ITEM_MOD_HIT_RATING_SHORT" and statKey ~= "ITEM_MOD_EXPERTISE_RATING_SHORT"
end

local function GetManagedSoftCapStatOptions()
    local options = {}
    local seen = {}

    local currentWeights = addon.GetCurrentWeights() or {}
    for statKey in pairs(currentWeights) do
        if IsManagedSoftCapStat(statKey) then
            options[#options + 1] = statKey
            seen[statKey] = true
        end
    end

    local softCaps = addon.GetCurrentSoftCaps and addon.GetCurrentSoftCaps() or {}
    for statKey in pairs(softCaps) do
        if IsManagedSoftCapStat(statKey) and not seen[statKey] then
            options[#options + 1] = statKey
            seen[statKey] = true
        end
    end

    table.sort(options, function(left, right)
        return tostring(GetLocalizedStatLabel(left)) < tostring(GetLocalizedStatLabel(right))
    end)

    return options
end

local function GetActiveSoftCapSummaryParts()
    local entries = {}
    local softCaps = addon.GetCurrentSoftCaps and addon.GetCurrentSoftCaps() or {}

    for statKey, data in pairs(softCaps) do
        if type(data) == "table" then
            local cap = tonumber(data.cap) or 0
            if cap > 0 then
                local multiplier = tonumber(data.multiplier) or 1
                if multiplier < 0 then multiplier = 0 end
                entries[#entries + 1] = {
                    label = GetLocalizedStatLabel(statKey),
                    cap = cap,
                    multiplier = multiplier
                }
            end
        end
    end

    local _, _, hitSoftCap, expSoftCap, hitSoftMultiplier, expSoftMultiplier = addon.GetCurrentCapSettings()
    if (tonumber(hitSoftCap) or 0) > 0 then
        entries[#entries + 1] = {
            label = L("HitSoftCap"),
            cap = tonumber(hitSoftCap) or 0,
            multiplier = math.max(0, tonumber(hitSoftMultiplier) or 1)
        }
    end
    if (tonumber(expSoftCap) or 0) > 0 then
        entries[#entries + 1] = {
            label = L("ExpSoftCap"),
            cap = tonumber(expSoftCap) or 0,
            multiplier = math.max(0, tonumber(expSoftMultiplier) or 1)
        }
    end

    table.sort(entries, function(left, right)
        return tostring(left.label) < tostring(right.label)
    end)

    local parts = {}
    for _, entry in ipairs(entries) do
        parts[#parts + 1] = string.format(L("SoftCapsSummaryLineFormat"), entry.label, FormatLocalizedNumber(entry.cap, 0), FormatLocalizedNumber(entry.multiplier, 2))
    end

    return parts
end

local function EnsureSoftCapModalRow(index, parent)
    local row = softCapModalRows[index]
    if row then return row end

    row = CreateFrame("Frame", nil, parent)
    row:SetHeight(22)
    row:SetPoint("LEFT", parent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    row.statText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.statText:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.statText:SetWidth(175)
    row.statText:SetJustifyH("LEFT")

    row.thresholdText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.thresholdText:SetPoint("LEFT", row.statText, "RIGHT", 12, 0)
    row.thresholdText:SetWidth(80)
    row.thresholdText:SetJustifyH("LEFT")

    row.multiplierText = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    row.multiplierText:SetPoint("LEFT", row.thresholdText, "RIGHT", 16, 0)
    row.multiplierText:SetWidth(70)
    row.multiplierText:SetJustifyH("LEFT")

    row.editButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.editButton:SetSize(52, 20)
    row.editButton:SetPoint("LEFT", row.multiplierText, "RIGHT", 14, 0)

    row.removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
    row.removeButton:SetSize(64, 20)
    row.removeButton:SetPoint("LEFT", row.editButton, "RIGHT", 6, 0)

    softCapModalRows[index] = row
    return row
end

local function StyleSoftCapModalInput(input)
    input:SetAutoFocus(false)
    input:SetJustifyH("RIGHT")
    input:SetFontObject("GameFontHighlightSmall")
    input:SetTextInsets(4, 4, 0, 0)
    input:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    input:SetBackdropColor(0, 0, 0, 0.7)
    input:SetBackdropBorderColor(0.55, 0.55, 0.55, 1)
end

local function SetSoftCapModalSelectedStat(statKey)
    if not softCapModal or not softCapModal.statDropdown then return end

    local options = GetManagedSoftCapStatOptions()
    local selected = statKey
    local exists = false
    for _, option in ipairs(options) do
        if option == selected then
            exists = true
            break
        end
    end
    if not exists then
        selected = options[1]
    end

    softCapModal.selectedStatKey = selected
    UIDropDownMenu_SetSelectedValue(softCapModal.statDropdown, selected)
    if selected then
        UIDropDownMenu_SetText(softCapModal.statDropdown, GetLocalizedStatLabel(selected))
    else
        UIDropDownMenu_SetText(softCapModal.statDropdown, L("Unknown"))
    end
end

local function GetSoftCapDefaultThreshold(statKey)
    local threshold = addon.GetCurrentPlayerStatValue and addon.GetCurrentPlayerStatValue(statKey) or 0
    threshold = tonumber(threshold) or 0
    threshold = math.max(1, math.floor(threshold + 0.5))
    return threshold
end

local function RefreshSoftCapModalThresholdInput()
    if not softCapModal or not softCapModal.thresholdInput then return end
    if softCapModal.editingStatKey then return end

    local selectedStat = softCapModal.selectedStatKey
    if not selectedStat then return end

    local threshold = GetSoftCapDefaultThreshold(selectedStat)
    softCapModal.thresholdInput:SetText(FormatLocalizedNumber(threshold, 0))
end

local function ResetSoftCapModalEditor()
    if not softCapModal then return end
    softCapModal.editingStatKey = nil
    if softCapModal.multiplierInput then
        softCapModal.multiplierInput:SetText("")
    end
    if softCapModal.thresholdInput then
        softCapModal.thresholdInput:SetText("")
    end
    if softCapModal.actionButton then
        softCapModal.actionButton:SetText(L("SoftCapsAdd"))
    end
    SetSoftCapModalSelectedStat(softCapModal.selectedStatKey)
    RefreshSoftCapModalThresholdInput()
end

local function RefreshSoftCapModal()
    if not softCapModal then return end

    softCapModal.title:SetText(L("SoftCapsModalTitle"))
    softCapModal.statLabel:SetText(L("SoftCapsStat"))
    softCapModal.thresholdLabel:SetText(L("SoftCapsThreshold"))
    softCapModal.multiplierLabel:SetText(L("SoftCapsMultiplier"))
    softCapModal.thresholdHeader:SetText(L("SoftCapsThreshold"))
    softCapModal.multiplierHeader:SetText(L("SoftCapsMultiplier"))
    softCapModal.statHeader:SetText(L("SoftCapsStat"))
    softCapModal.hintText:SetText(L("SoftCapsAutoThresholdHint"))
    softCapModal.closeButton:SetText(L("SoftCapsClose"))
    if softCapModal.editingStatKey then
        softCapModal.actionButton:SetText(L("SoftCapsUpdate"))
    else
        softCapModal.actionButton:SetText(L("SoftCapsAdd"))
    end

    local options = GetManagedSoftCapStatOptions()
    if not softCapModal.selectedStatKey and options[1] then
        softCapModal.selectedStatKey = options[1]
    end
    SetSoftCapModalSelectedStat(softCapModal.selectedStatKey)
    RefreshSoftCapModalThresholdInput()

    local entries = {}
    local softCaps = addon.GetCurrentSoftCaps and addon.GetCurrentSoftCaps() or {}
    for statKey, data in pairs(softCaps) do
        if IsManagedSoftCapStat(statKey) and type(data) == "table" then
            local cap = type(data.cap) == "number" and data.cap or 0
            local multiplier = type(data.multiplier) == "number" and data.multiplier or 1
            if multiplier < 0 then multiplier = 0 end
            entries[#entries + 1] = {
                statKey = statKey,
                statLabel = GetLocalizedStatLabel(statKey),
                cap = cap,
                multiplier = multiplier
            }
        end
    end
    table.sort(entries, function(left, right)
        return tostring(left.statLabel) < tostring(right.statLabel)
    end)

    local listY = -2
    local rowHeight = 24
    for index, entry in ipairs(entries) do
        local row = EnsureSoftCapModalRow(index, softCapModal.listFrame)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", softCapModal.listFrame, "TOPLEFT", 0, listY)
        row:SetPoint("RIGHT", softCapModal.listFrame, "RIGHT", 0, 0)
        row.statText:SetText(entry.statLabel)
        row.thresholdText:SetText(FormatLocalizedNumber(entry.cap, 0))
        row.multiplierText:SetText(FormatLocalizedNumber(entry.multiplier, 2))
        row.editButton:SetText(L("SoftCapsEdit"))
        row.removeButton:SetText(L("SoftCapsRemove"))
        AttachTooltip(row.editButton, L("SoftCapsEdit"), L("TooltipSoftCapEditBody"))
        AttachTooltip(row.removeButton, L("SoftCapsRemove"), L("TooltipSoftCapRemoveBody"))
        row.editButton:SetScript("OnClick", function()
            softCapModal.editingStatKey = entry.statKey
            softCapModal.selectedStatKey = entry.statKey
            SetSoftCapModalSelectedStat(entry.statKey)
            softCapModal.thresholdInput:SetText(FormatLocalizedNumber(entry.cap, 0))
            softCapModal.multiplierInput:SetText(FormatLocalizedNumber(entry.multiplier, 2))
            softCapModal.actionButton:SetText(L("SoftCapsUpdate"))
        end)
        row.removeButton:SetScript("OnClick", function()
            addon.ClearSoftCapOverride(entry.statKey)
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
            if softCapModal.editingStatKey == entry.statKey then
                ResetSoftCapModalEditor()
            end
            RefreshSoftCapModal()
        end)
        row:Show()
        listY = listY - rowHeight
    end

    for index = #entries + 1, #softCapModalRows do
        softCapModalRows[index]:Hide()
    end

    if #entries == 0 then
        softCapModal.noRowsText:SetText(L("SoftCapsNoRows"))
        softCapModal.noRowsText:Show()
    else
        softCapModal.noRowsText:Hide()
    end
end

local function CreateSoftCapModal()
    if softCapModal then return end

    softCapModal = CreateFrame("Frame", "WOTLKPawnSoftCapsModal", UIParent)
    softCapModal:SetSize(500, 390)
    softCapModal:SetPoint("CENTER")
    softCapModal:SetFrameStrata("DIALOG")
    softCapModal:EnableMouse(true)
    softCapModal:SetMovable(true)
    softCapModal:RegisterForDrag("LeftButton")
    softCapModal:SetScript("OnDragStart", function(self) self:StartMoving() end)
    softCapModal:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    softCapModal:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    softCapModal:SetBackdropColor(0, 0, 0, 1)
    softCapModal.backgroundFill = softCapModal:CreateTexture(nil, "BACKGROUND")
    softCapModal.backgroundFill:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    softCapModal.backgroundFill:SetAllPoints(softCapModal)
    softCapModal.backgroundFill:SetVertexColor(0, 0, 0, 0.92)
    softCapModal:Hide()

    softCapModal.title = softCapModal:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    softCapModal.title:SetPoint("TOPLEFT", 16, -16)

    softCapModal.statLabel = softCapModal:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    softCapModal.statLabel:SetPoint("TOPLEFT", softCapModal, "TOPLEFT", 18, -48)

    softCapModal.statDropdown = CreateFrame("Frame", "WOTLKPawnSoftCapStatDropdown", softCapModal, "UIDropDownMenuTemplate")
    softCapModal.statDropdown:SetPoint("TOPLEFT", softCapModal.statLabel, "BOTTOMLEFT", -14, -2)
    UIDropDownMenu_SetWidth(softCapModal.statDropdown, 140)
    UIDropDownMenu_Initialize(softCapModal.statDropdown, function(_, level)
        if level ~= 1 then return end
        local options = GetManagedSoftCapStatOptions()
        for _, statKey in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = GetLocalizedStatLabel(statKey)
            info.value = statKey
            info.func = function()
                softCapModal.selectedStatKey = statKey
                UIDropDownMenu_SetSelectedValue(softCapModal.statDropdown, statKey)
                UIDropDownMenu_SetText(softCapModal.statDropdown, GetLocalizedStatLabel(statKey))
                RefreshSoftCapModalThresholdInput()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    softCapModal.thresholdLabel = softCapModal:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    softCapModal.thresholdLabel:SetPoint("LEFT", softCapModal.statDropdown, "RIGHT", 12, 22)

    softCapModal.thresholdInput = CreateFrame("EditBox", nil, softCapModal)
    softCapModal.thresholdInput:SetSize(80, 20)
    softCapModal.thresholdInput:SetPoint("TOPLEFT", softCapModal.thresholdLabel, "BOTTOMLEFT", 0, -4)
    StyleSoftCapModalInput(softCapModal.thresholdInput)
    softCapModal.thresholdInput:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local current = self:GetText() or ""
        local sanitized = SanitizeNumericInput(current)
        if sanitized ~= current then
            local cursor = self:GetCursorPosition() or #current
            self:SetText(sanitized)
            local newCursor = cursor - (#current - #sanitized)
            if newCursor < 0 then newCursor = 0 end
            self:SetCursorPosition(newCursor)
        end
    end)

    softCapModal.multiplierLabel = softCapModal:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    softCapModal.multiplierLabel:SetPoint("LEFT", softCapModal.thresholdInput, "RIGHT", 12, 22)

    softCapModal.multiplierInput = CreateFrame("EditBox", nil, softCapModal)
    softCapModal.multiplierInput:SetSize(80, 20)
    softCapModal.multiplierInput:SetPoint("TOPLEFT", softCapModal.multiplierLabel, "BOTTOMLEFT", 0, -4)
    StyleSoftCapModalInput(softCapModal.multiplierInput)
    softCapModal.multiplierInput:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        local current = self:GetText() or ""
        local sanitized = SanitizeNumericInput(current)
        if sanitized ~= current then
            local cursor = self:GetCursorPosition() or #current
            self:SetText(sanitized)
            local newCursor = cursor - (#current - #sanitized)
            if newCursor < 0 then newCursor = 0 end
            self:SetCursorPosition(newCursor)
        end
    end)

    softCapModal.actionButton = CreateFrame("Button", nil, softCapModal, "UIPanelButtonTemplate")
    softCapModal.actionButton:SetSize(100, 22)
    softCapModal.actionButton:SetPoint("TOPRIGHT", softCapModal, "TOPRIGHT", -24, -78)
    softCapModal.multiplierInput:ClearAllPoints()
    softCapModal.multiplierInput:SetPoint("TOPRIGHT", softCapModal.actionButton, "TOPLEFT", -10, 0)
    softCapModal.thresholdInput:ClearAllPoints()
    softCapModal.thresholdInput:SetPoint("TOPRIGHT", softCapModal.multiplierInput, "TOPLEFT", -12, 0)
    softCapModal.thresholdLabel:ClearAllPoints()
    softCapModal.thresholdLabel:SetPoint("BOTTOMLEFT", softCapModal.thresholdInput, "TOPLEFT", 0, 4)
    softCapModal.multiplierLabel:ClearAllPoints()
    softCapModal.multiplierLabel:SetPoint("BOTTOMLEFT", softCapModal.multiplierInput, "TOPLEFT", 0, 4)
    softCapModal.actionButton:SetScript("OnClick", function()
        local statKey = softCapModal.selectedStatKey
        if not statKey or not IsManagedSoftCapStat(statKey) then
            return
        end

        local threshold = ParseNumericInput(softCapModal.thresholdInput:GetText())
        if not threshold then
            return
        end
        threshold = math.max(1, math.floor(threshold + 0.5))

        local multiplier = ParseNumericInput(softCapModal.multiplierInput:GetText())
        if not multiplier then
            return
        end
        if multiplier < 0 then
            multiplier = 0
        end

        addon.SetSoftCapOverride(statKey, threshold, multiplier)
        addon.UpdateActiveWeights()
        addon.RefreshConfigPanel()

        softCapModal.editingStatKey = nil
        softCapModal.thresholdInput:SetText("")
        softCapModal.multiplierInput:SetText("")
        softCapModal.actionButton:SetText(L("SoftCapsAdd"))
        RefreshSoftCapModal()
    end)

    softCapModal.hintText = softCapModal:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    softCapModal.hintText:SetPoint("TOPLEFT", softCapModal.statDropdown, "BOTTOMLEFT", 14, -8)
    softCapModal.hintText:SetWidth(softCapModal:GetWidth() - 42)
    softCapModal.hintText:SetJustifyV("TOP")
    softCapModal.hintText:SetJustifyH("LEFT")

    softCapModal.listFrame = CreateFrame("Frame", nil, softCapModal)
    softCapModal.listFrame:SetPoint("TOPLEFT", softCapModal.hintText, "BOTTOMLEFT", 0, -18)
    softCapModal.listFrame:SetPoint("RIGHT", softCapModal, "RIGHT", -18, 0)
    softCapModal.listFrame:SetHeight(190)

    softCapModal.statHeader = softCapModal.listFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    softCapModal.statHeader:SetPoint("TOPLEFT", softCapModal.listFrame, "TOPLEFT", 8, 16)
    softCapModal.statHeader:SetWidth(175)
    softCapModal.statHeader:SetJustifyH("LEFT")

    softCapModal.thresholdHeader = softCapModal.listFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    softCapModal.thresholdHeader:SetPoint("LEFT", softCapModal.statHeader, "RIGHT", 12, 0)
    softCapModal.thresholdHeader:SetWidth(80)
    softCapModal.thresholdHeader:SetJustifyH("LEFT")

    softCapModal.multiplierHeader = softCapModal.listFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    softCapModal.multiplierHeader:SetPoint("LEFT", softCapModal.thresholdHeader, "RIGHT", 16, 0)
    softCapModal.multiplierHeader:SetWidth(70)
    softCapModal.multiplierHeader:SetJustifyH("LEFT")

    softCapModal.noRowsText = softCapModal.listFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    softCapModal.noRowsText:SetPoint("TOPLEFT", softCapModal.listFrame, "TOPLEFT", 8, -6)
    softCapModal.noRowsText:SetPoint("RIGHT", softCapModal.listFrame, "RIGHT", -8, 0)
    softCapModal.noRowsText:SetJustifyH("LEFT")

    softCapModal.closeButton = CreateFrame("Button", nil, softCapModal, "UIPanelButtonTemplate")
    softCapModal.closeButton:SetSize(100, 22)
    softCapModal.closeButton:SetPoint("BOTTOMRIGHT", -16, 14)
    softCapModal.closeButton:SetScript("OnClick", function()
        softCapModal:Hide()
    end)

    softCapModal:SetScript("OnShow", function()
        RefreshSoftCapModal()
    end)

    AttachTooltip(softCapModal.statDropdown, L("SoftCapsStat"), L("TooltipSoftCapStatDropdownBody"))
    AttachTooltip(softCapModal.thresholdInput, L("SoftCapsThreshold"), L("TooltipSoftCapThresholdBody"))
    AttachTooltip(softCapModal.multiplierInput, L("SoftCapsMultiplier"), L("TooltipSoftCapMultiplierBody"))
    AttachTooltip(softCapModal.actionButton,
        function()
            return softCapModal.editingStatKey and L("SoftCapsUpdate") or L("SoftCapsAdd")
        end,
        function()
            return softCapModal.editingStatKey and L("TooltipSoftCapActionUpdateBody") or L("TooltipSoftCapActionAddBody")
        end
    )
    AttachTooltip(softCapModal.closeButton, L("SoftCapsClose"), L("TooltipSoftCapCloseBody"))
end

local function OpenSoftCapModal()
    if not softCapModal then
        CreateSoftCapModal()
    end

    if softCapModal then
        softCapModal:Show()
        RefreshSoftCapModal()
    end
end

function addon.CommitPendingConfigEdits()
    if not configPanel then return end

    for _, row in ipairs(configRows) do
        if row and row.input and row:IsShown() and row.statName then
            local value = ParseNumericInput(row.input:GetText())
            if value then
                addon.SaveManualOverride(row.statName, value)
            end
        end
    end

    for _, row in ipairs(hardCapRows) do
        if row and row.input and row:IsShown() and row.capKey then
            local value = ParseNumericInput(row.input:GetText())
            if value then
                addon.SaveCapOverride(row.capKey, value)
            end
        end
    end

    addon.UpdateActiveWeights()
end

function addon.RefreshConfigPanel()
    if not configPanel then return end

    addon.UpdateActiveWeights()

    local content = configPanel.contentFrame
    if content and configPanel.scrollFrame and configPanel.scrollFrame:GetWidth() > 0 then
        content:SetWidth(configPanel.scrollFrame:GetWidth() - 24)
    end

    local activeBracket = addon.GetLevelBracketKey()
    local bracketLabel = GetBracketLabel(activeBracket)
    local currentSpecName = addon.GetCurrentSpecName()
    local forcedSpec = addon.GetForcedSpecOverride and addon.GetForcedSpecOverride() or nil
    local forcedBracket = addon.GetForcedBracketOverride and addon.GetForcedBracketOverride() or nil

    local specLabel = currentSpecName ~= "" and currentSpecName or L("Unknown")
    if forcedSpec then
        specLabel = string.format("%s (%s)", specLabel, L("ForcedSuffix"))
    end
    if forcedBracket then
        bracketLabel = string.format("%s (%s)", bracketLabel, L("ForcedSuffix"))
    end

    configPanel.contextText:SetText(string.format(L("ContextFormat"), GetLocalizedClassName(class), specLabel, bracketLabel))

    RefreshSelectionOverrideControls()

    configPanel.generalHeader:SetText(L("GeneralVariables"))
    configPanel.hardCapsHeader:SetText(L("HardCaps"))
    configPanel.softCapsHeader:SetText(L("SoftCaps"))

    local y = -4
    configPanel.selectionOverridesHeader:ClearAllPoints()
    configPanel.selectionOverridesHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 24

    configPanel.selectionOverridesBlock:ClearAllPoints()
    configPanel.selectionOverridesBlock:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    configPanel.selectionOverridesBlock:SetPoint("RIGHT", content, "RIGHT", -8, 0)
    configPanel.selectionOverridesBlock:SetHeight(126)

    configPanel.forceSpecToggleRow:ClearAllPoints()
    configPanel.forceSpecToggleRow:SetPoint("TOPLEFT", configPanel.selectionOverridesBlock, "TOPLEFT", 0, 0)
    configPanel.forceSpecToggleRow:SetPoint("RIGHT", configPanel.selectionOverridesBlock, "RIGHT", 0, 0)
    configPanel.forceSpecToggleRow:SetHeight(30)

    configPanel.forceSpecDropdownRow:ClearAllPoints()
    configPanel.forceSpecDropdownRow:SetPoint("TOPLEFT", configPanel.forceSpecToggleRow, "BOTTOMLEFT", 0, -2)
    configPanel.forceSpecDropdownRow:SetPoint("RIGHT", configPanel.selectionOverridesBlock, "RIGHT", 0, 0)
    configPanel.forceSpecDropdownRow:SetHeight(30)

    configPanel.forceBracketToggleRow:ClearAllPoints()
    configPanel.forceBracketToggleRow:SetPoint("TOPLEFT", configPanel.forceSpecDropdownRow, "BOTTOMLEFT", 0, -2)
    configPanel.forceBracketToggleRow:SetPoint("RIGHT", configPanel.selectionOverridesBlock, "RIGHT", 0, 0)
    configPanel.forceBracketToggleRow:SetHeight(30)

    configPanel.forceBracketDropdownRow:ClearAllPoints()
    configPanel.forceBracketDropdownRow:SetPoint("TOPLEFT", configPanel.forceBracketToggleRow, "BOTTOMLEFT", 0, -2)
    configPanel.forceBracketDropdownRow:SetPoint("RIGHT", configPanel.selectionOverridesBlock, "RIGHT", 0, 0)
    configPanel.forceBracketDropdownRow:SetHeight(30)

    configPanel.forceSpecCheck:ClearAllPoints()
    configPanel.forceSpecCheck:SetPoint("TOPLEFT", configPanel.forceSpecToggleRow, "TOPLEFT", -4, 0)
    configPanel.forceSpecLabel:ClearAllPoints()
    configPanel.forceSpecLabel:SetPoint("LEFT", configPanel.forceSpecCheck, "RIGHT", 4, 1)
    configPanel.forceSpecDropdown:ClearAllPoints()
    configPanel.forceSpecDropdown:SetPoint("LEFT", configPanel.forceSpecDropdownRow, "LEFT", 170, 2)

    configPanel.forceBracketCheck:ClearAllPoints()
    configPanel.forceBracketCheck:SetPoint("TOPLEFT", configPanel.forceBracketToggleRow, "TOPLEFT", -4, 0)
    configPanel.forceBracketLabel:ClearAllPoints()
    configPanel.forceBracketLabel:SetPoint("LEFT", configPanel.forceBracketCheck, "RIGHT", 4, 1)
    configPanel.forceBracketDropdown:ClearAllPoints()
    configPanel.forceBracketDropdown:SetPoint("LEFT", configPanel.forceBracketDropdownRow, "LEFT", 170, 2)

    y = y - 126

    configPanel.overridesHintText:ClearAllPoints()
    configPanel.overridesHintText:SetPoint("TOPLEFT", configPanel.selectionOverridesBlock, "BOTTOMLEFT", 0, -8)
    configPanel.overridesHintText:SetWidth(math.max((content:GetWidth() or 320) - 16, 120))
    configPanel.overridesHintText:SetJustifyH("LEFT")
    local hintHeight = configPanel.overridesHintText:GetStringHeight() or 0
    if hintHeight < 14 then
        hintHeight = 14
    end
    y = y - hintHeight - 12

    y = y - SECTION_HEADER_TOP_GAP
    configPanel.generalHeader:ClearAllPoints()
    configPanel.generalHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 24

    local stats = {}
    local currentWeights = addon.GetCurrentWeights()
    local classData = addon.GetClassData()
    local defaultWeights = classData and classData[currentSpecName] or {}
    for statName in pairs(currentWeights or {}) do
        table.insert(stats, statName)
    end
    table.sort(stats)

    for i, statName in ipairs(stats) do
        local row = EnsureNumericRow(configRows, i, content)
        PlaceRow(row, content, y)
        row.statName = statName
        local currentValue = currentWeights[statName] or 0
        local defaultValue = defaultWeights and defaultWeights[statName] or 0
        SetupRow(row, GetStatRowLabel(statName, currentValue, defaultValue), currentValue, "%.3f", function(value)
            addon.SaveManualOverride(row.statName, value)
        end)
        y = y - 28
    end

    for i = #stats + 1, #configRows do
        configRows[i]:Hide()
    end

    local hitCap, expCap = addon.GetCurrentCapSettings()

    y = y - SECTION_HEADER_TOP_GAP
    configPanel.hardCapsHeader:ClearAllPoints()
    configPanel.hardCapsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 24

    local hardCapConfig = {
        { key = "HitCap", label = L("HitCap"), value = hitCap, format = "%.0f" },
        { key = "ExpCap", label = L("ExpCap"), value = expCap, format = "%.0f" }
    }

    for i, cfg in ipairs(hardCapConfig) do
        local row = EnsureNumericRow(hardCapRows, i, content)
        row.capKey = cfg.key
        PlaceRow(row, content, y)
        SetupRow(row, cfg.label, cfg.value, cfg.format, function(value)
            addon.SaveCapOverride(row.capKey, value)
        end)
        y = y - 28
    end

    y = y - SECTION_HEADER_TOP_GAP
    configPanel.softCapsHeader:ClearAllPoints()
    configPanel.softCapsHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    y = y - 24

    local softCapSummaryParts = GetActiveSoftCapSummaryParts()
    configPanel.softCapsSummaryText:ClearAllPoints()
    configPanel.softCapsSummaryText:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    configPanel.softCapsSummaryText:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    configPanel.softCapsSummaryText:SetJustifyH("LEFT")
    if #softCapSummaryParts > 0 then
        configPanel.softCapsSummaryText:SetText(table.concat(softCapSummaryParts, "   "))
        configPanel.softCapsSummaryText:Show()
        local summaryHeight = configPanel.softCapsSummaryText:GetStringHeight() or 0
        if summaryHeight < 14 then summaryHeight = 14 end
        y = y - summaryHeight - 8
    else
        configPanel.softCapsSummaryText:SetText(L("SoftCapsSummaryEmpty"))
        configPanel.softCapsSummaryText:Show()
        y = y - 22
    end

    configPanel.softCapsManageRow:ClearAllPoints()
    configPanel.softCapsManageRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    configPanel.softCapsManageRow:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    configPanel.softCapsManageRow:SetHeight(24)
    configPanel.softCapsManageButton:SetText(L("SoftCapsManageButton"))
    configPanel.softCapsManageRow:Show()
    y = y - 30

    content:SetHeight(-y + 12)
    if configPanel.scrollFrame then
        configPanel.scrollFrame:UpdateScrollChildRect()
        local maxScroll = configPanel.scrollFrame:GetVerticalScrollRange() or 0
        local current = configPanel.scrollFrame:GetVerticalScroll() or 0
        if current > maxScroll then
            configPanel.scrollFrame:SetVerticalScroll(maxScroll)
            current = maxScroll
        end
        if configPanel.scrollBar then
            configPanel.scrollBar:SetMinMaxValues(0, maxScroll)
            configPanel.scrollBar:SetValue(current)
            if maxScroll > 0 then
                configPanel.scrollBar:Show()
            else
                configPanel.scrollBar:Hide()
            end
        end
    end
end

local function CreateConfigPanel()
    if configPanel then return end

    configPanel = CreateFrame("Frame", "WOTLKPawnConfigPanel")
    configPanel.name = "WOTLK Pawn"
    configPanel:Hide()

    local title = configPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText(L("AddonTitle"))

    local subtitle = configPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText(L("Subtitle"))

    local resetButton = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
    resetButton:SetSize(140, 22)
    resetButton:SetPoint("BOTTOMRIGHT", -16, 16)
    resetButton:SetText(L("ResetToDefaults"))
    resetButton:SetScript("OnClick", function()
        addon.ResetCurrentSpecOverrides()
        addon.ClearSelectionOverrides()
        addon.UpdateActiveWeights()
        addon.RefreshConfigPanel()
    end)
    AttachTooltip(resetButton, L("ResetToDefaults"), L("TooltipResetBody"))
    configPanel.resetButton = resetButton

    configPanel.contextText = configPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    configPanel.contextText:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -10)
    configPanel.contextText:SetText("")

    local scrollFrame = CreateFrame("ScrollFrame", "WOTLKPawnConfigScrollFrame", configPanel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", configPanel.contextText, "BOTTOMLEFT", -2, -8)
    scrollFrame:SetPoint("BOTTOMRIGHT", configPanel, "BOTTOMRIGHT", -30, 42)
    local syncingScroll = false
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll() or 0
        local step = 32
        local maxScroll = self:GetVerticalScrollRange() or 0
        local target = current - (delta * step)
        if target < 0 then
            target = 0
        elseif target > maxScroll then
            target = maxScroll
        end
        self:SetVerticalScroll(target)
    end)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        if configPanel and configPanel.scrollBar and not syncingScroll then
            syncingScroll = true
            configPanel.scrollBar:SetValue(offset)
            syncingScroll = false
        end
    end)
    configPanel.scrollFrame = scrollFrame

    local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
    if scrollBar then
        scrollBar:SetValueStep(16)
        scrollBar:SetMinMaxValues(0, 0)
        scrollBar:SetValue(0)
        scrollBar:SetScript("OnValueChanged", function(self, value)
            if syncingScroll then return end
            syncingScroll = true
            scrollFrame:SetVerticalScroll(value)
            syncingScroll = false
        end)
        configPanel.scrollBar = scrollBar
    end

    local contentFrame = CreateFrame("Frame", nil, scrollFrame)
    contentFrame:SetSize(1, 1)
    contentFrame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, 0)
    scrollFrame:SetScrollChild(contentFrame)
    configPanel.contentFrame = contentFrame

    configPanel.generalHeader = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    configPanel.hardCapsHeader = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    configPanel.softCapsHeader = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    configPanel.softCapsSummaryText = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    configPanel.softCapsManageRow = CreateFrame("Frame", nil, contentFrame)
    configPanel.softCapsManageButton = CreateFrame("Button", nil, configPanel.softCapsManageRow, "UIPanelButtonTemplate")
    configPanel.softCapsManageButton:SetSize(180, 22)
    configPanel.softCapsManageButton:SetPoint("LEFT", configPanel.softCapsManageRow, "LEFT", 0, 0)
    configPanel.softCapsManageButton:SetScript("OnClick", function()
        OpenSoftCapModal()
    end)
    AttachTooltip(configPanel.softCapsManageButton, L("SoftCapsManageButton"), L("TooltipSoftCapsManageBody"))
    configPanel.selectionOverridesHeader = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    configPanel.selectionOverridesHeader:SetText(L("SelectionOverrides"))

    configPanel.selectionOverridesBlock = CreateFrame("Frame", nil, contentFrame)
    configPanel.forceSpecToggleRow = CreateFrame("Frame", nil, configPanel.selectionOverridesBlock)
    configPanel.forceSpecDropdownRow = CreateFrame("Frame", nil, configPanel.selectionOverridesBlock)
    configPanel.forceBracketToggleRow = CreateFrame("Frame", nil, configPanel.selectionOverridesBlock)
    configPanel.forceBracketDropdownRow = CreateFrame("Frame", nil, configPanel.selectionOverridesBlock)

    configPanel.forceSpecCheck = CreateFrame("CheckButton", nil, configPanel.forceSpecToggleRow, "UICheckButtonTemplate")
    configPanel.forceSpecLabel = configPanel.forceSpecToggleRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    configPanel.forceSpecLabel:SetText(L("ForceSpecialization"))

    configPanel.forceSpecDropdown = CreateFrame("Frame", "WOTLKPawnForceSpecDropdown", configPanel.forceSpecDropdownRow, "UIDropDownMenuTemplate")
    AttachTooltip(configPanel.forceSpecDropdown, L("ForceSpecialization"), L("TooltipForceSpecDropdownBody"))
    UIDropDownMenu_SetWidth(configPanel.forceSpecDropdown, 150)
    UIDropDownMenu_Initialize(configPanel.forceSpecDropdown, function(_, level)
        if level ~= 1 then return end

        local autoInfo = UIDropDownMenu_CreateInfo()
        autoInfo.text = L("AutoDetected")
        autoInfo.value = AUTO_SPEC_VALUE
        autoInfo.func = function()
            addon.ClearForcedSpecOverride()
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
        end
        UIDropDownMenu_AddButton(autoInfo, level)

        local classData = addon.GetClassData()
        for _, specName in ipairs((classData and classData["Specs"]) or {}) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = specName
            info.value = specName
            info.func = function()
                addon.SetForcedSpecOverride(specName)
                addon.UpdateActiveWeights()
                addon.RefreshConfigPanel()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    configPanel.forceBracketCheck = CreateFrame("CheckButton", nil, configPanel.forceBracketToggleRow, "UICheckButtonTemplate")
    configPanel.forceBracketLabel = configPanel.forceBracketToggleRow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    configPanel.forceBracketLabel:SetText(L("ForceWeightBracket"))

    configPanel.forceBracketDropdown = CreateFrame("Frame", "WOTLKPawnForceBracketDropdown", configPanel.forceBracketDropdownRow, "UIDropDownMenuTemplate")
    AttachTooltip(configPanel.forceBracketDropdown, L("ForceWeightBracket"), L("TooltipForceBracketDropdownBody"))
    UIDropDownMenu_SetWidth(configPanel.forceBracketDropdown, 150)
    UIDropDownMenu_Initialize(configPanel.forceBracketDropdown, function(_, level)
        if level ~= 1 then return end

        local autoInfo = UIDropDownMenu_CreateInfo()
        autoInfo.text = L("AutoByLevel")
        autoInfo.value = AUTO_BRACKET_VALUE
        autoInfo.func = function()
            addon.ClearForcedBracketOverride()
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
        end
        UIDropDownMenu_AddButton(autoInfo, level)

        local levelingInfo = UIDropDownMenu_CreateInfo()
        levelingInfo.text = L("LevelingBracket")
        levelingInfo.value = "leveling"
        levelingInfo.func = function()
            addon.SetForcedBracketOverride("leveling")
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
        end
        UIDropDownMenu_AddButton(levelingInfo, level)

        local endgameInfo = UIDropDownMenu_CreateInfo()
        endgameInfo.text = L("EndgameBracket")
        endgameInfo.value = "endgame"
        endgameInfo.func = function()
            addon.SetForcedBracketOverride("endgame")
            addon.UpdateActiveWeights()
            addon.RefreshConfigPanel()
        end
        UIDropDownMenu_AddButton(endgameInfo, level)
    end)

    configPanel.overridesHintText = contentFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    configPanel.overridesHintText:SetText(L("OverridesHint"))

    configPanel.forceSpecCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            local selected = addon.GetForcedSpecOverride()
            if not selected then
                selected = addon.GetCurrentSpecName()
            end
            if not selected or selected == "" then
                local classData = addon.GetClassData()
                selected = classData and classData["Specs"] and classData["Specs"][1] or nil
            end
            addon.SetForcedSpecOverride(selected)
        else
            addon.ClearForcedSpecOverride()
        end
        addon.UpdateActiveWeights()
        addon.RefreshConfigPanel()
    end)
    AttachTooltip(configPanel.forceSpecCheck, L("ForceSpecialization"), L("TooltipForceSpecToggleBody"))

    configPanel.forceBracketCheck:SetScript("OnClick", function(self)
        if self:GetChecked() then
            local selected = addon.GetForcedBracketOverride() or GetNaturalLevelBracketKey()
            addon.SetForcedBracketOverride(selected)
        else
            addon.ClearForcedBracketOverride()
        end
        addon.UpdateActiveWeights()
        addon.RefreshConfigPanel()
    end)
    AttachTooltip(configPanel.forceBracketCheck, L("ForceWeightBracket"), L("TooltipForceBracketToggleBody"))

    configPanel.okay = function()
        addon.CommitPendingConfigEdits()
    end
    configPanel:SetScript("OnHide", function()
        addon.CommitPendingConfigEdits()
    end)
    configPanel:SetScript("OnShow", addon.RefreshConfigPanel)

    InterfaceOptions_AddCategory(configPanel)
end

local function OpenConfigPanel()
    if not configPanel then
        CreateConfigPanel()
    end

    addon.RefreshConfigPanel()
    InterfaceOptionsFrame_OpenToCategory(configPanel)
    if InterfaceOptionsFrame and not InterfaceOptionsFrame:IsShown() then
        InterfaceOptionsFrame_OpenToCategory(configPanel)
    end
end

local function DumpCurrentOverrides()
    addon.EnsureSavedVariables()
    addon.UpdateActiveWeights()

    local bracket = addon.GetLevelBracketKey()
    local currentSpecName = addon.GetCurrentSpecName()
    local specLabel = currentSpecName ~= "" and currentSpecName or "Unknown"
    print(string.format("|cffFFD700WOTLK Pawn DB Dump|r Class=%s Spec=%s Bracket=%s", GetLocalizedClassName(class), specLabel, bracket))

    if currentSpecName == "" then
        print("WOTLK Pawn: no active spec detected; nothing to dump.")
        return
    end

    local function PrintNumericTable(prefix, source, valueFormat)
        local keys = {}
        for key, value in pairs(source or {}) do
            if type(value) == "number" then
                table.insert(keys, key)
            end
        end
        table.sort(keys)

        if #keys == 0 then
            print(prefix .. " none")
            return
        end

        for _, key in ipairs(keys) do
            local value = source[key]
            if valueFormat then
                print(string.format("%s %s = " .. valueFormat, prefix, key, value))
            else
                print(string.format("%s %s = %s", prefix, key, tostring(value)))
            end
        end
    end

    local manual = addon.GetSpecOverrides(currentSpecName, false) or {}
    local caps = addon.GetSpecCapOverrides(currentSpecName, false) or {}
    local forcedSpec = addon.GetForcedSpecOverride and addon.GetForcedSpecOverride() or nil
    local forcedBracket = addon.GetForcedBracketOverride and addon.GetForcedBracketOverride() or nil
    print(string.format("WOTLK Pawn Selection forceSpec=%s forceBracket=%s", forcedSpec or "auto", forcedBracket or "auto"))
    PrintNumericTable("WOTLK Pawn Manual", manual, "%.3f")
    PrintNumericTable("WOTLK Pawn Caps", caps, nil)
end

local slotMap = {
    ["INVTYPE_HEAD"] = {1}, ["INVTYPE_NECK"] = {2}, ["INVTYPE_SHOULDER"] = {3}, ["INVTYPE_BODY"] = {4},
    ["INVTYPE_CHEST"] = {5}, ["INVTYPE_ROBE"] = {5}, ["INVTYPE_WAIST"] = {6}, ["INVTYPE_LEGS"] = {7},
    ["INVTYPE_FEET"] = {8}, ["INVTYPE_WRIST"] = {9}, ["INVTYPE_HAND"] = {10}, ["INVTYPE_FINGER"] = {11, 12},
    ["INVTYPE_TRINKET"] = {13, 14}, ["INVTYPE_CLOAK"] = {15}, ["INVTYPE_WEAPON"] = {16},
    ["INVTYPE_2HWEAPON"] = {16}, ["INVTYPE_WEAPONMAINHAND"] = {16}, ["INVTYPE_WEAPONOFFHAND"] = {17},
    ["INVTYPE_HOLDABLE"] = {17}, ["INVTYPE_SHIELD"] = {17}, ["INVTYPE_RANGED"] = {18}, ["INVTYPE_RANGEDRIGHT"] = {18},
    ["INVTYPE_THROWN"] = {18}, ["INVTYPE_RELIC"] = {18}
}

local function GetEquippedItemEP(slotID)
    local equippedLink = GetInventoryItemLink("player", slotID)
    if not equippedLink then
        return 0, false
    end
    return addon.CalculateEP(equippedLink), true
end

local function GetComparisonEP(itemEquipLoc, slots, hoveredLink)
    if itemEquipLoc == "INVTYPE_2HWEAPON" then
        local mainEP, hasMain = GetEquippedItemEP(16)
        local offEP, hasOff = GetEquippedItemEP(17)
        if hasMain or hasOff then
            return mainEP + offEP, true
        end
        return 0, false
    end

    local bestEquippedEP, hasEquipped = 999999, false
    for _, slotID in ipairs(slots or {}) do
        local equippedLink = GetInventoryItemLink("player", slotID)
        if equippedLink then
            if #(slots or {}) > 1 and hoveredLink and equippedLink == hoveredLink then
                -- Skip: hovered item is equipped in this slot
            else
                local equippedEP = addon.CalculateEP(equippedLink)
                hasEquipped = true
                if equippedEP < bestEquippedEP then bestEquippedEP = equippedEP end
            end
        end
    end
    return hasEquipped and bestEquippedEP or 0, hasEquipped
end

local function ClearPawnLines(tooltip)
    -- remove any existing EP line previously added by Pawn
    local name = tooltip:GetName()
    if not name then return end
    for i = tooltip:NumLines(), 1, -1 do
        local line = _G[name .. "TextLeft" .. i]
        if line then
            local text = line:GetText()
            if text and text:find("EP:") then
                line:SetText("")
            end
        end
    end
end

local function AddEPToTooltip(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end

    local _, _, _, _, _, _, _, _, itemEquipLoc = GetItemInfo(link)
    if not itemEquipLoc or itemEquipLoc == "" then return end

    local slots = slotMap[itemEquipLoc]
    if not slots then return end

    -- clear any prior Pawn lines so repeated runs replace instead of append
    ClearPawnLines(tooltip)

    -- grab raw stats first so we can detect missing data
    local stats = addon.GetItemStatsWithEnchantAndGems(link)
    local statsEmpty = not stats or not next(stats)

    local hoveredEP = addon.CalculateEP(link)
    local bestEquippedEP, hasEquipped = GetComparisonEP(itemEquipLoc, slots, link)

    local diffText = ""
    if hasEquipped then
        local diff = hoveredEP - bestEquippedEP
        if math.abs(diff) > 0.0049 then
            local color = diff >= 0 and "|cff00FF00+" or "|cffFF0000"
            diffText = string.format(" (%s%s|r)", color, FormatLocalizedNumber(diff, 2))
        end
    end

    local currentSpecName = addon.GetCurrentSpecName()
    if currentSpecName ~= "" then
        tooltip:AddLine(string.format("|cffFFD700%s EP: %s%s|r", currentSpecName, FormatLocalizedNumber(hoveredEP, 2), diffText))
    else
        tooltip:AddLine(string.format("|cffFFD700EP: %s%s|r", FormatLocalizedNumber(hoveredEP, 2), diffText))
    end

    -- schedule retries when EP is zero but either stats were missing or the
    -- stats table contained entries.  Retry several times with increasing delay
    -- because vendor/cached tooltips can take a few frames to populate.  Track
    -- the count on the tooltip so we don't loop forever.
    if C_Timer and C_Timer.After then
        local count = tooltip._pawnRetryCount or 0
        if count < 5 and hoveredEP == 0 then
            tooltip._pawnRetryCount = count + 1
            local delay = 0.1 * tooltip._pawnRetryCount
            C_Timer.After(delay, function()
                if tooltip:IsShown() then
                    AddEPToTooltip(tooltip)
                end
            end)
        end
    end

    local projectedGemEP = 0
    local projectedEnchantEP = 0
    local perSocketResult = nil

    -- Gem recommendation section
    local emptySocketCount = 0
    local emptySocketColors = {}
    local socketBonusStat, socketBonusAmount = nil, 0
    for i = 1, tooltip:NumLines() do
        local line = _G[tooltip:GetName() .. "TextLeft" .. i]
        local text = line and line:GetText()
        if text then
            if text:find("Red Socket") or text:find("Roter Sockel") then
                emptySocketCount = emptySocketCount + 1
                table.insert(emptySocketColors, "r")
            elseif text:find("Yellow Socket") or text:find("Gelber Sockel") then
                emptySocketCount = emptySocketCount + 1
                table.insert(emptySocketColors, "y")
            elseif text:find("Blue Socket") or text:find("Blauer Sockel") then
                emptySocketCount = emptySocketCount + 1
                table.insert(emptySocketColors, "b")
            elseif text:find("Meta Socket") or text:find("Meta%-Sockel") then
                emptySocketCount = emptySocketCount + 1
                -- Don't add meta to emptySocketColors
            end
            -- Parse socket bonus
            if not socketBonusStat then
                local stat, amt = ParseSocketBonus(text)
                if stat then
                    socketBonusStat = stat
                    socketBonusAmount = amt
                end
            end
        end
    end

    -- Check socketed gems for non-BiS (skip meta gems via Diamond/diamant heuristic)
    local hasNonBisGem = false
    local hasBisGem = false
    local currentGemEP = 0
    local nonBisGemCount = 0
    local totalNonBisGemEP = 0
    local recs = addon.GetGemRecommendation and addon.GetGemRecommendation(class, currentSpecName)
    local currentWeights = addon.GetCurrentWeights()
    if recs and recs.bis and GetItemGem then
        local bisName = addon.GetLocalizedGemName(recs.bis)
        for i = 1, 3 do
            local gemName, gemLink = GetItemGem(link, i)
            if gemName and gemLink then
                local isMetaGem = gemName:lower():find("diamond") or gemName:lower():find("diamant")
                if not isMetaGem then
                    if gemName == bisName then
                        hasBisGem = true
                    else
                        hasNonBisGem = true
                        -- Compute EP of current non-BiS gem
                        local gemStats = GetItemStats(gemLink)
                        if not gemStats or not next(gemStats) then
                            gemStats = addon.GetGemStats and addon.GetGemStats(gemLink) or nil
                        end
                        if gemStats then
                            local ep = 0
                            for k, v in pairs(gemStats) do
                                ep = ep + v * (currentWeights[k] or 0)
                            end
                            if ep > currentGemEP then
                                currentGemEP = ep
                            end
                            nonBisGemCount = nonBisGemCount + 1
                            totalNonBisGemEP = totalNonBisGemEP + ep
                        end
                    end
                end
            end
        end
    end

    if emptySocketCount > 0 or hasNonBisGem or hasBisGem then
        local bracketKey = addon.GetLevelBracketKey()
        local _, _, _, _, minLevel = GetItemInfo(link)
        minLevel = minLevel or 0

        if bracketKey == "leveling" or minLevel < 80 then
            tooltip:AddLine("|cffFF6600" .. L("GemWarningLowLevel") .. "|r")
        elseif recs then
            if hasNonBisGem then
                tooltip:AddLine("|cffFF6600" .. L("GemWarningNonBiS") .. "|r")
            end
            tooltip:AddLine("|cff888888--- " .. L("GemRecommendationHeader") .. " ---|r")
            if recs.bis then
                local bisEP = recs.bis.computedEP or (recs.bis.ep_amount * (currentWeights[recs.bis.ep_stat] or 0))
                local bisStatLabel = "+" .. recs.bis.ep_amount .. " " .. GetLocalizedStatLabel(recs.bis.ep_stat)
                local bisGemName = addon.GetLocalizedGemName(recs.bis)

                if hasBisGem and not hasNonBisGem and emptySocketCount == 0 then
                    -- Scenario 3: BiS already socketed
                    tooltip:AddLine(string.format(
                        "|cff888888* " .. L("GemBiSLabel") .. ": %s (%s) - " .. L("GemBiSAlready") .. "|r",
                        bisGemName, bisStatLabel
                    ))
                elseif hasNonBisGem then
                    -- Scenario 1: Non-BiS gem, show upgrade delta
                    local deltaEP = bisEP - currentGemEP
                    tooltip:AddLine(string.format(
                        "|cff00FF96* " .. L("GemBiSLabel") .. ": %s (%s) +%s EP " .. L("GemUpgrade") .. "|r",
                        bisGemName, bisStatLabel, FormatLocalizedNumber(deltaEP, 2)
                    ))
                else
                    -- Scenario 2: Empty socket, show full EP
                    tooltip:AddLine(string.format(
                        "|cff00FF96* " .. L("GemBiSLabel") .. ": %s (%s) +%s EP " .. L("GemIfSocketed") .. "|r",
                        bisGemName, bisStatLabel, FormatLocalizedNumber(bisEP, 2)
                    ))
                end
            end
            if emptySocketCount > 0 and recs.budget then
                local budgetEP = recs.budget.computedEP or (recs.budget.ep_amount * (currentWeights[recs.budget.ep_stat] or 0))
                local budgetStatLabel = "+" .. recs.budget.ep_amount .. " " .. GetLocalizedStatLabel(recs.budget.ep_stat)
                tooltip:AddLine(string.format(
                    "|cffFFBB00* " .. L("GemBudgetLabel") .. ": %s (%s) +%s EP " .. L("GemIfSocketed") .. "|r",
                    addon.GetLocalizedGemName(recs.budget), budgetStatLabel, FormatLocalizedNumber(budgetEP, 2)
                ))
            end
            -- Per-socket color recommendation (when ≥2 empty non-meta sockets and socket bonus exists)
            if #emptySocketColors >= 2 and socketBonusStat then
                perSocketResult = addon.ResolvePerSocketRecommendation and addon.ResolvePerSocketRecommendation(emptySocketColors, socketBonusStat, socketBonusAmount)
                if perSocketResult and perSocketResult.useColorMatch then
                    local bonusStatLabel = GetLocalizedStatLabel(socketBonusStat)
                    tooltip:AddLine(string.format("|cff9999FF  " .. L("GemMatchColors") .. " (+%d %s " .. L("GemSocketBonus") .. " = +%s EP):|r",
                        socketBonusAmount, bonusStatLabel, FormatLocalizedNumber(perSocketResult.bonusEP, 2)))
                    local socketColorNames = { r = "|cffFF6666", y = "|cffFFFF66", b = "|cff6666FF" }
                    for _, entry in ipairs(perSocketResult.matchStrategy) do
                        if entry.gem then
                            local gemName = addon.GetLocalizedGemName(entry.gem)
                            local colorCode = socketColorNames[entry.socketColor] or "|cffAAAAAA"
                            local colorName = L("GemSocketColor_" .. entry.socketColor)
                            tooltip:AddLine(string.format("  %s[%s]|r %s (+%s EP)",
                                colorCode, colorName, gemName, FormatLocalizedNumber(entry.ep, 2)))
                        end
                    end
                    tooltip:AddLine(string.format("|cff9999FF  Total: %s EP vs %s EP (" .. L("GemIgnoreColors") .. ")|r",
                        FormatLocalizedNumber(perSocketResult.matchEP, 2), FormatLocalizedNumber(perSocketResult.ignoreEP, 2)))
                end
            end
        end
    end

    -- Accumulate projected gem EP
    if recs and recs.bis then
        local bisEP = recs.bis.computedEP or (recs.bis.ep_amount * (currentWeights[recs.bis.ep_stat] or 0))
        if emptySocketCount > 0 then
            if perSocketResult and perSocketResult.useColorMatch then
                projectedGemEP = perSocketResult.matchEP
            else
                projectedGemEP = bisEP * emptySocketCount
            end
        end
        if nonBisGemCount > 0 then
            projectedGemEP = projectedGemEP + (bisEP * nonBisGemCount - totalNonBisGemEP)
        end
    end

    -- Enchant recommendation section
    do
        local bracketKey = addon.GetLevelBracketKey()

        if bracketKey ~= "leveling" then
            local enchantRec = addon.ResolveEnchantRecommendation and addon.ResolveEnchantRecommendation(itemEquipLoc, link)
            if enchantRec and enchantRec.best then
                tooltip:AddLine("|cff888888--- " .. L("EnchantRecommendationHeader") .. " ---|r")
                local enchantName = addon.GetLocalizedEnchantName(enchantRec.best)

                -- Build stat summary for the best enchant
                local statParts = {}
                for stat, amount in pairs(enchantRec.best.stats) do
                    table.insert(statParts, "+" .. amount .. " " .. GetLocalizedStatLabel(stat))
                end
                local statSummary = table.concat(statParts, ", ")

                if enchantRec.isCurrentBiS then
                    -- BiS already applied
                    tooltip:AddLine(string.format(
                        "|cff888888* " .. L("EnchantBiSLabel") .. ": %s (%s) - " .. L("EnchantBiSAlready") .. "|r",
                        enchantName, statSummary
                    ))
                    projectedEnchantEP = 0
                elseif enchantRec.hasEnchant then
                    -- Non-BiS enchant, show upgrade delta
                    local deltaEP = enchantRec.bestEP - enchantRec.currentEnchantEP
                    tooltip:AddLine(string.format(
                        "|cff00FF96* " .. L("EnchantBiSLabel") .. ": %s (%s) +%s EP " .. L("EnchantUpgrade") .. "|r",
                        enchantName, statSummary, FormatLocalizedNumber(deltaEP, 2)
                    ))
                    projectedEnchantEP = deltaEP
                else
                    -- No enchant, show full EP
                    tooltip:AddLine(string.format(
                        "|cff00FF96* " .. L("EnchantBiSLabel") .. ": %s (%s) +%s EP " .. L("EnchantIfApplied") .. "|r",
                        enchantName, statSummary, FormatLocalizedNumber(enchantRec.bestEP, 2)
                    ))
                    projectedEnchantEP = enchantRec.bestEP
                end
            end
        end
    end

    -- Projected EP subtotal
    if projectedGemEP > 0 or projectedEnchantEP > 0 then
        local projectedTotal = hoveredEP + projectedGemEP + projectedEnchantEP
        tooltip:AddLine(string.format("|cffFFD700--- %s: %s (%s) ---|r",
            L("ProjectedEPHeader"),
            FormatLocalizedNumber(projectedTotal, 2),
            L("ProjectedEPFormat")
        ))
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("PLAYER_TALENT_UPDATE")
frame:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
frame:RegisterEvent("CHARACTER_POINTS_CHANGED")
frame:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("ZONE_CHANGED_INDOORS")
frame:RegisterEvent("ZONE_CHANGED")
frame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        addon.EnsureSavedVariables()
        if arg1 == addon.name then
            addon.UpdateActiveWeights()
            if configPanel and configPanel:IsShown() then
                addon.RefreshConfigPanel()
            end
        end
        return
    end

    if event == "PLAYER_LOGIN" then
        addon.EnsureSavedVariables()
        addon.UpdateActiveWeights()
        if configPanel and configPanel:IsShown() then
            addon.RefreshConfigPanel()
        end
        return
    end

    if event == "PLAYER_LOGOUT" then
        addon.CommitPendingConfigEdits()
        addon.EnsureSavedVariables()
        return
    end

    addon.UpdateActiveWeights()
    if configPanel and configPanel:IsShown() then
        addon.RefreshConfigPanel()
    end
end)

CreateConfigPanel()

SLASH_WOTLKPawnCONFIG1 = "/pawn-config"
SlashCmdList["WOTLKPawnCONFIG"] = function()
    OpenConfigPanel()
end

SLASH_WOTLKPawnDUMPDB1 = "/pawn-dumpdb"
SlashCmdList["WOTLKPawnDUMPDB"] = function()
    DumpCurrentOverrides()
end

C_Timer = C_Timer or {}
if C_Timer.After then
    C_Timer.After(3, addon.UpdateActiveWeights)
else
    addon.UpdateActiveWeights()
end

local function SafeHook(tooltip)
    if tooltip and tooltip.HookScript then
        pcall(function()
            tooltip:HookScript("OnTooltipSetItem", AddEPToTooltip)
        end)
    end
end

SafeHook(GameTooltip)
SafeHook(ItemRefTooltip)
SafeHook(ShoppingTooltip1)
SafeHook(ShoppingTooltip2)
if _G.QuestRewardItemTooltip then SafeHook(_G.QuestRewardItemTooltip) end
if _G.QuestLogRewardItemTooltip then SafeHook(_G.QuestLogRewardItemTooltip) end
if _G.QuestLogItemTooltip then SafeHook(_G.QuestLogItemTooltip) end

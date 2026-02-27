local addonName, addon = ...
local class = addon.class

local function CopySelectionOverrides(source)
    local result = {}
    if type(source) ~= "table" then
        return result
    end

    for classKey, selection in pairs(source) do
        if type(selection) == "table" then
            local classSelection = {}
            if type(selection.forcedSpec) == "string" and selection.forcedSpec ~= "" then
                classSelection.forcedSpec = selection.forcedSpec
            end
            if selection.forcedBracket == "leveling" or selection.forcedBracket == "endgame" then
                classSelection.forcedBracket = selection.forcedBracket
            end
            if next(classSelection) then
                result[classKey] = classSelection
            end
        end
    end

    return result
end

local function GetClassSpecs()
    local classData = addon.GetClassData and addon.GetClassData() or nil
    if classData and type(classData.Specs) == "table" then
        return classData.Specs
    end

    local allWeights = addon.GetAllWeights and addon.GetAllWeights() or nil
    local byClass = allWeights and allWeights[class] or nil
    if byClass and type(byClass.Specs) == "table" then
        return byClass.Specs
    end

    return {}
end

local function IsValidSpecName(specName)
    if type(specName) ~= "string" or specName == "" then
        return false
    end
    for _, existing in ipairs(GetClassSpecs()) do
        if existing == specName then
            return true
        end
    end
    return false
end

local function GetClassSelectionOverrides(create)
    local db = addon.GetEffectiveDB()
    local root = db.selectionOverrides
    local classSelection = root[class]
    if not classSelection and create then
        classSelection = {}
        root[class] = classSelection
    end
    return classSelection
end

function addon.EnsureSavedVariables()
    if type(WOTLKPawnDB) ~= "table" then
        WOTLKPawnDB = {}
    end
    if type(WOTLKPawnCharDB) ~= "table" then
        WOTLKPawnCharDB = {}
    end

    WOTLKPawnDB.manualOverrides = type(WOTLKPawnDB.manualOverrides) == "table" and WOTLKPawnDB.manualOverrides or {}
    WOTLKPawnDB.capOverrides = type(WOTLKPawnDB.capOverrides) == "table" and WOTLKPawnDB.capOverrides or {}
    WOTLKPawnDB.selectionOverrides = type(WOTLKPawnDB.selectionOverrides) == "table" and WOTLKPawnDB.selectionOverrides or {}
    WOTLKPawnCharDB.manualOverrides = type(WOTLKPawnCharDB.manualOverrides) == "table" and WOTLKPawnCharDB.manualOverrides or {}
    WOTLKPawnCharDB.capOverrides = type(WOTLKPawnCharDB.capOverrides) == "table" and WOTLKPawnCharDB.capOverrides or {}
    WOTLKPawnCharDB.selectionOverrides = type(WOTLKPawnCharDB.selectionOverrides) == "table" and WOTLKPawnCharDB.selectionOverrides or {}

    if not WOTLKPawnCharDB._migratedFromGlobal then
        if not next(WOTLKPawnCharDB.manualOverrides) and next(WOTLKPawnDB.manualOverrides) then
            WOTLKPawnCharDB.manualOverrides = addon.CopyNumericOverrideTree(WOTLKPawnDB.manualOverrides)
        end
        if not next(WOTLKPawnCharDB.capOverrides) and next(WOTLKPawnDB.capOverrides) then
            WOTLKPawnCharDB.capOverrides = addon.CopyNumericOverrideTree(WOTLKPawnDB.capOverrides)
        end
        if not next(WOTLKPawnCharDB.selectionOverrides) and next(WOTLKPawnDB.selectionOverrides) then
            WOTLKPawnCharDB.selectionOverrides = CopySelectionOverrides(WOTLKPawnDB.selectionOverrides)
        end
        WOTLKPawnCharDB._migratedFromGlobal = true
    end

    if not next(WOTLKPawnDB.manualOverrides) and next(WOTLKPawnCharDB.manualOverrides) then
        WOTLKPawnDB.manualOverrides = addon.CopyNumericOverrideTree(WOTLKPawnCharDB.manualOverrides)
    end
    if not next(WOTLKPawnDB.capOverrides) and next(WOTLKPawnCharDB.capOverrides) then
        WOTLKPawnDB.capOverrides = addon.CopyNumericOverrideTree(WOTLKPawnCharDB.capOverrides)
    end
    if not next(WOTLKPawnDB.selectionOverrides) and next(WOTLKPawnCharDB.selectionOverrides) then
        WOTLKPawnDB.selectionOverrides = CopySelectionOverrides(WOTLKPawnCharDB.selectionOverrides)
    end
end

function addon.GetEffectiveDB()
    addon.EnsureSavedVariables()
    return WOTLKPawnCharDB
end

function addon.SyncLegacyGlobalDB()
    addon.EnsureSavedVariables()
    WOTLKPawnDB.manualOverrides = addon.CopyNumericOverrideTree(WOTLKPawnCharDB.manualOverrides)
    WOTLKPawnDB.capOverrides = addon.CopyNumericOverrideTree(WOTLKPawnCharDB.capOverrides)
    WOTLKPawnDB.selectionOverrides = CopySelectionOverrides(WOTLKPawnCharDB.selectionOverrides)
end

function addon.GetForcedSpecOverride()
    local classSelection = GetClassSelectionOverrides(false)
    if not classSelection then return nil end
    local specName = classSelection.forcedSpec
    if IsValidSpecName(specName) then
        return specName
    end
    return nil
end

function addon.SetForcedSpecOverride(specName)
    local classSelection = GetClassSelectionOverrides(true)
    if not classSelection then return end

    if IsValidSpecName(specName) then
        classSelection.forcedSpec = specName
    else
        classSelection.forcedSpec = nil
    end

    if not classSelection.forcedSpec and not classSelection.forcedBracket then
        addon.GetEffectiveDB().selectionOverrides[class] = nil
    end
    addon.SyncLegacyGlobalDB()
end

function addon.ClearForcedSpecOverride()
    addon.SetForcedSpecOverride(nil)
end

function addon.GetForcedBracketOverride()
    local classSelection = GetClassSelectionOverrides(false)
    if not classSelection then return nil end
    local bracket = classSelection.forcedBracket
    if bracket == "leveling" or bracket == "endgame" then
        return bracket
    end
    return nil
end

function addon.SetForcedBracketOverride(bracket)
    local classSelection = GetClassSelectionOverrides(true)
    if not classSelection then return end

    if bracket == "leveling" or bracket == "endgame" then
        classSelection.forcedBracket = bracket
    else
        classSelection.forcedBracket = nil
    end

    if not classSelection.forcedSpec and not classSelection.forcedBracket then
        addon.GetEffectiveDB().selectionOverrides[class] = nil
    end
    addon.SyncLegacyGlobalDB()
end

function addon.ClearForcedBracketOverride()
    addon.SetForcedBracketOverride(nil)
end

function addon.ClearSelectionOverrides()
    local db = addon.GetEffectiveDB()
    if db.selectionOverrides then
        db.selectionOverrides[class] = nil
    end
    addon.SyncLegacyGlobalDB()
end

function addon.GetSpecOverrides(specName, create)
    if not specName or specName == "" then return nil end
    local db = addon.GetEffectiveDB()

    local manualOverrides = db.manualOverrides
    local classOverrides = manualOverrides[class]
    if not classOverrides and create then
        classOverrides = {}
        manualOverrides[class] = classOverrides
    end
    if not classOverrides then return nil end

    local bracket = addon.GetLevelBracketKey()
    local bracketOverrides = classOverrides[bracket]
    if not bracketOverrides and create then
        bracketOverrides = {}
        classOverrides[bracket] = bracketOverrides
    end
    if not bracketOverrides then return nil end

    local specOverrides = bracketOverrides[specName]
    if not specOverrides and create then
        specOverrides = {}
        bracketOverrides[specName] = specOverrides
    end

    return specOverrides
end

function addon.GetSpecCapOverrides(specName, create)
    if not specName or specName == "" then return nil end
    local db = addon.GetEffectiveDB()

    local capOverrides = db.capOverrides
    local classOverrides = capOverrides[class]
    if not classOverrides and create then
        classOverrides = {}
        capOverrides[class] = classOverrides
    end
    if not classOverrides then return nil end

    local bracket = addon.GetLevelBracketKey()
    local bracketOverrides = classOverrides[bracket]
    if not bracketOverrides and create then
        bracketOverrides = {}
        classOverrides[bracket] = bracketOverrides
    end
    if not bracketOverrides then return nil end

    local specOverrides = bracketOverrides[specName]
    if not specOverrides and create then
        specOverrides = {}
        bracketOverrides[specName] = specOverrides
    end

    return specOverrides
end

function addon.SaveManualOverride(statName, value)
    local currentSpecName = addon.GetCurrentSpecName()
    if not currentSpecName or currentSpecName == "" then return end
    if not statName then return end
    local specOverrides = addon.GetSpecOverrides(currentSpecName, true)
    if not specOverrides then return end
    specOverrides[statName] = value
    addon.SyncLegacyGlobalDB()
end

function addon.SaveCapOverride(key, value)
    local currentSpecName = addon.GetCurrentSpecName()
    if not currentSpecName or currentSpecName == "" then return end
    if not key then return end
    local specOverrides = addon.GetSpecCapOverrides(currentSpecName, true)
    if not specOverrides then return end
    if key == "HitSoftMultiplier" or key == "ExpSoftMultiplier" or (type(key) == "string" and string.find(key, "^SoftMultiplier__")) then
        if type(value) == "number" and value < 0 then value = 0 end
    end
    specOverrides[key] = value
    addon.SyncLegacyGlobalDB()
end

function addon.GetCurrentSoftCaps()
    local softCaps = {}
    local specCaps = addon.GetSpecCapOverrides(addon.GetCurrentSpecName(), false)
    if not specCaps then
        return softCaps
    end

    local excludedSoftCapStats = {
        ["ITEM_MOD_HIT_RATING_SHORT"] = true,
        ["ITEM_MOD_EXPERTISE_RATING_SHORT"] = true
    }

    for key, value in pairs(specCaps) do
        if type(key) == "string" and type(value) == "number" then
            local statKey = string.match(key, "^SoftCap__(.+)$")
            if statKey then
                if not excludedSoftCapStats[statKey] then
                    local entry = softCaps[statKey] or { cap = 0, multiplier = 1 }
                    entry.cap = value
                    softCaps[statKey] = entry
                end
            else
                statKey = string.match(key, "^SoftMultiplier__(.+)$")
                if statKey then
                    if not excludedSoftCapStats[statKey] then
                        local entry = softCaps[statKey] or { cap = 0, multiplier = 1 }
                        entry.multiplier = value < 0 and 0 or value
                        softCaps[statKey] = entry
                    end
                end
            end
        end
    end

    return softCaps
end

function addon.SetSoftCapOverride(statKey, capValue, multiplierValue)
    if type(statKey) ~= "string" or statKey == "" then return end

    local currentSpecName = addon.GetCurrentSpecName()
    if not currentSpecName or currentSpecName == "" then return end

    local specOverrides = addon.GetSpecCapOverrides(currentSpecName, true)
    if not specOverrides then return end

    local capKey = "SoftCap__" .. statKey
    local multiplierKey = "SoftMultiplier__" .. statKey

    if type(capValue) == "number" then
        specOverrides[capKey] = capValue
    elseif capValue == nil then
        specOverrides[capKey] = nil
    end

    if type(multiplierValue) == "number" then
        if multiplierValue < 0 then multiplierValue = 0 end
        specOverrides[multiplierKey] = multiplierValue
    elseif multiplierValue == nil then
        specOverrides[multiplierKey] = nil
    end

    addon.SyncLegacyGlobalDB()
end

function addon.ClearSoftCapOverride(statKey)
    if type(statKey) ~= "string" or statKey == "" then return end

    local currentSpecName = addon.GetCurrentSpecName()
    if not currentSpecName or currentSpecName == "" then return end

    local specOverrides = addon.GetSpecCapOverrides(currentSpecName, false)
    if not specOverrides then return end

    specOverrides["SoftCap__" .. statKey] = nil
    specOverrides["SoftMultiplier__" .. statKey] = nil

    addon.SyncLegacyGlobalDB()
end

function addon.GetCurrentCapSettings()
    local classData = addon.GetClassData()
    local hitCap = classData and (classData["HitCap"] or 0) or 0
    local expCap = classData and (classData["ExpCap"] or 0) or 0
    local hitSoftCap, expSoftCap = 0, 0
    local hitSoftMultiplier, expSoftMultiplier = 1, 1

    local specCaps = addon.GetSpecCapOverrides(addon.GetCurrentSpecName(), false)
    if specCaps then
        if type(specCaps.HitCap) == "number" then hitCap = specCaps.HitCap end
        if type(specCaps.ExpCap) == "number" then expCap = specCaps.ExpCap end
    end

    if specCaps then
        if type(specCaps.HitSoftCap) == "number" then hitSoftCap = specCaps.HitSoftCap end
        if type(specCaps.HitSoftMultiplier) == "number" then
            hitSoftMultiplier = specCaps.HitSoftMultiplier
            if hitSoftMultiplier < 0 then hitSoftMultiplier = 0 end
        end
    end

    local softCaps = addon.GetCurrentSoftCaps()
    local expSoft = softCaps["ITEM_MOD_EXPERTISE_RATING_SHORT"]
    if expSoft then
        if type(expSoft.cap) == "number" then expSoftCap = expSoft.cap end
        if type(expSoft.multiplier) == "number" then expSoftMultiplier = expSoft.multiplier end
    end

    return hitCap, expCap, hitSoftCap, expSoftCap, hitSoftMultiplier, expSoftMultiplier
end

function addon.ResetCurrentSpecOverrides()
    local currentSpecName = addon.GetCurrentSpecName()
    if not currentSpecName or currentSpecName == "" then return end
    local db = addon.GetEffectiveDB()

    local function ClearSpecFromRoot(root)
        if not root then return end
        local classOverrides = root[class]
        if not classOverrides then return end
        local bracket = addon.GetLevelBracketKey()
        local bracketOverrides = classOverrides[bracket]
        if not bracketOverrides then return end

        bracketOverrides[currentSpecName] = nil
        if not next(bracketOverrides) then
            classOverrides[bracket] = nil
        end
        if not next(classOverrides) then
            root[class] = nil
        end
    end

    ClearSpecFromRoot(db.manualOverrides)
    ClearSpecFromRoot(db.capOverrides)
    addon.SyncLegacyGlobalDB()
end

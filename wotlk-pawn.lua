local addonName, addon = ...

if not addonName or addonName == "" then
    addonName = "WOTLKPawn"
end

addon = addon or _G.WOTLKPawnAddon or {}
_G.WOTLKPawnAddon = addon

addon.name = addonName

local _, class = UnitClass("player")
addon.class = class

addon.state = addon.state or {}
local state = addon.state
state.currentWeights = state.currentWeights or {}
state.currentSpecName = state.currentSpecName or ""
state.lastDetectedSpec = state.lastDetectedSpec
state.lastDetectedLevel = state.lastDetectedLevel or UnitLevel("player")
state.classData = state.classData
state.allWeights = state.allWeights

function addon.GetLevelBracketKey()
    if addon.GetForcedBracketOverride then
        local forcedBracket = addon.GetForcedBracketOverride()
        if forcedBracket == "leveling" or forcedBracket == "endgame" then
            return forcedBracket
        end
    end
    return UnitLevel("player") < 80 and "leveling" or "endgame"
end

function addon.CopyNumericOverrideTree(source)
    local result = {}
    if type(source) ~= "table" then
        return result
    end

    for classKey, classOverrides in pairs(source) do
        if type(classOverrides) == "table" then
            local classCopy = {}
            for bracketKey, bracketOverrides in pairs(classOverrides) do
                if type(bracketOverrides) == "table" then
                    local bracketCopy = {}
                    for specName, specOverrides in pairs(bracketOverrides) do
                        if type(specOverrides) == "table" then
                            local specCopy = {}
                            for statOrCapKey, value in pairs(specOverrides) do
                                if type(value) == "number" then
                                    specCopy[statOrCapKey] = value
                                end
                            end
                            if next(specCopy) then
                                bracketCopy[specName] = specCopy
                            end
                        end
                    end
                    if next(bracketCopy) then
                        classCopy[bracketKey] = bracketCopy
                    end
                end
            end
            if next(classCopy) then
                result[classKey] = classCopy
            end
        end
    end

    return result
end

function addon.GetCurrentSpecName()
    return addon.state.currentSpecName or ""
end

function addon.SetCurrentSpecName(specName)
    addon.state.currentSpecName = specName or ""
end

function addon.GetCurrentWeights()
    return addon.state.currentWeights or {}
end

function addon.SetCurrentWeights(weights)
    addon.state.currentWeights = weights or {}
end

function addon.GetClassData()
    return addon.state.classData
end

function addon.SetClassData(classData)
    addon.state.classData = classData
end

function addon.GetAllWeights()
    return addon.state.allWeights
end

function addon.SetAllWeights(allWeights)
    addon.state.allWeights = allWeights
end

function addon.GetLastDetectedSpec()
    return addon.state.lastDetectedSpec
end

function addon.SetLastDetectedSpec(specName)
    addon.state.lastDetectedSpec = specName
end

function addon.GetLastDetectedLevel()
    return addon.state.lastDetectedLevel
end

function addon.SetLastDetectedLevel(level)
    addon.state.lastDetectedLevel = level
end

--  	Author: Ryan Hagelstrom
--	  	Copyright © 2022
--	  	This work is licensed under a Creative Commons Attribution-ShareAlike 4.0 International License.
--	  	https://creativecommons.org/licenses/by-sa/4.0/

local rest = nil
local addEffect = nil
local applyDamage = nil

local checkModRoll = nil
local skillModRoll = nil
local initModRoll = nil
local modAttack = nil
local modSave = nil
local onCastSave = nil
local outputResult = nil

local bCritDeathSuccess = false
function onInit()
	rest = CharManager.rest
	addEffect = EffectManager.addEffect
	applyDamage = ActionDamage.applyDamage

	CharManager.rest = customRest
	EffectManager.addEffect = customAddEffect
	ActionDamage.applyDamage = customApplyDamage

	table.insert(DataCommon.conditions, "fatigued")
	table.sort(DataCommon.conditions)
end

function onTabletopInit()
	checkModRoll = ActionCheck.modRoll
	skillModRoll = ActionSkill.modRoll
	modAttack = ActionAttack.modAttack
	modSave = ActionSave.modSave
	onCastSave = ActionPower.onCastSave
	outputResult = ActionsManager.outputResult
	initModRoll = ActionInit.modRoll

	ActionCheck.modRoll = customCheckModRoll
	ActionSkill.modRoll = customSkillModRoll
	ActionAttack.modAttack = customModAttack
	ActionSave.modSave = customModSave
	ActionPower.onCastSave = customOnCastSave
	ActionsManager.outputResult = customOutputResult
	ActionInit.modRoll = customModInit

	ActionsManager.registerModHandler("check", customCheckModRoll)
	ActionsManager.registerModHandler("skill", customSkillModRoll)
	ActionsManager.registerModHandler("attack",customModAttack)
	ActionsManager.registerModHandler("save", customModSave)
	ActionsManager.registerModHandler("concentration", customModSave)
	ActionsManager.registerModHandler("init", customModInit)

end

function onClose()
	EffectManager.addEffect = addEffect
	CharManager.rest = rest
	ActionDamage.applyDamage = applyDamage
	ActionCheck.modRoll = checkModRoll
	ActionSkill.modRoll = skillModRoll
	ActionAttack.modAttack = modAttack
	ActionSave.modSave = modSave

	ActionPower.onCastSave = onCastSave
	ActionsManager.outputResult = outputResult
	ActionInit.modRoll = initModRoll

	ActionsManager.registerModHandler("check", ActionCheck.modRoll)
	ActionsManager.registerModHandler("skill", ActionSkill.modRoll)
	ActionsManager.registerModHandler("attack",ActionAttack.modAttack)
	ActionsManager.registerModHandler("save", ActionSave.modSave)
	ActionsManager.registerModHandler("concentration", ActionSave.modSave)
	ActionsManager.registerModHandler("init", ActionInit.modRoll)
end

function cleanFatigueEffect(rNewEffect)
	local nFatigueLevel = 0
	local aEffectComps = EffectManager.parseEffect(rNewEffect.sName)
	for i,sEffectComp in ipairs(aEffectComps) do
		local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
		if rEffectComp.type:lower() == "fatigued"  or rEffectComp.original:lower() == "fatigued" then
			if rEffectComp.mod == 0 then
				rEffectComp.mod = 1
				sEffectComp = sEffectComp .. ": 1"
			end
			aEffectComps[i] = sEffectComp:upper()
			nFatigueLevel = rEffectComp.mod
		end
	end
	rNewEffect.sName = EffectManager.rebuildParsedEffect(aEffectComps)
	return nFatigueLevel
end

-- Return return the sum total else return nil
function sumFatigue(rActor, nFatigueLevel)
	local nSummed = nil
	local nodeCT = ActorManager.getCTNode(rActor)
	local nodeEffectsList = DB.getChildren(nodeCT, "effects")

	for _, nodeEffect in pairs(nodeEffectsList) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)
		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type:upper() == "FATIGUED"  and rEffectComp.mod < ActorManager5E.getAbilityBonus(rActor, "prf") then
				rEffectComp.mod = rEffectComp.mod + nFatigueLevel
				aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
				sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
				updateEffect(nodeCT, nodeEffect, sEffect)
				nSummed = rEffectComp.mod
			elseif  rEffectComp.type:upper() == "FATIGUED"  and rEffectComp.mod == ActorManager5E.getAbilityBonus(rActor, "prf")  then
				nSummed = rEffectComp.mod
			end
		end
	end
	return nSummed
end

function updateEffect(nodeActor, nodeEffect, sLabel)
	DB.setValue(nodeEffect, "label", "string", sLabel)
	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect)
	local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), sLabel, Interface.getString("effect_status_updated"))
	EffectManager.message(sMessage, nodeActor, bGMOnly)
end

--Not currently used
function reduceFatigued(nodeCT)
	local rActor = ActorManager.resolveActor(nodeCT)
	-- Check conditionals
	local aEffectsByType = EffectManager5E.getEffectsByType(rActor, "FATIGUED")
	if aEffectsByType and next(aEffectsByType) then
		for _,nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			local sEffect = DB.getValue(nodeEffect, "label", "")
			local aEffectComps = EffectManager.parseEffect(sEffect)

			for i,sEffectComp in ipairs(aEffectComps) do
				local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
				if rEffectComp.type:lower() == "fatigued" then
					rEffectComp.mod  = rEffectComp.mod - 1
					if  rEffectComp.mod >= 1 then
						aEffectComps[i] = rEffectComp.type .. ": " .. tostring(rEffectComp.mod)
						sEffect = EffectManager.rebuildParsedEffect(aEffectComps)
						updateEffect(nodeCT, nodeEffect, sEffect)
					else
						EffectManager.expireEffect(nodeCT, nodeEffect, 0)
					end
				end
			end
		end
	end
end

function removeFatigued(nodeChar)
	local nodeCT = ActorManager.getCTNode(nodeChar)
	local nodeEffectsList = DB.getChildren(nodeCT, "effects")

	for _, nodeEffect in pairs(nodeEffectsList) do
		local sEffect = DB.getValue(nodeEffect, "label", "")
		local aEffectComps = EffectManager.parseEffect(sEffect)
		for i,sEffectComp in ipairs(aEffectComps) do
			local rEffectComp = EffectManager.parseEffectCompSimple(sEffectComp)
			if rEffectComp.type:upper() == "FATIGUED"  then
				EffectManager.expireEffect(nodeCT, nodeEffect, 0)
				break;
			end
		end
	end
end

function customRest(nodeChar, bLong)
	removeFatigued(nodeChar)
	rest(nodeChar,bLong)
end

function customAddEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	if not nodeCT or not rNewEffect or not rNewEffect.sName then
		return addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end
	if rNewEffect.sName:upper():match("FATIGUED") and bCritDeathSuccess then
		bCritDeathSuccess = false
		return
	end
	local nFatigued = nil
	local nFatiguedLevel = cleanFatigueEffect(rNewEffect)
	if nFatiguedLevel > 0  then
		local rActor = ActorManager.resolveActor(nodeCT)
		local aCancelled = EffectManager5E.checkImmunities(nil, rActor, rNewEffect)
		if #aCancelled > 0 then
			local sMessage = string.format("%s ['%s'] -> [%s]", Interface.getString("effect_label"), rNewEffect.sName, Interface.getString("effect_status_targetimmune"))
			EffectManager.message(sMessage, nodeCT, false, sUser);
			return
		end

		nFatigued = sumFatigue(rActor, nFatiguedLevel)
	end
	if not nFatigued then
		addEffect(sUser, sIdentity, nodeCT, rNewEffect, bShowMsg)
	end
end

function customApplyDamage(rSource, rTarget, rRoll)
	local bDead = false
	local nTotalHP
	local nWounds
	local sTargetNodeType, nodeTarget = ActorManager.getTypeAndNode(rTarget)
	if not nodeTarget or not rRoll or rRoll.sType ~= "heal"  then
		return applyDamage(rSource, rTarget, rRoll)
	end
	if sTargetNodeType == "pc" then
		nTotalHP = DB.getValue(nodeTarget, "hp.total", 0)
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
	elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
		nTotalHP = DB.getValue(nodeTarget, "hptotal", 0)
		nWounds = DB.getValue(nodeTarget, "wounds", 0)
	else
		return applyDamage(rSource, rTarget, rRoll)
	end
	if nTotalHP <= nWounds then
		bDead = true
	end

	applyDamage(rSource, rTarget, rRoll)

	if sTargetNodeType == "pc" then
		nWounds = DB.getValue(nodeTarget, "hp.wounds", 0)
	elseif sTargetNodeType == "ct" or sTargetNodeType == "npc" then
		nWounds = DB.getValue(nodeTarget, "wounds", 0)
	end
	if nTotalHP > nWounds and bDead == true then
		EffectManager.addEffect("", "", ActorManager.getCTNode(rTarget), { sName = "FATIGUED", nDuration = 0 }, true)
	end
end

function modFatigued (rSource, rTarget, rRoll)
	local nFatiguedMod, nFatiguedCount = EffectManager5E.getEffectsBonus(rSource, {"FATIGUED"}, true);
	if nFatiguedCount > 0 then
		if nFatiguedMod >= 1 then
			rRoll.nMod = rRoll.nMod - nFatiguedMod
			rRoll.sDesc = rRoll.sDesc .. " [FATIGUED -" .. tostring(nFatiguedMod) .. "]"
		end
	end
end

function customOutputResult(bSecret, rSource, rOrigin, msgLong, msgShort)
	local sSubString = msgLong.text:match("%[vs%.%s*DC%s*%d+%]")
	if sSubString then
		local nFatiguedMod, nFatiguedCount = EffectManager5E.getEffectsBonus(rOrigin, {"FATIGUED"}, true);
		if nFatiguedCount > 0 and nFatiguedMod >= 1 then
				sSubString = sSubString:gsub("%[", "%%[")
				local sModSubString = sSubString  .. "%[FATIGUED -" .. tostring(nFatiguedMod) .. "]"
				msgLong.text=  msgLong.text:gsub(sSubString, sModSubString)
		end
	end
	outputResult(bSecret, rSource, rOrigin, msgLong, msgShort)
end

function customOnCastSave(rSource, rTarget, rRoll)
	local nFatiguedMod, nFatiguedCount = EffectManager5E.getEffectsBonus(rSource, {"FATIGUED"}, true);
	if nFatiguedCount > 0 and nFatiguedMod >= 1 then
		rRoll.nMod = rRoll.nMod - nFatiguedMod
		local sSubString = rRoll.sDesc:match("%[%s*%a+%s*DC%s*%d+%]"):gsub("%[", "%%[")
		local sDC = sSubString:match("(%d+)")
		local sModSubString = sSubString:gsub(sDC, tostring(rRoll.nMod))
		rRoll.sDesc = rRoll.sDesc:gsub(sSubString, sModSubString)
		rRoll.sDesc = rRoll.sDesc .. " [FATIGUED -" .. tostring(nFatiguedMod) .. "]"
	end
	return onCastSave(rSource, rTarget, rRoll)
end

function customCheckModRoll (rSource, rTarget, rRoll)
	modFatigued(rSource, rTarget, rRoll)
	return checkModRoll(rSource, rTarget, rRoll)
end

function customSkillModRoll (rSource, rTarget, rRoll)
	modFatigued(rSource, rTarget, rRoll)
	return skillModRoll(rSource, rTarget, rRoll)
end

function customModAttack(rSource, rTarget, rRoll)
	modFatigued(rSource, rTarget, rRoll)
	return modAttack(rSource, rTarget, rRoll)
end

function customModSave(rSource, rTarget, rRoll)
	modFatigued(rSource, rTarget, rRoll)
	return modSave(rSource, rTarget, rRoll)
end

function customModInit(rSource, rTarget, rRoll)
	modFatigued(rSource, rTarget, rRoll)
	return initModRoll(rSource, rTarget, rRoll)
end
Events.OnGameBoot.Add(print("Skill Recovery Journal: ver:0.4-masscraxx-refactor"))

SRJ = {}

function SRJ.CleanseFalseSkills(gainedXP)
	for skill,xp in pairs(gainedXP) do

		local perkList = PerkFactory.PerkList
		local junk = true

		if xp>1 then
			for i=0, perkList:size()-1 do
				---@type PerkFactory.Perk
				local perk = perkList:get(i)
				if perk and tostring(perk:getType()) == skill then
					junk = false
				end
			end
		end

		if junk then
			gainedXP[skill] = nil
		end
	end
end


---@param player IsoGameCharacter
function SRJ.calculateGainedSkills(player)

	-- calc professtion skills
	local bonusSkillLevels = SRJ.getFreeLevelsFromProfession(player)

	--calc trait skills
	local bonusTraitLevels = SRJ.getFreeLevelsFromTraits(player)

	local gainedXP = {}
	local storingSkills = false

	print("INFO: SkillRecoveryJournal: calculating gained skills:  total skills: "..Perks.getMaxIndex())
	for i=1, Perks.getMaxIndex()-1 do
		---@type PerkFactory.Perks
		local perks = Perks.fromIndex(i)
		if perks then
			---@type PerkFactory.Perk
			local perk = PerkFactory.getPerk(perks)
			if perk then
				local currentXP = player:getXp():getXP(perk)
				local perkType = tostring(perk:getType())
				local bonusLevels = (bonusSkillLevels[perkType] or 0) + (bonusTraitLevels[perkType] or 0)
				local recoverableXPFactor = (SandboxVars.SkillRecoveryJournal.RecoveryPercentage/100) or 1

				local recoverableXP = math.floor(((currentXP-perk:getTotalXpForLevel(bonusLevels))*recoverableXPFactor)*1000)/1000
				if perkType == "Strength" or perkType == "Fitness" or recoverableXP==1 then
					recoverableXP = 0
				end

				print("  "..i.." "..perkType.." = "..tostring(recoverableXP).."xp  (current:"..currentXP.." - "..perk:getTotalXpForLevel(bonusLevels))

				if recoverableXP > 0 then
					gainedXP[perkType] = recoverableXP
					storingSkills = true
				end
				--end
			end
		end
	end

	if not storingSkills then
		return
	end

	return gainedXP
end

function SRJ.getFreeXPFromProfessionAndTraits(player)
	local bonusXP = {}

	-- calc professtion skills
	local bonusSkillLevels = SRJ.getFreeLevelsFromProfession(player)

	--calc trait skills
	local bonusTraitLevels = SRJ.getFreeLevelsFromTraits(player)

	-- convert to xp
	for i=1, Perks.getMaxIndex()-1 do
		local perks = Perks.fromIndex(i)
		if perks then
			---@type PerkFactory.Perk
			local perk = PerkFactory.getPerk(perks)
			if perk then
				local perkString = tostring(perk:getType())
				if bonusSkillLevels[perkString] or bonusTraitLevels[perkString] then
					local bonusLevels = (bonusSkillLevels[perkString] or 0) + (bonusTraitLevels[perkString] or 0)
					local initialXPforPerk = perk:getTotalXpForLevel(bonusLevels)
					bonusXP[perkString] = initialXPforPerk
					print("Initial xp for "..perkString..": "..initialXPforPerk.."->"..(bonusSkillLevels[perkString] or 0).."+"..(bonusTraitLevels[perkString] or 0))
				end
			end
		end
	end

	return bonusXP
end

function SRJ.getFreeLevelsFromProfession(player)
	local bonusLevels = {}

	local playerDesc = player:getDescriptor()
	local playerProfessionID = playerDesc:getProfession()
	local playerProfession = ProfessionFactory.getProfession(playerProfessionID)

	local descXpMap = transformIntoKahluaTable(playerProfession:getXPBoostMap())

	for perk,level in pairs(descXpMap) do
		local perky = tostring(perk)
		if perky ~= "Strength" and perky ~= "Fitness" then
			local levely = tonumber(tostring(level))
			bonusLevels[perky] = levely
		end
	end

	return bonusLevels
end

function SRJ.getFreeLevelsFromTraits(player)
	local bonusLevels = {}
	
	local playerTraits = player:getTraits()
	for i=0, playerTraits:size()-1 do
		local trait = playerTraits:get(i)
		---@type TraitFactory.Trait
		local traitTrait = TraitFactory.getTrait(trait)
		local traitXpMap = transformIntoKahluaTable(traitTrait:getXPBoostMap())

		for perk,level in pairs(traitXpMap) do
			local perky = tostring(perk)
			if perky ~= "Strength" and perky ~= "Fitness" then
				local levely = tonumber(tostring(level))
				bonusLevels[perky] = (bonusLevels[perky] or 0) + levely
			end
		end
	end

	return bonusLevels
end
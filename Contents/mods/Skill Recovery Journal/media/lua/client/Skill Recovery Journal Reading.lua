require "TimedActions/ISBaseTimedAction"

local SRJ = require "Skill Recovery Journal Main"

require "TimedActions/ISBaseTimedAction"

---@class ReadSkillRecoveryJournal : ISBaseTimedAction
ReadSkillRecoveryJournal = ISBaseTimedAction:derive("ReadSkillRecoveryJournal")


function ReadSkillRecoveryJournal:isValid()
	local vehicle = self.character:getVehicle()
	if vehicle and vehicle:isDriver(self.character) then return not vehicle:isEngineRunning() or vehicle:getSpeed2D() == 0 end
	return self.character:getInventory():contains(self.item)
end


function ReadSkillRecoveryJournal:start()
	self.item:setJobType(getText("ContextMenu_Read") ..' '.. self.item:getName())
	--self.item:setJobDelta(0.0)
	self:setAnimVariable("ReadType", "book")
	self:setActionAnim(CharacterActionAnims.Read)
	self:setOverrideHandModels(nil, self.item)

	self.character:setReading(true)
	self.character:reportEvent("EventRead")
end


function ReadSkillRecoveryJournal:forceStop()
	self.character:setReading(false)
	self.item:setJobDelta(0.0)
	if self.action then self.action:setLoopedAction(false) end
	self.character:playSound("CloseBook")
	ISBaseTimedAction.forceStop(self)
end


function ReadSkillRecoveryJournal:perform()
	self.character:setReading(false)
	self.item:getContainer():setDrawDirty(true)
	ISBaseTimedAction.perform(self)
end


function ReadSkillRecoveryJournal:animEvent(event, parameter)
	if event == "PageFlip" then
		if getGameSpeed() ~= 1 then return end
		self.character:playSound("PageFlipBook")
	end
end


function ReadSkillRecoveryJournal:update()

	if not self.loopedAction then return end

	---@type Literature
	local journal = self.item

	local bJournalUsedUp = false

	self.readTimer = (self.readTimer or 0) + (getGameTime():getMultiplier() or 0)
	-- normalize update time via in game time. Adjust updateInterval as needed
	local updateInterval = 10
	if self.readTimer >= updateInterval then
		self.readTimer = 0

		---@type IsoGameCharacter | IsoPlayer | IsoMovingObject | IsoObject
		local player = self.character

		local journalModData = journal:getModData()
		local JMD = journalModData["SRJ"]
		local changesMade = false
		local changesBeingMade = {}
		local delayedStop = false
		local sayText
		local sayTextChoices = {"IGUI_PlayerText_DontUnderstand", "IGUI_PlayerText_TooComplicated", "IGUI_PlayerText_DontGet"}

		local pSteamID = player:getSteamID()

		if (not JMD) then
			delayedStop = true
			sayText = getText("IGUI_PlayerText_NothingWritten")

		elseif self.character:HasTrait("Illiterate") then
			delayedStop = true
			sayText = getText("IGUI_PlayerText_IGUI_PlayerText_Illiterate"..ZombRand(2)+1)-- 0,1 + 1

		elseif pSteamID ~= 0 then
			JMD["ID"] = JMD["ID"] or {}
			local journalID = JMD["ID"]
			if journalID["steamID"] and (journalID["steamID"] ~= pSteamID) then
				delayedStop = true
				sayText = getText("IGUI_PlayerText_DoesntFeelRightToRead")
			end
		end

		if not delayedStop then

			if (#self.learnedRecipes > 0) then

				self.recipeIntervals = self.recipeIntervals+1
				changesMade = true

				if self.recipeIntervals > 5 then
					local recipeChunk = math.min(#self.learnedRecipes, math.floor(1.09^math.sqrt(#self.learnedRecipes)))
					local properPlural = getText("IGUI_Tooltip_Recipe")
					if recipeChunk>1 then properPlural = getText("IGUI_Tooltip_Recipes") end
					table.insert(changesBeingMade, recipeChunk.." "..properPlural)

					for i=0, recipeChunk do
						local recipeID = self.learnedRecipes[#self.learnedRecipes]
						if recipeID then player:learnRecipe(recipeID) end
						table.remove(self.learnedRecipes,#self.learnedRecipes)
					end
					self.recipeIntervals = 0
				end
			end

			local XpStoredInJournal = JMD["gainedXP"]
			local greatestXp = 0

			for skill,xp in pairs(XpStoredInJournal) do
				if skill=="NONE" or skill=="MAX" then
					XpStoredInJournal[skill] = nil
				else
					if xp > greatestXp then greatestXp = xp end
				end
			end

			local xpRate = math.sqrt(greatestXp)/25
			local readXP = SRJ.getReadXP(player)

			journalModData.recoveryJournalXpLog = journalModData.recoveryJournalXpLog or {}
			local jmdUsedXP = journalModData.recoveryJournalXpLog

			local oneTimeUse = (SandboxVars.SkillRecoveryJournal.RecoveryJournalUsed == true)

			for skill,xp in pairs(XpStoredInJournal) do
				if Perks[skill] then

					readXP[skill] = readXP[skill] or 0
					local currentlyReadXP = readXP[skill]
					local journalXP = xp

					if oneTimeUse and jmdUsedXP[skill] and jmdUsedXP[skill] then
						if jmdUsedXP[skill] >= currentlyReadXP then bJournalUsedUp = true end
						currentlyReadXP = math.max(currentlyReadXP, jmdUsedXP[skill])
					end

					if currentlyReadXP < journalXP then
						local readTimeMulti = SandboxVars.SkillRecoveryJournal.ReadTimeSpeed or 1

						local differential = SRJ.getMaxXPDifferential(skill)

						local perkLevelPlusOne = player:getPerkLevel(Perks[skill])+1
						local perPerkXpRate = ((xpRate*math.sqrt(perkLevelPlusOne))*1000)/1000 * readTimeMulti / differential
						if perkLevelPlusOne == 11 then perPerkXpRate=false end

						--print("TESTING:  perPerkXpRate:"..perPerkXpRate.."  perkLevel:"..(perkLevelPlusOne-1).."  xpStored:"..xp.."  currentXP:"..currentlyReadXP)

						if perPerkXpRate~=false then

							if currentlyReadXP+perPerkXpRate > journalXP then perPerkXpRate = math.max(journalXP-currentlyReadXP, 0.001) end

							readXP[skill] = readXP[skill]+perPerkXpRate
							jmdUsedXP[skill] = (jmdUsedXP[skill] or 0)+perPerkXpRate

							---- perksType, XP, passHook, applyXPBoosts, transmitMP)
							player:getXp():AddXP(Perks[skill], perPerkXpRate, false, false, true)
							changesMade = true

							local skill_name = getText("IGUI_perks_"..skill)
							if skill_name == ("IGUI_perks_"..skill) then skill_name = skill end
							table.insert(changesBeingMade, skill_name)
						end
					end
				end
			end
		end

		if JMD and (not changesMade) then
			delayedStop = true

			if bJournalUsedUp then
				sayText = getText("IGUI_JournalXPUsedUp")
			else
				sayTextChoices = {"IGUI_PlayerText_KnowSkill","IGUI_PlayerText_BookObsolete"}
				sayText = getText(sayTextChoices[ZombRand(#sayTextChoices)+1])
			end

		elseif changesMade then
			local changesBeingMadeText = ""
			for k,v in pairs(changesBeingMade) do
				changesBeingMadeText = changesBeingMadeText.." "..v
				if k~=#changesBeingMade then
					changesBeingMadeText = changesBeingMadeText..", "
				end
			end
			if #changesBeingMade>0 then
				changesBeingMadeText = getText("IGUI_Tooltip_Learning")..": "..changesBeingMadeText
			end

			HaloTextHelper:update()
			HaloTextHelper.addText(self.character, changesBeingMadeText, HaloTextHelper.getColorWhite())
		end

		if delayedStop then
			if sayText and not self.spoke then
				self.spoke = true
				player:Say(sayText, 0.55, 0.55, 0.55, UIFont.Dialogue, 0, "default")
			end
			self:forceStop()
		end
	end
end


function ReadSkillRecoveryJournal:new(character, item)
	local o = {}
	setmetatable(o, self)
	self.__index = self

	o.character = character
	o.item = item
	o.stopOnWalk = false
	o.stopOnRun = true
	o.loopedAction = true
	o.ignoreHandsWounds = true
	o.caloriesModifier = 0.5
	o.readTimer = -30
	o.forceProgressBar = true
	o.learnedRecipes = {}
	o.recipeIntervals = 0
	o.maxTime = -1

	local journalModData = item:getModData()
	local JMD = journalModData["SRJ"]
	if JMD then
		if SandboxVars.SkillRecoveryJournal.RecoverRecipes == true then
			local learnedRecipes = JMD["learnedRecipes"]
			if learnedRecipes then
				for recipeID,_ in pairs(learnedRecipes) do
					if not character:isRecipeKnown(recipeID) then
						table.insert(o.learnedRecipes, recipeID)
					end
				end
			end
		end
	end

	return o
end
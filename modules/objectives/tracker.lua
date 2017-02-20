local _, Engine = ...
local Module = Engine:NewModule("ObjectiveTracker")
local L = Engine:GetLocale()
local C = Engine:GetStaticConfig("Data: Colors")

-- Lua API
local _G = _G
local ipairs = ipairs
local math_ceil = math.ceil
local math_huge = math.huge
local math_min = math.min
local pairs = pairs
local select = select
local setmetatable = setmetatable
local string_match = string.match
local string_split = string.split
local table_remove = table.remove
local tonumber = tonumber
local unpack = unpack

-- WoW API
local AddAutoQuestPopUp = _G.AddAutoQuestPopUp
local AddQuestWatch = _G.AddQuestWatch
local C_TaskQuest = _G.C_TaskQuest
local GetAuctionItemClasses = _G.GetAuctionItemClasses
local GetAuctionItemSubClasses = _G.GetAuctionItemSubClasses
local GetContainerItemID = _G.GetContainerItemID
local GetContainerItemLink = _G.GetContainerItemLink
local GetContainerNumSlots = _G.GetContainerNumSlots
local GetContainerNumFreeSlots = _G.GetContainerNumFreeSlots
local GetCurrentMapAreaID = _G.GetCurrentMapAreaID
local GetCVarBool = _G.GetCVarBool
local GetDistanceSqToQuest = _G.GetDistanceSqToQuest
local GetItemSubClassInfo = _G.GetItemSubClassInfo
local GetNumAutoQuestPopUps = _G.GetNumAutoQuestPopUps
local GetAutoQuestPopUp = _G.GetAutoQuestPopUp
local GetNumQuestLogEntries = _G.GetNumQuestLogEntries
local GetNumQuestWatches = _G.GetNumQuestWatches
local GetNumWorldQuestWatches = _G.GetNumWorldQuestWatches
local GetQuestDifficultyColor = _G.GetQuestDifficultyColor
local GetQuestLogIndexByID = _G.GetQuestLogIndexByID
local GetQuestLogIsAutoComplete = _G.GetQuestLogIsAutoComplete
local GetQuestLogSpecialItemInfo = _G.GetQuestLogSpecialItemInfo
local GetQuestLogTitle = _G.GetQuestLogTitle
local GetQuestWatchInfo = _G.GetQuestWatchInfo
local GetQuestWorldMapAreaID = _G.GetQuestWorldMapAreaID
local GetRealZoneText = _G.GetRealZoneText
local GetSuperTrackedQuestID = _G.GetSuperTrackedQuestID
local GetWorldQuestWatchInfo = _G.GetWorldQuestWatchInfo
local IsPlayerInMicroDungeon = _G.IsPlayerInMicroDungeon
local IsWorldQuestWatched = _G.IsWorldQuestWatched
local PlaySound = _G.PlaySound
local QuestHasPOIInfo = _G.QuestHasPOIInfo
local QuestMapFrame_IsQuestWorldQuest = _G.QuestMapFrame_IsQuestWorldQuest
local RemoveQuestWatch = _G.RemoveQuestWatch
local SetMapToCurrentZone = _G.SetMapToCurrentZone
local SetSuperTrackedQuestID = _G.SetSuperTrackedQuestID
local ShowQuestComplete = _G.ShowQuestComplete
local ShowQuestOffer = _G.ShowQuestOffer
local SortQuestWatches = _G.SortQuestWatches
local UnitAffectingCombat = _G.UnitAffectingCombat

-- WoW Frames
local QuestFrame = _G.QuestFrame
local QuestFrameAcceptButton = _G.QuestFrameAcceptButton
local WorldMapFrame = _G.WorldMapFrame

-- WoW Constants
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local NUM_BAG_SLOTS = _G.NUM_BAG_SLOTS

-- Client Constants
local ENGINE_LEGION 	= Engine:IsBuild("Legion")
local ENGINE_WOD 		= Engine:IsBuild("WoD")
local ENGINE_MOP 		= Engine:IsBuild("MoP")
local ENGINE_CATA 		= Engine:IsBuild("Cata")

-- Localized string
local L_ACCEPT = _G.ACCEPT
local L_CONTINUE = _G.CONTINUE
local L_OBJECTIVES = _G.OBJECTIVES_TRACKER_LABEL
local L_QUEST_COMPLETE = _G.QUEST_WATCH_QUEST_READY or _G.QUEST_WATCH_QUEST_COMPLETE or _G.QUEST_COMPLETE
local L_QUEST = ENGINE_LEGION and GetItemSubClassInfo(_G.LE_ITEM_CLASS_QUESTITEM, (select(1, GetAuctionItemSubClasses(_G.LE_ITEM_CLASS_QUESTITEM)))) or ENGINE_CATA and 	(select(10, GetAuctionItemClasses())) or (select(12, GetAuctionItemClasses())) or "Quest" -- the fallback isn't actually needed

-- Create search patterns from these later on, 
-- to better parse quest objectives and figure out what we need, 
-- what has changed, what events to look out for and so on. 

--QUEST_SUGGESTED_GROUP_NUM = "Suggested Players [%d]";
--QUEST_SUGGESTED_GROUP_NUM_TAG = "Group: %d";
--QUEST_FACTION_NEEDED = "%s:  %s / %s";
--QUEST_ITEMS_NEEDED = "%s: %d/%d";
--QUEST_MONSTERS_KILLED = "%s slain: %d/%d";
--QUEST_OBJECTS_FOUND = "%s: %d/%d";
--QUEST_PLAYERS_KILLED = "Players slain: %d/%d";
--QUEST_FACTION_NEEDED_NOPROGRESS = "%s:  %s";
--QUEST_INTERMEDIATE_ITEMS_NEEDED = "%s: (%d)";
--QUEST_ITEMS_NEEDED_NOPROGRESS = "%s x %d";
--QUEST_MONSTERS_KILLED_NOPROGRESS = "%s x %d";
--QUEST_OBJECTS_FOUND_NOPROGRESS = "%s x %d";
--QUEST_PLAYERS_KILLED_NOPROGRESS = "Players x %d";

-- Blank texture used as a fallback for borders and bars
local BLANK_TEXTURE = [[Interface\ChatFrame\ChatFrameBackground]] 
local BUTTON_SIZE = 40 
local BUTTON_BACKDROP = {
	bgFile = BLANK_TEXTURE,
	edgeFile = BLANK_TEXTURE,
	edgeSize = 1,
	insets = {
		left = -1,
		right = -1,
		top = -1,
		bottom = -1
	}
}

-- Constant indicating the tracker needs an additional update.
local NEED_UPDATE

-- Constant to avoid auto tracking new quests
local IGNORE_QUEST

local questData = {} -- quest status and objectives by questID 

local allTrackedQuests = {} -- all tracked quests
local zoneTrackedQuests = {} -- quests auto tracked by zone
local userTrackedQuests = {} -- quests manually tracked by the user

local itemButtons = {} -- item button cache, mostly for easier naming

local scheduledForRemoval = {} -- temporary cache for quests no longer tracked 
local scheduledForTracking = {} -- temporary cache for quests to be tracked


-- Here we correct incorrect mapIDs for various quests. 
-- Will move this to the settings file later on, 
-- keeping it here for now.
-- 
-- MapIDs retrieved from: http://wow.gamepedia.com/MapID
local questMapIDOverrides = {
	[13789] = 492, 		-- Taking The Battle To The Enemy
	[14096] = 492 		-- You've Really Done It This Time, Kul
}


-- Utility functions and stuff
-----------------------------------------------------

-- Set a message and calculate it's best size for display
-- Have to revisit this one, as it's far from perfect, 
-- doesn't count words or spaces, and fails miserably 
-- at times which ends up with too few lines and truncated text.
local setTextAndGetSize = function(fontString, msg, minWidth, minHeight)
	fontString:Hide() -- hide the madness we're about to do

	local lineSpacing = fontString:GetSpacing()
	local newWidth, newHeight

	-- Max the text size for proper calculations
	fontString:SetWidth(minWidth * 6) 
	fontString:SetHeight(minHeight * 6 + lineSpacing*5)

	-- Set the title text
	fontString:SetText(msg)

	-- Get the current, full, untruncated text pixel width
	local fontStringWidth = fontString:GetStringWidth()

	-- Figure out the height and lines of the title text
	if fontStringWidth > minWidth then
		-- The minHeight*10 addition to the string width 
		-- is an attempt to make up for the fact that words 
		-- have different lengths, and some lines will be longer 
		-- than others. 
		local numLines = math_ceil((fontStringWidth + minHeight*10) / minWidth) 

		newHeight = minHeight*numLines + numLines*lineSpacing
		newWidth = math_min(minWidth, math_ceil(fontStringWidth / numLines) + (fontStringWidth / 5))
	end

	fontString:SetSize(newWidth or minWidth, newHeight or minHeight) -- set our new sizes
	fontString:Show() -- show the fontstring again

	-- return the sizes as well
	return newWidth or minWidth, newHeight or minHeight, lineSpacing
end

-- Create a square/dot used for unfinished objectives (and the completion texts)
local createDot = function(parent)
	local dot = parent:CreateFrame("Frame")
	dot:SetSize(10, 10)
	dot:SetBackdrop(BUTTON_BACKDROP)
	dot:SetBackdropColor(0, 0, 0, .75)
	dot:SetBackdropBorderColor( 240/255, 240/255, 240/255, .85)
	return dot
end



-- Maximize/Minimize button Template
-----------------------------------------------------
local MinMaxButton = Engine:CreateFrame("Button")
MinMaxButton_MT = { __index = MinMaxButton }

MinMaxButton.OnClick = function(self, mouseButton)
	if self:IsEnabled() then
		if (self.currentState == "maximized") then
			self.body:Hide()
			self.currentState = "minimized"
			PlaySound("igQuestListClose")
		else
			self.body:Show()
			self.currentState = "maximized"
			PlaySound("igQuestListOpen")
		end
	end	
	self:UpdateLayers()
end

MinMaxButton.UpdateLayers = function(self)
	if self:IsEnabled() then
		--if (self:GetAttribute("currentState") == "maximized") then
		if (self.currentState == "maximized") then
			if self:IsMouseOver() then
				self.minimizeTexture:SetAlpha(0)
				self.minimizeHighlightTexture:SetAlpha(1)
				self.maximizeTexture:SetAlpha(0)
				self.maximizeHighlightTexture:SetAlpha(0)
				self.disabledTexture:SetAlpha(0)
			else
				self.minimizeTexture:SetAlpha(1)
				self.minimizeHighlightTexture:SetAlpha(0)
				self.maximizeTexture:SetAlpha(0)
				self.maximizeHighlightTexture:SetAlpha(0)
				self.disabledTexture:SetAlpha(0)
			end
		else
			if self:IsMouseOver() then
				self.minimizeTexture:SetAlpha(0)
				self.minimizeHighlightTexture:SetAlpha(0)
				self.maximizeTexture:SetAlpha(0)
				self.maximizeHighlightTexture:SetAlpha(1)
				self.disabledTexture:SetAlpha(0)
			else
				self.minimizeTexture:SetAlpha(0)
				self.minimizeHighlightTexture:SetAlpha(0)
				self.maximizeTexture:SetAlpha(1)
				self.maximizeHighlightTexture:SetAlpha(0)
				self.disabledTexture:SetAlpha(0)
			end
		end
	else
		self.minimizeTexture:SetAlpha(0)
		self.minimizeHighlightTexture:SetAlpha(0)
		self.maximizeTexture:SetAlpha(0)
		self.maximizeHighlightTexture:SetAlpha(0)
		self.disabledTexture:SetAlpha(1)
	end
end



-- Item Template
-----------------------------------------------------
local Item = Engine:CreateFrame("Button")
Item_MT = { __index = Item }

local Container = Engine:CreateFrame("Frame")
Container_MT = { __index = function(self, bagID)
	self[bagID] = self:CreateFrame("Frame")
	self[bagID]:SetID(bagID)
	return self[bagID]
end }


-- Entry Title (clickable button)
-----------------------------------------------------
local Title = Engine:CreateFrame("Button")
Title_MT = { __index = Title }

Title.OnClick = function(self, mouseButton)
	local questLogIndex = self._owner.questLogIndex

	--local questLogIndex = GetQuestLogIndexByID(owner.questID)
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
		local questLink = GetQuestLink(questLogIndex)
		if questLink then
			ChatEdit_InsertLink(questLink)
		end
	elseif not(mouseButton == "RightButton") then
		CloseDropDownMenus()
		if (ENGINE_WOD) then
			QuestLogPopupDetailFrame_Show(questLogIndex)
		else
			QuestLog_OpenToQuest(questLogIndex)
		end
	end
end


-- Entry Template (tracked quests, achievements, etc)
-----------------------------------------------------
local Entry = Engine:CreateFrame("Frame")
Entry_MT = { __index = Entry }

-- Creates a new objective element
Entry.AddObjective = function(self, objectiveType)
	local objectives = self.objectives

	local objective = self:CreateFrame("Frame")
	objective:SetHeight(.0001)

	-- Objective text
	local msg = objective:CreateFontString()
	msg:SetHeight(objectives.standardHeight)
	msg:SetWidth(self:GetWidth() - objectives.leftMargin - objectives.rightMargin)
	msg:Point("TOP", 0, 0)
	msg:Point("LEFT", objectives.leftMargin, 0)
	msg:Point("RIGHT", -objectives.rightMargin, 0)
	msg:SetDrawLayer("BACKGROUND")
	msg:SetJustifyH("LEFT")
	msg:SetJustifyV("TOP")
	msg:SetIndentedWordWrap(false)
	msg:SetWordWrap(true)
	msg:SetNonSpaceWrap(false)
	msg:SetFontObject(objectives.normalFont)
	msg:SetSpacing(objectives.lineSpacing)

	-- Unfinished objective dot
	local dot = createDot(objective)
	dot:Place("TOP", msg, "TOPLEFT", -floor(objectives.leftMargin/2), objectives.dotAdjust)

	objective.msg = msg
	objective.dot = dot

	return objective
end

local UIHider = CreateFrame("Frame")
UIHider:Hide()

-- Creates a new quest item element
Entry.AddQuestItem = function(self)
	local config = self.config
	local num = #itemButtons + 1
	local name = "Engine_QuestItemButton"..num

	local item = setmetatable(self:CreateFrame("Button", name, ENGINE_WOD and "QuestObjectiveItemButtonTemplate" or "WatchFrameItemButtonTemplate"), Item_MT)
	item:Hide()

	-- We just clean out everything from the old template, 
	-- as we're really only after its inherited functionality.
	-- The looks and elements will be manually created by us instead.
	if ENGINE_WOD then
		for i,key in ipairs({ "Cooldown", "Count", "icon", "HotKey", "NormalTexture" }) do
			local exists = item[key]
			if exists then
				exists:SetParent(UIHider)
				exists:Hide()
			end
		end
	else
		for i,key in ipairs({ "Cooldown", "Count", "HotKey", "IconTexture", "NormalTexture", "Stock" }) do
			local exists = _G[name..key]
			if exists then
				exists:SetParent(UIHider)
				exists:Hide()
			end
		end
	end

	item:SetScript("OnUpdate", nil)
	item:SetScript("OnEvent", nil)
	item:UnregisterAllEvents()
	item:SetPushedTexture("")
	item:SetHighlightTexture("")

	item:SetSize(config.body.entry.item.size[1], config.body.entry.item.size[2])
	item:SetFrameLevel(self:GetFrameLevel() + 10) -- gotta get it above the title button

	local glow = item:CreateFrame("Frame")
	glow:SetFrameLevel(item:GetFrameLevel())
	glow:SetPoint("CENTER", 0, 0)
	glow:SetSize(config.body.entry.item.glow.size[1], config.body.entry.item.glow.size[2])
	glow:SetBackdrop(config.body.entry.item.glow.backdrop)
	glow:SetBackdropColor(0, 0, 0, 0)
	glow:SetBackdropBorderColor(0, 0, 0, .75)

	local overlay = item:CreateFrame("Frame")
	overlay:SetFrameLevel(item:GetFrameLevel() + 1)
	overlay:SetPoint("CENTER", 0, 0)
	overlay:SetSize(config.body.entry.item.border.size[1], config.body.entry.item.border.size[2])
	overlay:SetBackdrop(config.body.entry.item.border.backdrop)
	overlay:SetBackdropColor(0, 0, 0, .75)
	overlay:SetBackdropBorderColor(C.General.UIBorder[1], C.General.UIBorder[2], C.General.UIBorder[3], .85)

	local newIconTexture = overlay:CreateTexture()
	newIconTexture:SetDrawLayer("BORDER")
	newIconTexture:SetPoint("CENTER", 0, 0)
	newIconTexture:SetSize(22, 22)

	local newIconDarken = overlay:CreateTexture()
	newIconDarken:SetDrawLayer("ARTWORK")
	newIconDarken:SetAllPoints(newIconTexture)
	newIconDarken:SetColorTexture(0, 0, 0, .15)

	local newIconShade = overlay:CreateTexture()
	newIconShade:SetDrawLayer("OVERLAY")
	newIconShade:SetAllPoints(newIconTexture)
	newIconShade:SetTexture(config.body.entry.item.shade)
	newIconShade:SetVertexColor(0, 0, 0, 1)
	
	item.SetItemTexture = function(self, ...)
		newIconTexture:SetTexture(...)
	end

	item:Show()

	-- test
	--local tex = item:CreateTexture()
	--tex:SetColorTexture(0, 0, 0, .5)
	--tex:SetAllPoints()

	itemButtons[num] = item

	return item
end

-- Updates an objective, and adds new ones as needed
Entry.SetObjective = function(self, objectiveID)
	local objectives = self.objectives
	local objective = objectives[objectiveID] or self:AddObjective()
	local currentQuestData = questData[self.questID] 
	local currentQuestObjectives = currentQuestData.questObjectives[objectiveID]

	local width, height = setTextAndGetSize(objective.msg, currentQuestObjectives.description, objectives.standardWidth, objectives.standardHeight)
	objective:SetHeight(height)
	objective:Show()

	-- Update the pointer in case it's a new objective, 
	-- or the order got changed(?) (gotta revisit this)
	objectives[objectiveID] = objective

	return objective
end

-- Clears an objective
Entry.ClearObjective = function(self, objectiveID)
	local objective = self.objectives[objectiveID]
	if (not objective) then
		return
	end
	objective.msg:SetText("")
	objective:ClearAllPoints()
	objective:Hide()
end

-- Clears all displayed objectives
Entry.ClearObjectives = function(self)
	local objectives = self.objectives
	for objectiveID = #objectives,1,-1 do
		self:ClearObjective(objectiveID)
	end
end

-- Sets the questID of the current tracker entry
Entry.SetQuest = function(self, questLogIndex, questID)
	local entryHeight = 0.0001

	-- Set the IDs of this entry, and thus tell the tracker it's in use
	self.questID = questID
	self.questLogIndex = questLogIndex

	-- Grab the data about the current quest
	local currentQuestData = questData[questID]

	-- Shortcuts to our own elements
	local title = self.title
	local titleText = self.title.msg
	local body = self.body
	local completionText = self.completionText

	-- Set and size the title
	local titleWidth, titleHeight = setTextAndGetSize(titleText, currentQuestData.questTitle, title:GetWidth(), title.standardHeight)
	title:SetHeight(titleHeight) -- set the size of the title frame as well

	entryHeight = entryHeight + titleHeight

	-- Update objective descriptions and completion text
	if currentQuestData.isComplete then
		if (not currentQuestData.hasBeenCompleted) then
			-- Clear away all objectives
			self:ClearObjectives()

			-- No need repeating this step
			currentQuestData.hasBeenCompleted = true
		end

		-- Change quest description to the completion text
		local completeMsg = (currentQuestData.completionText and currentQuestData.completionText ~= "") and currentQuestData.completionText or L_QUEST_COMPLETE
		local width, height = setTextAndGetSize(completionText, completeMsg, completionText.standardWidth, completionText.standardHeight)
		completionText.dot:Show()

		entryHeight = entryHeight + completionText.topMargin + height + completionText.bottomMargin

	else
		-- Just make sure the completion text is hidden
		completionText:SetText("")
		completionText:SetSize(completionText.standardWidth, completionText.standardHeight)
		completionText.dot:Hide()

		-- Update the current or remaining quest objectives
		local objectives = self.objectives
		local objectiveOffset = objectives.topOffset
		local currentQuestObjectives = currentQuestData.questObjectives

		local visibleObjectives = 0
		local numObjectives = #currentQuestObjectives

		if numObjectives > 0 then
			for objectiveID = 1, numObjectives  do
				-- Only display unfinished quest objectives
				if (not currentQuestObjectives[objectiveID].isCompleted) then
					local objective = self:SetObjective(objectiveID)

					-- Since the order and visibility of the objectives 
					-- change based on the visible ones, we need to reset
					-- all the points here, or the objective will "disappear".
					objective:ClearAllPoints()
					objective:Point("TOP", self.title, "BOTTOM", 0, -objectiveOffset)
					objective:Point("LEFT", 0, 0)
					objective:Point("RIGHT", 0, 0)

					local height = objectives.topMargin + objective:GetHeight()
					objectiveOffset = objectiveOffset + height
					entryHeight = entryHeight + height

					visibleObjectives = visibleObjectives + 1
				end
			end
			entryHeight = entryHeight + objectives.bottomMargin
		end

		-- A lot of quests in especially in the Cata (and higher) starting zones are 
		-- of the "go to some NPC"-type, has no objectives, and are finished the instant they start.
		-- For some reason though they still get counted as not finished in my tracker,
		-- so we simply squeeze in a slightly more descriptive text here. 
		if visibleObjectives == 0 then
			-- Change quest description to the completion text
			local completeMsg = (currentQuestData.completionText and currentQuestData.completionText ~= "") and currentQuestData.completionText or L_QUEST_COMPLETE
			local width, height = setTextAndGetSize(completionText, completeMsg, completionText.standardWidth, completionText.standardHeight)
			completionText.dot:Show()

			entryHeight = entryHeight + completionText.topMargin + height + completionText.bottomMargin
		end

		-- Clear finished objectives (or remnants from previously tracked quests)
		for objectiveID = numObjectives + 1, #self.objectives do
			self:ClearObjective(objectiveID)
		end
	end

	self:SetHeight(entryHeight)

end

-- Sets which quest item to display along with the quest entry
-- *Todo: add support for equipped items too! 
Entry.SetQuestItem = function(self)
	local item = self.questItem or self:AddQuestItem()
	item:SetID(self.questLogIndex)
	item:Place("TOPRIGHT", -(10), 0)
	item:SetItemTexture(questData[self.questID].icon)
	item:Show()

	self.questItem = item

	return questItem
end

Entry.UpdateQuestItem = function(self)
end

-- Removes any item currently connected with the entry's current quest.
Entry.ClearQuestItem = function(self)
	local item = self.questItem
	if item then
		item:Hide()
	end
end

-- Returns the questID of the entry's current quest, or nil if none.
Entry.GetQuestID = function(self)
	return self.questID
end

-- Clear the entry
Entry.Clear = function(self)
	self.questID = nil
	self.questLogIndex = nil

	-- Clear the messages 
	self.title.msg:SetText("")
	self.completionText:SetText("")

	-- Clear the quest item, if any
	self:ClearQuestItem()

	-- Clear away all objectives
	self:ClearObjectives()	
end



-- Tracker Template
-----------------------------------------------------
local Tracker = Engine:CreateFrame("Frame")
Tracker_MT = { __index = Tracker }

Tracker.AddEntry = function(self)
	local config = self.config

	local entry = setmetatable(self.body:CreateFrame("Frame"), Entry_MT)
	entry:Hide()
	entry:SetHeight(0.0001)
	entry:SetWidth(self:GetWidth())
	entry.config = config
	entry.topMargin = config.body.entry.topMargin
	
	-- Title region
	-----------------------------------------------------------
	local title = setmetatable(entry:CreateFrame("Button"), Title_MT)
	title:Point("TOP", 0, 0)
	title:Point("LEFT", 0, 0)
	title:Point("RIGHT", 0, 0)
	title:SetWidth(self:GetWidth() - config.body.entry.title.leftMargin - config.body.entry.title.rightMargin)
	title:SetHeight(config.body.entry.title.height)
	title.standardHeight = config.body.entry.title.height
	title.maxLines = config.body.entry.title.maxLines -- not currently used
	title.leftMargin = config.body.entry.title.leftMargin
	title.rightMargin = config.body.entry.title.rightMargin

	title._owner = entry
	title:EnableMouse(true)
	title:RegisterForClicks("LeftButtonUp")
	title:SetScript("OnClick", Title.OnClick)

	-- Quest title
	local titleText = title:CreateFontString()
	titleText:SetHeight(title.standardHeight)
	titleText:SetWidth(self:GetWidth() - config.body.entry.title.leftMargin - config.body.entry.title.rightMargin)
	titleText:Place("TOPLEFT", 0, 0)
	titleText:SetDrawLayer("BACKGROUND")
	titleText:SetJustifyH("LEFT")
	titleText:SetJustifyV("TOP")
	titleText:SetIndentedWordWrap(false)
	titleText:SetWordWrap(true)
	titleText:SetNonSpaceWrap(false)
	titleText:SetFontObject(config.body.entry.title.normalFont)
	titleText:SetSpacing(config.body.entry.title.lineSpacing)

	title.msg = titleText

	-- Flash messages like "NEW", "UPDATE", "COMPLETED" and so on
	local flashMessage = title:CreateFontString()
	flashMessage:SetDrawLayer("BACKGROUND")
	flashMessage:SetPoint("RIGHT", title, "LEFT", 0, -10)



	-- Body region
	-----------------------------------------------------------
	local body = entry:CreateFrame("Frame")
	body:SetWidth(self:GetWidth())
	body:Point("TOP", title, "BOTTOM", 0, config.body.margins.top)
	body:Point("LEFT", config.body.margins.left, 0)
	body:Point("RIGHT", config.body.margins.right, 0)

	-- Quest complete text
	local completionText = body:CreateFontString()
	completionText.leftMargin = config.body.entry.complete.leftMargin
	completionText.rightMargin = config.body.entry.complete.rightMargin
	completionText.topMargin = config.body.entry.complete.topMargin
	completionText.bottomMargin = config.body.entry.complete.bottomMargin
	completionText.lineSpacing = config.body.entry.complete.lineSpacing
	completionText.standardHeight = config.body.entry.complete.height
	completionText.standardWidth = self:GetWidth() - completionText.leftMargin - completionText.rightMargin
	completionText.maxLines = config.body.entry.complete.maxLines -- not currently used
	completionText.dotAdjust = config.body.entry.complete.dotAdjust

	completionText:SetFontObject(config.body.entry.complete.normalFont)
	completionText:SetSpacing(completionText.lineSpacing)
	completionText:SetWidth(self:GetWidth() - completionText.leftMargin - completionText.rightMargin)
	completionText:SetHeight(completionText.standardHeight)
	completionText:Point("TOP", title, "BOTTOM", 0, -completionText.topMargin)
	completionText:Point("LEFT", completionText.leftMargin, 0)
	completionText:Point("RIGHT", -completionText.rightMargin, 0)
	completionText:SetDrawLayer("BACKGROUND")
	completionText:SetJustifyH("LEFT")
	completionText:SetJustifyV("TOP")
	completionText:SetIndentedWordWrap(false)
	completionText:SetWordWrap(true)
	completionText:SetNonSpaceWrap(false)

	completionText.dot = createDot(body)
	completionText.dot:Place("TOP", completionText, "TOPLEFT", -floor(completionText.leftMargin/2), completionText.dotAdjust)
	completionText.dot:Hide()

	-- Cache of the current quest objectives
	local objectives = {
		standardHeight = config.body.entry.objective.height,
		standardWidth = self:GetWidth() - config.body.entry.objective.leftMargin - config.body.entry.objective.rightMargin,
		topOffset = config.body.entry.objective.topOffset,
		leftMargin = config.body.entry.objective.leftMargin,
		rightMargin = config.body.entry.objective.rightMargin,
		topMargin = config.body.entry.objective.topMargin,
		bottomMargin = config.body.entry.objective.bottomMargin,
		lineSpacing = config.body.entry.objective.lineSpacing,
		normalFont = config.body.entry.objective.normalFont,
		dotAdjust = config.body.entry.objective.dotAdjust
	} 

	entry.body = body
	entry.completionText = completionText
	entry.flash = flashMessage
	entry.objectives = objectives
	entry.title = title

	-- test
	--local tex = entry:CreateTexture()
	--tex:SetColorTexture(0, 0, 0, .5)
	--tex:SetAllPoints()	

	return entry
end

-- Full tracker update.
Tracker.Update = function(self)
	local entries = self.entries
	local numEntries = #entries
	local numZoneQuests = #zoneTrackedQuests

	local maxTrackerHeight = self:GetHeight()
	local currentTrackerHeight = self.header:GetHeight() + 4

	-- Update existing and create new entries
	local anchor = self.header
	for i = 1, numZoneQuests do

		-- Get the zone quest data
		local zoneQuest = zoneTrackedQuests[i]

		-- Sometimes the events collide or something, 
		-- and we end up calling this right after the questData
		-- has been deleted, thus resulting in a nil error up 
		-- in the SetQuest() method. 
		-- Trying to avoid this now.
		if questData[zoneQuest.questID] then
			local currentQuestData = questData[zoneQuest.questID]

			-- Get the entry or create on
			local entry = entries[i] or self:AddEntry()

			-- Set the entry's quest
			entry:SetQuest(zoneQuest.questLogIndex, zoneQuest.questID)
			
			-- Set the entry's usable item, if any
			if currentQuestData.hasQuestItem and ((not currentQuestData.isComplete) or currentQuestData.showItemWhenComplete) then
				entry:SetQuestItem()
			else
				entry:ClearQuestItem()
			end

			-- Update entry pointer
			entries[i] = entry

			-- Don't show more entries than there's room for,
			-- forcefully quit and hide the rest when it would overflow.
			-- Will add a better system later.
			if ((currentTrackerHeight + entry.topMargin + entry:GetHeight()) > maxTrackerHeight) then
				numZoneQuests = i-1
				break
			else
				currentTrackerHeight = currentTrackerHeight + entry.topMargin + entry:GetHeight()

				entry:Place("TOPLEFT", anchor, "BOTTOMLEFT", 0, -entry.topMargin)
				entry:Show()
				anchor = entry
			end
		else
			-- hide finished entries
			local entry = entries[i]
			if entry then
				entry:Hide()
				entry:Clear()
				entry:ClearAllPoints() 
			end
		end
	end

	-- Hide unused entries
	for i = numZoneQuests + 1, numEntries do
		local entry = entries[i]
		entry:Hide()
		entry:Clear()
		entry:ClearAllPoints() 
	end

end



-- Parse the quest log for quests and items valid in the current zone, 
-- track the quests in the current zone, and untrack others. 
-- Tracking mostly relates to map POI functionality, 
-- and won't affect what our own tracker actually shows. 
Module.ParseQuests = function(self, event)
	local tracker = self.tracker

	-- GetQuestWorldMapAreaID() sets the map to the current zone, 
	-- so to avoid the WorldMap being "locked", we have to queue 
	-- updates to when it's hidden again. 
	-- This will pause our tracker when it's visible, 
	-- but hopefully it won't be a problem. 
	-- Will write additional code to simply update existing quests 
	-- in the future, thus keeping the tracker updated if the user 
	-- chooses to have the map visible while questing. 
	if WorldMapFrame:IsShown() then
		NEED_UPDATE = true
		return
	end
	
	-- Set the map to the current zone
	if ENGINE_WOD then
		local inMicroDungeon = IsPlayerInMicroDungeon()
		if inMicroDungeon ~= self.inMicroDungeon then
			self.inMicroDungeon = inMicroDungeon
			if (not WorldMapFrame:IsShown()) and GetCVarBool("questPOI") then
				SetMapToCurrentZone()
			end
			SortQuestWatches()
		end
	else 
		if (not WorldMapFrame:IsShown()) and GetCVarBool("questPOI") then
			SetMapToCurrentZone()
		end
		SortQuestWatches()
	end

	-- figure out the current mapID
	local mapID, isContinent = GetCurrentMapAreaID() 
	if (not ENGINE_CATA) then
		mapID = mapID - 1 -- WotLK bug
	end

	-- Retrieve number of entries in the game quest log
	local numEntries, numQuests = GetNumQuestLogEntries()

	-- Parse the quest log
	for questLogIndex = 1, numEntries do

		-- The questTag return value (could be stuff like "PVP") got removed in WoD
		local questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID
		if ENGINE_WOD then
			questTitle, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(questLogIndex)
		else
			questTitle, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(questLogIndex)
		end

		-- This was previously a 0/1 return, but now is true/nil
		if ((isHeader == 0) or (not isHeader)) then
			
			-- Trying to fix a problem with QuestFrameAcceptButton 
			-- when auto-accepting quests and the window remains open 
			-- with the button saying "accept", even though it's already accepted!
			-- This is not the same bug as when manually completed quests in WotLK
			-- remain open, so I'll have to figure out something else for them.
			if ENGINE_CATA and (QuestFrame:IsShown() and (GetQuestID() == questID)) then
				local button = QuestFrameAcceptButton
				local msg = button:GetText()
				if (msg == L_ACCEPT) then
					button:SetText(L_CONTINUE)
				end
			end

			-- Figure out if the quest is in our current zone or not
			local mapId, floorNumber = GetQuestWorldMapAreaID(questID)
			if (((mapID == mapId) or questMapIDOverrides[questID]) and (not (questID == IGNORE_QUEST))) then
				local currentQuestData = questData[questID] or {}

				if isComplete then
					-- If the quest is complete, we only show the completion text ("Return to blabla" etc)
					local completionText = GetQuestLogCompletionText(questLogIndex)

					currentQuestData.isComplete = true
					currentQuestData.questObjectives = nil -- just remove the whole objectives table
					currentQuestData.completionText = completionText 

				else
					local difficultyColor = GetQuestDifficultyColor(level)
					local questObjectives = currentQuestData.questObjectives or {}

					-- Parse objectives for our tracker entries
					local numQuestLogLeaderBoards = GetNumQuestLeaderBoards(questLogIndex)
					for i = 1, numQuestLogLeaderBoards do
						local description, objectiveType, isCompleted = GetQuestLogLeaderBoard(i, questLogIndex)

						-- Should parse the description and objectiveType here 
						-- to figure out items, rep, money needed and so on,
						-- so we more easily can track changes to objectives. 
						questObjectives[i] = {
							description = description,
							objectiveType = objectiveType,
							isCompleted = isCompleted
						}
					end

					-- Can't really imagine why a quest's number of objectives should 
					-- change after creation, but just in case we wipe away any unneeded entries.
					-- Point is that we're using #questObjectives to determine number of objectives.
					for i = #questObjectives, numQuestLogLeaderBoards + 1, -1 do
						questObjectives[i] = nil
					end

					-- put the data into our cache
					currentQuestData.isComplete = nil
					currentQuestData.completionText = nil
					currentQuestData.questObjectives = questObjectives 

					-- Figure out if there's an item connected to the quest
					local link, icon, charges, showItemWhenComplete = GetQuestLogSpecialItemInfo(questLogIndex) -- only an iconID in Legion, not a texture link
					if icon and ((not isComplete) or showItemWhenComplete) then
		
						-- Parse the bags for the item if one exists
						local itemID, bag, slot
						local itemString = string_match(link, "item[%-?%d:]+")
						if itemString then
							itemID = tonumber((select(2, string_split(":", itemString))))
						end

						for bagID = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
							local numberOfFreeSlots, bagType = GetContainerNumFreeSlots(bagID)
							local numberOfSlots = GetContainerNumSlots(bagID)

							if bagType == 0 then -- assuming only "normal" bags have quest items
								for slotID = 1, numberOfSlots do

									if itemID then
										local itemId = GetContainerItemID(bagID, slotID)
										if itemId == itemID then
											bag, slot = bagID, slotID
											break
										end
									end

									-- In case the itemID was missing, or for some reason don't match
									-- I doubt this will ever be true
									local itemLink = GetContainerItemLink(bagID, slotID)
									if itemLink == link then
										bag, slot = bagID, slotID
										break
									end

								end
							end
							if bag and slot then
								break
							end
						end
						
						-- An item was found in the bags.
						if bag and slot then
							currentQuestData.hasQuestItem = true
							currentQuestData.showItemWhenComplete = showItemWhenComplete
							currentQuestData.bagID = bag
							currentQuestData.slotID = slot
							currentQuestData.icon = icon
						else
							-- Check quipped items with /use effects 
							-- if nothing was found in the bags.
						end
					end
				end

				-- put the rest of the data into the cache
				currentQuestData.questTitle = questTitle
				currentQuestData.level = level
				currentQuestData.questTag = questTag
				currentQuestData.suggestedGroup = suggestedGroup
				currentQuestData.isDaily = isDaily or frequency

				-- update pointer in case it was a newly added quest
				questData[questID] = currentQuestData
				
				-- Queue it up to be added later
				scheduledForTracking[#scheduledForTracking + 1] = { 
					questLogIndex = questLogIndex, 
					questID = questID 
				}
			else
				-- Debugging of quests not showing up
				-- I'm using this to update my mapID override table as needed.
				--print("not tracking (quest mapID, current mapID, questID, title):")
				--print(mapId, mapID, questID, questTitle)
				--print(" ")

				-- Queue it up to be removed later
				scheduledForRemoval[#scheduledForRemoval + 1] = { 
					questLogIndex = questLogIndex, 
					questID = questID 
				}
			end
		end
	end

	-- Delete the cache of quests not currently active, 
	-- to avoid the cache growing too much in long leveling sessions.
	for questID in pairs(questData) do
		local found
		for i in ipairs(scheduledForTracking) do
			if scheduledForTracking[i].questID == questID then
				found = true
				break
			end
		end
		if (not found) then
			questData[questID] = nil
		end
	end

	-- Remove quests from other zones
	for i = #scheduledForRemoval,1,-1 do
		local questLogIndex = scheduledForRemoval[i].questLogIndex
		local questID = scheduledForRemoval[i].questID

		-- Remove our own tracking
		for i = #zoneTrackedQuests,1,-1 do
			local zoneQuest = zoneTrackedQuests[i]
			if (zoneQuest.questID == questID) then
				table_remove(zoneTrackedQuests, i)
				break
			end
		end
		
		-- Remove the blizzard quest watch
		RemoveQuestWatch(questLogIndex)
		
		-- Clear the entry to avoid chaos and mixups
		scheduledForRemoval[i] = nil
	end

	-- Add quests in the current zone
	for i = #scheduledForTracking,1,-1 do
		local questLogIndex = scheduledForTracking[i].questLogIndex
		local questID = scheduledForTracking[i].questID

		local zoneQuestID
		for i = 1,#zoneTrackedQuests do
			local zoneQuest = zoneTrackedQuests[i]
			if (zoneQuest.questID == questID) then
				zoneQuestID = i
				break
			end
		end
		if (not zoneQuestID) then
			zoneTrackedQuests[#zoneTrackedQuests + 1] = {
				questLogIndex = questLogIndex,
				questID = questID
			}
		end

		-- Add blizzard tracking for map and POI systems
		AddQuestWatch(questLogIndex)

		-- Clear the entry to avoid facepalms
		scheduledForTracking[i] = nil
	end

	-- Update the tracker entries
	self:UpdateTracker()

	-- Hide it if we have no quests in the current zone
	self:UpdateTrackerVisibility()

	-- Supertracking!
	-- Our own current version just supertracks whatever is closest,
	-- but we will improve this in the future to allow better control.
	--
	-- *The supertracking is actually unrelated to the tracker currently, 
	-- but since we block the blizzard code for this, we need to add something back.
	if ENGINE_CATA then
		self:UpdateSuperTracking()
	end

	-- Reset the forced update flag
	NEED_UPDATE = nil
end

Module.UpdateTracker = function(self)
	self.tracker:Update()
end

-- Should only be done out of combat. 
-- To have more control we user our own combat tracking system here, 
-- instead of relying on the Engine's secure wrapper handler.  
Module.UpdateTrackerVisibility = function(self)
	if UnitAffectingCombat("player") then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
	else
		local tracker = self.tracker
		if #zoneTrackedQuests > 0 then
			if (not tracker:IsShown()) then
				tracker:Show()
			end
		else
			if tracker:IsShown() then
				tracker:Hide()
			end
		end
	end	
end



-- Super tracking. Blizzard copies, mostly.
-- *Some of these are currently unused, but I copied them 
-- for future reference, as I plan to expand and improve 
-- this system a lot in the future.  
----------------------------------------------------------------
local PENDING_QUEST_ID

Module.QuestSuperTracking_OnQuestTracked = function(self, questID)
	-- We should supertrack quest if it got added to the top of the tracker
	-- First check if we have POI info. Could be missing if 1) we didn't know about this quest before, 2) just doesn't have POIs
	if QuestHasPOIInfo(questID) then
		SetSuperTrackedQuestID(questID)
		PENDING_QUEST_ID = nil
	else
		-- no POI info, could be arriving later
		PENDING_QUEST_ID = questID
	end
end

Module.QuestSuperTracking_OnQuestCompleted = function(self)
	self:QuestSuperTracking_ChooseClosestQuest()
end

Module.QuestSuperTracking_OnQuestUntracked = function(self)
	self:QuestSuperTracking_ChooseClosestQuest()
end

Module.QuestSuperTracking_OnPOIUpdate = function(self)
	-- if we were waiting on data for an added quest, we should supertrack it if it has POI data and it's at the top of the tracker
	if (PENDING_QUEST_ID and QuestHasPOIInfo(PENDING_QUEST_ID)) then
		SetSuperTrackedQuestID(PENDING_QUEST_ID)
	elseif (GetSuperTrackedQuestID() == 0) then
		-- otherwise pick something if we're not supertrack anything
		self:QuestSuperTracking_ChooseClosestQuest()
	end
	PENDING_QUEST_ID = nil
end

Module.QuestSuperTracking_ChooseClosestQuest = function(self)
	local closestQuestID
	local minDistSqr = math_huge

	-- World quest watches got introduced in Legion
	if ENGINE_LEGION then
		for i = 1, GetNumWorldQuestWatches() do
			local watchedWorldQuestID = GetWorldQuestWatchInfo(i)
			if watchedWorldQuestID then
				local distanceSq = C_TaskQuest.GetDistanceSqToQuest(watchedWorldQuestID)
				if distanceSq and distanceSq <= minDistSqr then
					minDistSqr = distanceSq
					closestQuestID = watchedWorldQuestID
				end
			end
		end
	end
	
	if ENGINE_WOD then
		if ( not closestQuestID ) then
			for i = 1, GetNumQuestWatches() do
				local questID, title, questLogIndex = GetQuestWatchInfo(i)
				if ( questID and QuestHasPOIInfo(questID) ) then
					local distSqr, onContinent = GetDistanceSqToQuest(questLogIndex)
					if ( onContinent and distSqr <= minDistSqr ) then
						minDistSqr = distSqr
						closestQuestID = questID
					end
				end
			end
		end
	end

	-- If nothing with POI data is being tracked expand search to quest log
	if ( not closestQuestID ) then
		for questLogIndex = 1, GetNumQuestLogEntries() do
			local title, level, suggestedGroup, isHeader, isCollapsed, isComplete, frequency, questID = GetQuestLogTitle(questLogIndex)
			if (not isHeader and QuestHasPOIInfo(questID)) then
				local distSqr, onContinent = GetDistanceSqToQuest(questLogIndex)
				if (onContinent and distSqr <= minDistSqr) then
					minDistSqr = distSqr
					closestQuestID = questID
				end
			end
		end
	end

	-- Supertrack if we have a valid quest
	if closestQuestID then
		SetSuperTrackedQuestID(closestQuestID)
	else
		SetSuperTrackedQuestID(0)
	end
end

Module.QuestSuperTracking_IsSuperTrackedQuestValid = function(self)
	local trackedQuestID = GetSuperTrackedQuestID()
	if trackedQuestID == 0 then
		return false
	end

	if (GetQuestLogIndexByID(trackedQuestID) == 0) then
		-- Might be a tracked world quest that isn't in our log yet
		if QuestMapFrame_IsQuestWorldQuest(trackedQuestID) and IsWorldQuestWatched(trackedQuestID) then
			return C_TaskQuest.IsActive(trackedQuestID)
		end
		return false
	end

	return true
end

Module.QuestSuperTracking_CheckSelection = function(self)
	if (not self:QuestSuperTracking_IsSuperTrackedQuestValid()) then
		self:QuestSuperTracking_ChooseClosestQuest()
	end
end

-- Fairly big copout here, and we need to expand 
-- on it later to avoid overriding user choices. 
Module.UpdateSuperTracking = function(self)
	self:QuestSuperTracking_ChooseClosestQuest()
end

Module.ParseAutoQuests = function(self)
	for i = 1, GetNumAutoQuestPopUps() do
		local questID, popUpType = GetAutoQuestPopUp(i)
		if (questId == questID) then
			if (popUpType == "OFFER") then
				ShowQuestOffer(questLogIndex)

			elseif (popUpType == "COMPLETE") then
				PlaySound("UI_AutoQuestComplete")
				ShowQuestComplete(questLogIndex)
			end
		end
	end
end

Module.OnEvent = function(self, event, ...)
	if event == "PLAYER_ALIVE" then
		-- This event is only wanted prior to MoP, 
		-- and we only want it the initial time it fires 
		-- since this indicates that quest data is available.
		self:UnregisterEvent("PLAYER_ALIVE", "OnEvent")

	elseif event == "PLAYER_ENTERING_WORLD" then

		-- parse auto quest popups
		if ENGINE_CATA then
			self:ParseAutoQuests()
		end

	elseif event == "QUEST_LOG_UPDATE" then

	--elseif event == "PLAYER_MONEY" then
		-- Should track quests requiring money, 
		-- and return if the player doesn't have any such. 

	elseif event == "PLAYER_REGEN_ENABLED" then

		-- We only want this event to be active when something 
		-- actually changed on the quest item bar while in combat. 
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		self:UpdateTrackerVisibility()

	--elseif event == "ZONE_CHANGED" then

	elseif event == "ZONE_CHANGED_NEW_AREA" then

		-- parse auto quest popups
		if ENGINE_CATA then
			self:ParseAutoQuests()
		end
	

	elseif event == "BAG_UPDATE" then
		--self:ScanBags()

		return
	
	elseif event == "UNIT_INVENTORY_CHANGED" then

		return

	elseif event == "QUEST_POI_UPDATE" then -- cata
		self:UpdateSuperTracking()
		return

	elseif event == "QUEST_AUTOCOMPLETE" then -- cata

		-- Cata auto completion and auto offering of quests
		local questId = ...
		local questLogIndex = GetQuestLogIndexByID(questId)

		PlaySound("UI_AutoQuestComplete")
		ShowQuestComplete(questLogIndex)

		return
	end

	self:ParseQuests(event)
end

Module.ForceUpdate = function(self, event, ...)
	if (event == "WORLDMAP_HIDE") then
		if NEED_UPDATE then
			self:ParseQuests()
		end
	end
end

Module.OnInit = function(self)
	self.config = self:GetStaticConfig("Objectives").tracker
	self.db = self:GetConfig("ObjectiveTracker") -- user settings. will save manually tracked quests here later.

	local config = self.config


	-- Tracker visibility layer
	-----------------------------------------------------------
	-- The idea here is that we simply do NOT want it visible while in an arena, 
	-- or while engaged in a boss fight.  
	-- We want as little clutter and distractions as possible during those 
	-- types of fights, and the quest tracker is simply just in the way then. 
	-- Same goes for pet battles in MoP and beyond. 
	local visibility = Engine:CreateFrame("Frame", nil, "UICenter", "SecureHandlerAttributeTemplate")
	if ENGINE_MOP then
		RegisterStateDriver(visibility, "visibility", "[petbattle][@boss1,exists][@arena1,exists]hide;show")
	else
		RegisterStateDriver(visibility, "visibility", "[@boss1,exists][@arena1,exists]hide;show")
	end

	-- Tracker frame
	-----------------------------------------------------------
	local tracker = setmetatable(visibility:CreateFrame("Frame"), Tracker_MT)
	tracker:SetFrameStrata("MEDIUM")
	tracker:SetFrameLevel(15)
	tracker.config = config
	tracker.entries = {} -- table to hold entries

	for i,point in ipairs(config.points) do
		tracker:Point(unpack(point))
	end

	-- Header region
	-----------------------------------------------------------
	local header = tracker:CreateFrame("Frame")
	header:SetHeight(config.header.height)
	for i,point in ipairs(config.header.points) do
		header:Point(unpack(point))
	end

	-- Tracker title
	local title = header:CreateFontString()
	title:SetDrawLayer("BACKGROUND")
	title:SetFontObject(config.header.title.normalFont)
	title:Place(unpack(config.header.title.position))
	title:SetText(L_OBJECTIVES)

	-- Maximize/minimize button
	-- This needs to be secure, so we can use it to allow the user 
	-- to toggle the tracker visibility while engaged in combat, 
	-- even though the tracker contains secure actionbuttons 
	-- and otherwise can't be changed in combat. 
	-- I would write the whole trackre in secure code if I could, 
	-- but the API simply doesn't exist for that, so we compromise.
	local button = setmetatable(header:CreateFrame("Button"), MinMaxButton_MT)
	--local button = setmetatable(header:CreateFrame("Button", nil, "SecureHandlerClickTemplate"), MinMaxButton_MT)
	button:SetSize(unpack(config.header.button.size))
	button:Place(unpack(config.header.button.position))
	button:EnableMouse(true)
	button:RegisterForClicks("LeftButtonDown")

	local buttonMinimizeTexture = button:CreateTexture()
	buttonMinimizeTexture:SetAlpha(0)
	buttonMinimizeTexture:SetDrawLayer("BORDER")
	buttonMinimizeTexture:SetSize(unpack(config.header.button.textureSize))
	buttonMinimizeTexture:Place(unpack(config.header.button.texturePosition))
	buttonMinimizeTexture:SetTexture(config.header.button.textures.enabled)
	buttonMinimizeTexture:SetTexCoord(unpack(config.header.button.texcoords.minimized))

	local buttonMinimizeHighlightTexture = button:CreateTexture()
	buttonMinimizeHighlightTexture:SetAlpha(0)
	buttonMinimizeHighlightTexture:SetDrawLayer("BORDER")
	buttonMinimizeHighlightTexture:SetSize(unpack(config.header.button.textureSize))
	buttonMinimizeHighlightTexture:Place(unpack(config.header.button.texturePosition))
	buttonMinimizeHighlightTexture:SetTexture(config.header.button.textures.enabled)
	buttonMinimizeHighlightTexture:SetTexCoord(unpack(config.header.button.texcoords.minimizedHighlight))

	local buttonMaximizeTexture = button:CreateTexture()
	buttonMaximizeTexture:SetAlpha(0)
	buttonMaximizeTexture:SetDrawLayer("BORDER")
	buttonMaximizeTexture:SetSize(unpack(config.header.button.textureSize))
	buttonMaximizeTexture:Place(unpack(config.header.button.texturePosition))
	buttonMaximizeTexture:SetTexture(config.header.button.textures.enabled)
	buttonMaximizeTexture:SetTexCoord(unpack(config.header.button.texcoords.maximized))

	local buttonMaximizeHighlightTexture = button:CreateTexture()
	buttonMaximizeHighlightTexture:SetAlpha(0)
	buttonMaximizeHighlightTexture:SetDrawLayer("BORDER")
	buttonMaximizeHighlightTexture:SetSize(unpack(config.header.button.textureSize))
	buttonMaximizeHighlightTexture:Place(unpack(config.header.button.texturePosition))
	buttonMaximizeHighlightTexture:SetTexture(config.header.button.textures.enabled)
	buttonMaximizeHighlightTexture:SetTexCoord(unpack(config.header.button.texcoords.maximizedHighlight))

	local buttonDisabledTexture = button:CreateTexture()
	buttonDisabledTexture:SetAlpha(0)
	buttonDisabledTexture:SetDrawLayer("BORDER")
	buttonDisabledTexture:SetSize(unpack(config.header.button.textureSize))
	buttonDisabledTexture:Place(unpack(config.header.button.texturePosition))
	buttonDisabledTexture:SetTexture(config.header.button.textures.disabled)
	buttonDisabledTexture:SetTexCoord(unpack(config.header.button.texcoords.disabled))

	button.minimizeTexture = buttonMinimizeTexture
	button.minimizeHighlightTexture = buttonMinimizeHighlightTexture
	button.maximizeTexture = buttonMaximizeTexture
	button.maximizeHighlightTexture = buttonMaximizeHighlightTexture
	button.disabledTexture = buttonDisabledTexture

	-- Body region
	-----------------------------------------------------------
	local body = tracker:CreateFrame("Frame")
	body:Point("TOPLEFT", header, "BOTTOMLEFT", 0, -4)
	body:Point("TOPRIGHT", header, "BOTTOMRIGHT", 0, -4)
	body:Point("BOTTOMLEFT", 0, 0)
	body:Point("BOTTOMRIGHT", 0, 0)


	-- Apply scripts
	-----------------------------------------------------------
	-- These are mostly for visual stuff, anything else is 
	-- done through the secure state drivers and click handlers. 
	button.body = body
	button.currentState = "maximized" -- todo: save this between sessions(?)

	button:SetScript("OnEnter", MinMaxButton.UpdateLayers)
	button:SetScript("OnLeave", MinMaxButton.UpdateLayers)
	button:SetScript("OnEnable", MinMaxButton.UpdateLayers)
	button:SetScript("OnDisable", MinMaxButton.UpdateLayers)
	button:SetScript("OnClick", MinMaxButton.OnClick)
	button:UpdateLayers()
	

	-- test
	--local tex = body:CreateTexture()
	--tex:SetColorTexture(0, 0, 0, .5)
	--tex:SetAllPoints()

	tracker.header = header
	tracker.body = body
	
	self.tracker = tracker

end

Module.OnEnable = function(self)

	-- kill off the blizzard objectives tracker 
	local BlizzardUI = self:GetHandler("BlizzardUI")
	BlizzardUI:GetElement("ObjectiveTracker"):Disable()
	BlizzardUI:GetElement("Menu_Option"):Remove(true, "InterfaceOptionsObjectivesPanelWatchFrameWidth")

	self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEvent")
	self:RegisterEvent("PLAYER_MONEY", "OnEvent")
	self:RegisterEvent("QUEST_LOG_UPDATE", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED", "OnEvent")
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "OnEvent")

	self:RegisterEvent("BAG_UPDATE", "OnEvent")
	self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnEvent")

	if (not ENGINE_MOP) then
		self:RegisterEvent("PLAYER_ALIVE", "OnEvent")
	end

	if ENGINE_CATA then
		self:RegisterEvent("QUEST_AUTOCOMPLETE", "OnEvent")
		self:RegisterEvent("QUEST_POI_UPDATE", "OnEvent")
	end

	-- Our quest parser will forcefully keep the WorldMapFrame set to the current zone, 
	-- so currently we're queueing updates to when the map is hidden. 
	WorldMapFrame:HookScript("OnHide", function() self:ForceUpdate("WORLDMAP_HIDE") end)


	--[[
	self:RegisterEvent("SCENARIO_CRITERIA_UPDATE", "OnEvent")
	self:RegisterEvent("SCENARIO_SPELL_UPDATE", "OnEvent")
	self:RegisterEvent("SCENARIO_UPDATE", "OnEvent")
	self:RegisterEvent("TRACKED_ACHIEVEMENT_LIST_CHANGED", "OnEvent")
	self:RegisterEvent("TRACKED_ACHIEVEMENT_UPDATE", "OnEvent") 
	self:RegisterEvent("VARIABLES_LOADED", "OnEvent") -- don't think I need this for anything
	]]

end

-----------------------------------------------------------------------------------------------
-- Client Lua Script for QuestTrackerTweaks
-- Copyright (c) Ilazki. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- QuestTrackerTweaks Module Definition
-----------------------------------------------------------------------------------------------
local QuestTrackerTweaks = {}

-----------------------------------------------------------------------------------------------
-- Init
-----------------------------------------------------------------------------------------------
function QuestTrackerTweaks:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

    -- initialize variables here

    return o
end

function QuestTrackerTweaks:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
	   "QuestTracker",
	   "SimpleQuestTracker",    -- Try to load after SQT to inject tweaks.  No idea if it works.
	   "QuestTracker_CRB",      -- Local copy of Carbine's tracker for edits and testing. Unused
	                            -- outside of development.
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end


-----------------------------------------------------------------------------------------------
-- OnLoad & OnDocLoaded
-----------------------------------------------------------------------------------------------
function QuestTrackerTweaks:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("QuestTrackerTweaks.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function QuestTrackerTweaks:OnDocumentReady()
	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "QuestTrackerRightClick", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

	    self.wndMain:Show(false, true)

		--- Replace QuestTracker's right click menu
    self.ReplaceQTRightClick()
	end
end


function QuestTrackerTweaks:OnDependencyError(dep, err)
--- QuestTracker is only hard dependnecy; don't freak out over SQT or my copy of CRB's tracker
   if dep ~= "QuestTracker" then return true end
   return true
   
end

   

-----------------------------------------------------------------------------------------------
-- Other Functions
-----------------------------------------------------------------------------------------------

--- This function adds an Abandon handler to QuestTracker, loads a modified rightclick form,
--- and overrides QuestTracker:ShowRightClick() to use the new form and handler.
function QuestTrackerTweaks.ReplaceQTRightClick()
   QuestTracker = Apollo.GetAddon("QuestTracker") or Apollo.GetAddon("QuestTracker_CRB")
   if not QuestTracker then return nil end

	--- Add an "Abandon" handler method to the QuestTracker
	function QuestTracker:OnRightClickAbandonBtn( wndHandler, wndControl)
		local queQuest = wndHandler:GetData()
    --- Unpin before abandoning to avoid some pinned quests crashing the tracker.
    self.tPinned.tQuests[queQuest:GetId()] = nil

	 	queQuest:SetActiveQuest(false)
		queQuest:Abandon()
		self:OnQuestTrackerRightClickClose()

	end
	--- Load the replacement Form and set a couple variables the normal tracker uses internally
	--- since they aren't accesible here.
	local rightClickReplace = Apollo.GetAddon("QuestTrackerTweaks").xmlDoc
	local knXCursorOffset = 10
	local knYCursorOffset = 25

	--- Mostly duplicated from the Carbine quest tracker.
  --- Changed or added lines are commented with "--- Ilazki" so I know what to edit whenever
  --- I need to update the function with changed Carbine code.
	function QuestTracker:ShowQuestRightClick(queQuest)
		self:OnQuestTrackerRightClickClose()

		self.wndQuestRightClick = Apollo.LoadForm(rightClickReplace, "QuestTrackerRightClick", nil, self)	--- Ilazki
		self.wndQuestRightClick:FindChild("RightClickOpenLogBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickShareQuestBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickLinkToChatBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickMaxMinBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickPinUnpinBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickHideBtn"):SetData(queQuest)
		self.wndQuestRightClick:FindChild("RightClickAbandonBtn"):SetData(queQuest)							--- Ilakzi

		self.wndQuestRightClick:FindChild("RightClickShareQuestBtn"):Enable(queQuest:CanShare())

		local nQuestId = queQuest:GetId()
		local bAlreadyMinimized = nQuestId and self.tMinimized.tQuests[nQuestId]
		self.wndQuestRightClick:FindChild("RightClickMaxMinBtn"):SetText(bAlreadyMinimized and Apollo.GetString("QuestTracker_Expand") or Apollo.GetString("QuestTracker_Minimize"))
		self.wndQuestRightClick:FindChild("RightClickMaxMinBtn"):Enable(queQuest and queQuest:GetState() ~= Quest.QuestState_Botched)

		local bAlreadyPinned = nQuestId and self.tPinned.tQuests[nQuestId]
		self.wndQuestRightClick:FindChild("RightClickPinUnpinBtn"):SetText(bAlreadyPinned and Apollo.GetString("QuestTracker_Unpin") or Apollo.GetString("QuestTracker_Pin"))

		local tCursor = Apollo.GetMouse()
		local nWidth = self.wndQuestRightClick:GetWidth()
		self.wndQuestRightClick:Move(tCursor.x - nWidth + knXCursorOffset, tCursor.y - knYCursorOffset, nWidth, self.wndQuestRightClick:GetHeight())
	end
end

-----------------------------------------------------------------------------------------------
-- QuestTrackerTweaksForm Functions
-----------------------------------------------------------------------------------------------
local QuestTrackerTweaksInst = QuestTrackerTweaks:new()
QuestTrackerTweaksInst:Init()

-----------------------------------------------------------------------------------------------
-- QuestTrackerTweaks Instance
-----------------------------------------------------------------------------------------------
local QuestTrackerTweaksInst = QuestTrackerTweaks:new()
QuestTrackerTweaksInst:Init()

-----------------------------------------------------------------------------------------------
-- Client Lua Script for QuestTrackerTweaks
-- Copyright (c) Ilazki. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"

-----------------------------------------------------------------------------------------------
-- QuestTrackerTweaks Module Definition, Constants, & Forward Declarations
-----------------------------------------------------------------------------------------------
local QuestTrackerTweaks = {}

--- Forward declarations
local returnQuestTracker

--- Constants used internally by QuestTracker that must be recreated here for overriden bits.
local knXCursorOffset = 10
local knYCursorOffset = 25

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
    -- load QTT's form file
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
		local QT = returnQuestTracker()
		if QT then
		   self:ReplaceQTRightClick(QT)
		   self:ReplaceHintArrowHelper(QT)
		   -- Something to experiment with to tweak performance/responsiveness tradeoff.
		   -- Not ready to use it yet.
		   -- QT.timerRealTimeUpdate = ApolloTimer.Create(10.0, true, "OnRealTimeUpdateTimer", self)
		   -- QT.timerRealTimeUpdate:Stop()
		end
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

--- Returns a QuestTracker object to mangle.  Avoids adding multi-addon checks each function.
returnQuestTracker = function()
   return Apollo.GetAddon("QuestTracker") or Apollo.GetAddon("QuestTracker_CRB")
end

----------------------------
-- ReplaceHintArrowHelper
----------------------------

--- Overrides the Hint Arrow Helper to add more user-friendly behaviour.  In this version, if
--- the selected objective is completed, it selects the first uncompleted objective in the
--- same quest.  This makes more sense than the Carbine version selecting the overarching
--- quest because it makes the interact key more useful for quest pointing.
--- Acts the same as Carbine's version in any other case.
function QuestTrackerTweaks:ReplaceHintArrowHelper(QuestTracker)
   --- The new QuestTracker function.
   function QuestTracker:HelperSelectInteractHintArrowObject(oCur, wndBtn)

	  --- Takes one quest argument and returns two:
	  ---  1: the QuestTracker's objWnd UI element for the quest's first uncompleted Objective
	  ---  2: the index vale of the Objective.

	  --- local function to avoid extra-deep nesting.  QT code is already bad enough about it
	  --- without me contributing to the mess in here.
	  local function getObjectiveWnd(currentQuest)
		 local questID   = currentQuest:GetId()
		 local objCount  = currentQuest:GetObjectiveCount()
		 for i = 0, objCount - 1 do
			local objKey = questID .. "O" .. i   --- QT caches objective info in a table using
			                                     --- Quest ID + Objective Index
			                                     --- Format: qqqqOi, with uppercase o as a
			                                     --- separator between quest ID and index.
			local objWnd = self.tObjectiveWndCache[objKey]
			if objWnd and currentQuest:GetObjectiveCompleted(i) == 0 then return objWnd end
		 end
	  end

	  --- Carbine code, umodified
	  local oInteractObject = GameLib.GetInteractHintArrowObject()
	  if not oInteractObject or (oInteractObject and oInteractObject.eHintArrowType == GameLib.CodeEnumHintType.None) then
		 return
	  end

	  local bIsInteractHintArrowObject = oInteractObject.objTarget and oInteractObject.objTarget == oCur
	  if bIsInteractHintArrowObject and not wndBtn:IsChecked() then

		 --- Try to get the objWnd object for an uncompleted sibling Objective to the current quest.
		 --- If successful, selects that Objective as the new quest object.  
		 local objWnd, objIndex = getObjectiveWnd(oCur)
		 if objWnd then
			objWnd.wndObjective:FindChild("QuestObjectiveBtn"):SetCheck(true)
			GameLib.SetInteractHintArrowObject(oCur, objIndex)
		 else
			--- Otherwise, revert to Carbine's behaviour.
			wndBtn:SetCheck(true)
		 end
	 
	  end
   end
   
end

-------------------------
-- ReplaceQTRightClick
-------------------------

--- This function adds an Abandon handler to QuestTracker, loads a modified rightclick form,
--- and overrides QuestTracker:ShowRightClick() to use the new form and handler.
function QuestTrackerTweaks:ReplaceQTRightClick(QuestTracker)
   --- Add an "Abandon" handler method to the QuestTracker that gets called by the new popup
	function QuestTracker:OnRightClickAbandonBtn( wndHandler, wndControl)
		local queQuest = wndHandler:GetData()
    --- Unpin quest before abandoning to avoid some pinned quests crashing the tracker.
    self.tPinned.tQuests[queQuest:GetId()] = nil

	 	queQuest:SetActiveQuest(false)
		queQuest:Abandon()
		self:OnQuestTrackerRightClickClose()

	end
	--- Load the replacement Form and set a couple variables the normal tracker uses internally
	--- since they aren't accesible here.
	local rightClickReplace = Apollo.GetAddon("QuestTrackerTweaks").xmlDoc

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

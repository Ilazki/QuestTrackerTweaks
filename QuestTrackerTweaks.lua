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
local returnQuestTracker   -- Returns the Quest Tracker object
local qtswap = {}          -- Holds all the replacement functions to merge

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

		--- Start mutating the Quest Tracker
		local QT = returnQuestTracker()
		if QT then
		   -- Merge in any functions in qtswap first.
		   for k,v in pairs(qtswap) do
			  QT[k] = v
		   end

		   -- Any other changes that need to be made go here.
		   
		   -- Something to experiment with to tweak performance/responsiveness tradeoff.
		   -- Not ready to use it yet.
--		    QT.timerRealTimeUpdate = ApolloTimer.Create(3.0, true, "OnRealTimeUpdateTimer", self)
--		    QT.timerRealTimeUpdate:Stop()
		end
	end
end


function QuestTrackerTweaks:OnDependencyError(dep, err)
--- QuestTracker is only hard dependency; don't freak out over SQT or my test copy of CRB's tracker
   if dep ~= "QuestTracker" then return true end
--   return true
   
end

   

-----------------------------------------------------------------------------------------------
-- Other Functions
-----------------------------------------------------------------------------------------------

--- Returns a QuestTracker object to mangle.  Avoids adding multi-addon checks each function.
returnQuestTracker = function()
   return Apollo.GetAddon("QuestTracker") or Apollo.GetAddon("QuestTracker_CRB")
end



function qtswap:Reset()
   self:BuildAll()
   self:ResizeAll()
end
   
function qtswap:Derp(str)
   Print("Derp: " .. tostring(str))
end


----------------------------
-- Replace OnStateChanged
----------------------------

-- REASONS
--  1. Usability:  accepting a new quest should not obliterate existing tracked quest.
--  2. Bug:  accepting new quests results in multiple selected quests in default tracker.

function qtswap:OnQuestStateChanged(queQuest, eState)
   local oInteractObject       = GameLib.GetInteractHintArrowObject() or {}
   local hintObjIsQuest        = oInteractObject.eHintArrowType == GameLib.CodeEnumHintType.Quest
   local hintObjIsCurrentQuest = hintObjIsQuest and oInteractObject.objTarget:GetId() == queQuest:GetId()

   -- Destroy quest and wipe hint arrows if the quest is no longer in achieved or accepted states.
   if eState ~= Quest.QuestState_Achieved and eState ~= Quest.QuestState_Accepted then
	  self:DestroyQuest(queQuest)
	  if hintObjIsCurrentQuest then
		 GameLib.SetInteractHintArrowObject(nil) end
	  self.timerResizeDelay:Start()
	  return
   end

   -- Quest is achieved or accepted and should be drawn.
   
   -- This check is what was causing the multi-selection problem by drawing new
   --   hint arrows without clearing previous.  It was unwanted behaviour if
   --   already targeting a quest any way, so I now check and only apply new
   --   hint arrow if the hint arrow was a non-quest.

   if eState == Quest.QuestState_Accepted then
	  --Add new quests to saved hint arrow.
	  if not hintObjIsQuest then  -- Don't obliterate existing quest hints.
		 GameLib.SetInteractHintArrowObject(queQuest) end
   end
   self:DrawQuest(queQuest)
   self.timerResizeDelay:Start()
end

----------------------------
-- ReplaceHintArrowHelper
----------------------------

-- TODO:  Refactor the Carbine code for readability.

-- REASONS
--  1. Usability:  completing the selected quest objective should select a sibling objective,
--       not the objective's parent quest.  This makes the interact key more useful for questing.

function qtswap:HelperSelectInteractHintArrowObject(oCur, wndBtn)

   --- Takes one quest argument and returns two:
   ---  1: the QuestTracker's objWnd UI element for the quest's first uncompleted Objective
   ---  2: the index vale of the Objective.
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
	  --  Possibly too conservative, because it's not selecting new objectives that replace
	  --    just-completed objectives in same quest.  
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

---------------------------------------------
-- Replace ShowQuestRightClick
--   and new OnRightClickAbandonBtn handler
---------------------------------------------

--- Add an "Abandon" handler method to the QuestTracker that gets called by the new popup
function qtswap:OnRightClickAbandonBtn( wndHandler, wndControl)
   local queQuest = wndHandler:GetData()
   --- Unpin quest before abandoning to avoid some pinned quests crashing the tracker.
   self.tPinned.tQuests[queQuest:GetId()] = nil

   queQuest:SetActiveQuest(false)
   queQuest:Abandon()
   self:OnQuestTrackerRightClickClose()

end


-- TODO:  Refactor Carbine's code for readability.

--- Mostly duplicated from the Carbine quest tracker.
--- Changed or added lines are commented with "--- Ilazki" so I know what to edit whenever
--- I need to update the function with changed Carbine code.
function qtswap:ShowQuestRightClick(queQuest)
   self:OnQuestTrackerRightClickClose()
   --- Load the replacement Form 
   local rightClickReplace = Apollo.GetAddon("QuestTrackerTweaks").xmlDoc

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

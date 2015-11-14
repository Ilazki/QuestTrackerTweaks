## About Quest Tracker Tweaks

This addon is the home for any changes or bugfixes I make to the default Carbine QuestTracker for Wildstar.  It works by overloading parts of the default Quest Tracker with new code to add features or fix problems.  The goal is to improve the quality of Carbine's tracker without diverging from its design.  Extreme changes will be avoided here, though I may try making a 100% new tracker later as a side project.

So far it doesn't seem to add any major bugs to the tracker that I can find, but it's hard to be sure because the Carbine tracker is already pretty buggy.  Bug reports and feature requests welcome.

This addon *may* work with Simple Quest Tracker, but consider it untested and unsupported.  YMMV.

## Features

* Add an "Abandon" menu entry to the tracker's right-click popup menu, underneath the "Hide" button.  No need to use the quest log to drop quests any more.
* Changed the behaviour of objective selection when completing a selected objective.  When the selected objective is completed, the tracker now attempts to select the first uncompleted objective within the same quest.  If this fails it reverts to the default tracker behaviour of selecting the quest itself.


## Future Ideas
These are things I'm considering doing if feasible:
* Extra checks for the quest filtering.  It mostly works as-is but does some weird things when "indoors"
* Optional auto-pinning of nearby quests
* Improve the tracker's information density somehow.  There's a lot of extra space that could be reduced, and also the possibility of doing tricks like auto-collapsing quests outside of a configurable range.
* Try to improve performance.
* Fix some of Carbine's tracker bugs, if possible.

## Download

Either use the Releases link or get it from [Curse](http://www.curse.com/ws-addons/wildstar/237916-quest-tracker-tweaks)

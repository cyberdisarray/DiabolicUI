# DiabolicUI Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).

## [Unreleased][1.1.26] 2017-02-21
### Added
- Added custom scaling options.
- Added PvP Capture Bars.
- Added WorldState info (Battleground scores, World PvP score, dungeon waves, etc) to the minimap. 
- Added a new point based resource system for all classes using such. This also fixes the Rogue combo point bugs.  

### Changed
- Side actionbars have changed layout and position, and won't interfere with the quest tracker anymore.

## [1.1.25] 2017-02-21
### Changed
- The custom DiabolicUI font objects will now change to region specific versions of the Google Noto font for zhCN, zhTW and koKR realms.

## [1.1.24] 2017-02-21
### Changed
- The default scaling of DiabolicUI will now better fit most screen resolutions.
- The target NamePlate (Legion only) will now be kept below the target unitframe and above the bottom actionbars.
- Mirror timers (breath, fatigue, etc) now has a dark background and a spark, and looks more like the castbars and unitframes.

## [1.1.23b] 2017-02-20
### Changed
- Temporarily disabled the combo point display for Rogues in MoP and above, since this turned out to be bugged.

## [1.1.23] 2017-02-20
### Fixed
- Fixed a bug in the QuestTracker that would lock the WorldMapFrame to the current zone 

## [1.1.22] 2017-02-19
### Added
- Added Noto fonts for zhCN, zhTW and koKR regions. 
- Added a custom and for the time being completely automatic quest tracker. No support for achievements yet, but it's coming!
- Added a new large, square semi-transparent Minimap in true Diablo III style.
- Added text based LFG/PvP/GroupFinder elements to the Minimap.
- Added information about group/solo status, dungeon size or territory PvP status (Contested, Alliance, Horde, Sanctuary etc) to the Minimap.
- Added information about a player's average item level, gear and specialization to the tooltip when holding down the Shift key.
- Added NamePlates. They currently only displays health and level, but more will be added.
- Added buffs and debuffs to the Target frame.
- Added Player buffs and debuffs, placed above the action bars. 
- Added health values to the unit tooltip health bar.
- Added spell name and cast timer to the Target cast bar.
- Added cast timer to the Player cast bar.
- Added subtle background shades to the target, tot, focus and pet unitframes, to make them easier to see on both light and dark backgrounds.
- Added subtle background shades to the player castbar and also the warning and objective texts to make them too stand more out when visible. 
- Added UI sounds when clicking the chat- and menu buttons in the corners.
- Added UI sounds when showing or hiding action bars.
- Added UI sounds when targeting something and canceling your target. 
- Added more methods to our custom Orb- and StatusBar UI widgets.

### Changed
- Health values are visible at all times on the Target Frame now, making it far easier to decide what kind of mob or opponent you are currently facing.
- Health and power values above the Player orbs are now both visible in combat and on mouseover, so you more easily can track your own resources. 
- Added a descriptive text (Health, Rage, Mana, etc) to the Player orbs which will be visible on mouseover. 
- Power bars on the target frame will now remain visible even when empty if the target is a player.
- Red warnings and yellow quest objective updates are now displayed more centered, closer to the character. 
- Minimap rotation is now forcefully turned off, as rotation is incompatible with a square Minimap.
- The Game Menu (Esc) centers itself vertically upon display now (if out of combat), making it centered regardless of number of buttons or game client version.
- The player health orb is now colored by your current character class.
- The player power orb is now split in two for classes and specs that currently have mana in addition to another primary resource.
- Changed, corrected and upgraded a lot of the class- and power colors, both the single bar colors and the multi layered orb colors. 
- Changed the git folder structure to treat the root folder as the main addon folder. 
- Changed from the DejaVu font family to Noto, as Noto has variations with support for all WoW's client locales.
- Split the static module setups and default user settings into separate folders, to make the addon easier to understand for other developers and enthusiasts. 
- Did a lot of performance tweaks both to the core engine and the modules.

### Fixed
- Fixed a bug where the chat bubbles sometimes would bug out if other addons had added child frames to the WorldFrame.
- The XP bar now properly hides when entering player frame vehicles like the chairs at the Pilgrim's Bounty tables.
- Actionbuttons should now properly reflect if the target of the action is out of range.
- Actionbutton icons are now colored by priority: unusable > out of range > usable > not enough mana > unusable for other reasons.
- Fixed a bug in the core Engine that would prevent modules from getting ADDON_LOADED events.

### Removed
- Removed the old, round temporary Minimap that pretty much was just a slightly reskinned version of the Minimap from Goldpaw's UI. 
- Removed the Blizzard Order Hall bar (Legion). A custom one will be added later.
- Removed the Blizzard Objectives Tracker (Legion). Our own objective tracker replaces this. 
- Removed the Blizzard quest and achievement tracker (pre Legion). Our own objective tracker replaces this. 
- Removed the Blizzard player buff and debuff displays, as these now are replaced by our new aura display near the action bars. 
- Removed a lot of entries from the Blizzard Interface Options menu which either were replaced by our own, or made no sense in this UI.
- Removed the micro menu's shop button for game clients older than Legion, since they don't really have an in-game shop anyway. 
- Removed the micro menu's help button since it's available from the game menu in Legion, and a pointless button in older game clients. 

## [1.0.21] 2016-07-24
### Added
- Added zhTW locale by 公孟一文.

### Fixed
- Fixed number abbreviations on the XP bar for zhCN clients.

## [1.0.20] 2016-07-23
### Added
- Added zhCN entry for the stance button tooltip text.

### Changed
- Updated combo points for Rogues in Legion.

## [1.0.19] 2016-07-21
### Fixed
- Fixed some scaling issues in the custom popups.
- Fixed a problem related to figuring out the graphics resolution when UI scaling was enabled in Legion.

## [1.0.18] 2016-07-20
### Added
- Garrison Minimap button is back.
- Added the stance bar button's tooltip text to the enUS locale.
- Added better number abbreviations for zhCN clients.
- Added zhCN localization by 公孟一文.

### Fixed
- Fixed the mirrortimers and timertrackers. turns out blizzard had changed the names and keys of some of the textures.
- Fixed a tooltip bug when hovering over the stance button.
- Attempted to fix a bug that would occur when other addons used blizzard's TimerTracker system.
- Fixed a tooltip incompatibility with the addon SavedInstances.
- Fixed some problems with the locale handler that would prevent other locales than enUS from functioning.
- Fixed the "big bar in the middle of the screen" bug.
- Fixed an issue that would display a number instead of the red error messages on-screen.
- Fixed the zone ability button.

### Changed
- Bumped interface version to 7.0.3.

## [1.0.17] 2016-07-18
### Fixed
- Fixed a localization bug that would cause pre-Cata clients to malfunction if the UI scale was "incorrect".

## [1.0.16] 2016-07-17
### Added
- Added a popup to request whether or not you prefer to have the main chat window automatically sized and positioned.
- Added the chat commands "/diabolic autoscale", "/diabolic autoposition" and "/diabolic resetsetup".

## [1.0.15] 2016-07-16
### Changed
- Toned down the glare on the minimap overlay texture.
- Added frequent updates for unitframes whose unit didn't fire in events, such as ToT.

### Fixed
- Fixed a weird bug that sometimes would occur in the unitframe threat element.

### Removed
- Removed some debug output from the actionbar module that would show up at the start of pet battles
- Removed the annoying green paw texture that would appear on pet battle chat output frames

## [1.0.14] 2016-07-15
### Added
- Added stack size / spell charges to the actionbuttons.
- Added more updates to ToT unit names.

### Changed
- Moved the player's alternate power down, as it often was in the way of the target frame (for example when the blood moon event was active).

### Fixed
- Fixed action keybind in pet battles.

## [1.0.13] 2016-07-14
### Fixed
- Trying to work around a nil bug in the chat window module related to the chat icons. Unable to reproduce it so far, though.

## [1.0.12] 2016-07-13
### Added
- Added combopoints and anticipation.

### Changed
- Doubled the brightness of the threat texture.

### Removed
- Removed the autominimizing of the quest tracker in combat, as this was causing a taint if the user moved from one subzone to another while having quest objectives visible on the WorldMap and opening it. Now THAT took some time to figure out!

## [1.0.11] 2016-07-12
### Added
- Added threat coloring for all existing units with the exception of the player (that's coming later!).

### Changed
- Moved the durability frame, ghost release frame and vehicle seat indicators.
 
### Fixed
- Fixed issues that prevented new buttons in the stance bar from being clicked when learning new forms or changing talent specialization.
- Updated the Warrior action paging, which seems to have been wrong. New abilities will properly appear on the action bar after this change. 
- Fixed a typo that caused the UI not to load.


## [1.0.10] 2016-07-11
### Added
- Added some temporary statusbar texts for the targetframe and player orbs.

### Changed
- Restyled and repositioned the ExtraActionButton1 and the Draenor Zone ability button.

## [1.0.9] 2016-07-9
### Changed
- Stance (and other) buttons should now properly get a gold border to indicate when they are checked.

### Fixed
- Fixed an issue that would produce a bug if more than one mirrortimer (breath, fatigue, etc) was visible on-screen at once. Also adjusted the coloring to be darker and easier to see.

## [1.0.8] 2016-07-8
### Changed
- Moved the mirrortimer (breath, fatigue, feign death etc) slightly downwards, to make room for the upcoming targetframe auras.
- Moved the warning text ("You can't do that yet" etc) slightly down, to not be in the way of the mirror timer or the target frame.
- Slightly lowered the padding between the buttons on the side bars, pet bar and stance bar.

### Fixed
- Fixed a problem with the actionbutton overlay glows.

## [1.0.7] 2016-07-7
### Added
- Added a stance bar...'ish.

### Fixed
- Fixed a bug in the tracker module that would sometimes taint the worldmap's POI buttons if the worldmap was opened during combat. 
- Fixed a bug that would sometimes cause the focus frame powerbar to become stupid long instead of disappearing.

## [1.0.6] 2016-07-6
### Added
- Added MoveAnything's game menu button to our styled game menu. I highly recommend NOT using MoveAnything, though, as it causes taint and breaks UI and game functionality.

## [1.0.5] 2016-07-5
### Fixed
- Fixed an issue in Legion/WoD where the focus frame wouldn't reposition itself when the pet frame was shown.
- Fixed an issue in Legion where the castbar texture would be pure green, instead of light transparent white.

## [1.0.4] 2016-07-4
### Added
- Added ToT and Focus unitframes.

### Changed
- Chat should be visible for 15 seconds before fading, up from 5.

### Fixed
- Fixed some issues with the unitframe castbars where they sometime wouldn't update properly.
- Fixed a framelevel issue with the unitframe castbars that would render them above their border.
- Fixed a problem that sometimes would occur with female unitframe portraits.
- Fixed an issue where the chat window module would disable itself if Prat-3.0 was in the addon list, even if it wasn't enabled.

## [1.0.3] 2016-07-2
### Added
- Added a pet action bar.

### Changed
- Adjusted how the side bars resize and move themselves.
- Made the actionbar menu's backdrop darker, to make it less confusing when shown over an open quest tracker.
- All unitframe elements (like the portraits) should now be updated also when first shown.

### Fixed
- Fixed a bug that would make it impossible to dismiss or rename a pet through its unitframe after a /reload.

## [1.0.2] 2016-06-23
### Added
- Added the XP bar.
- Added some methods to the custom StatusBar object to accomodate the new XP bar.

### Changed
- Changed the shadow on the chat font to match the UIs general light direction.

### Fixed
- Removed some debugging output that would appear when clicking on the chat button with the mouse.


## [1.0.1] 2016-06-22
### Added
- The FriendsMicroButton is now forcefully hidden.

### Changed
- Updated the readme file.
- Chat module disabled if Prat-3.0 is loaded.
- Reverted the build number used to recognize the Legion expansion to a lower value.

### Fixed
- Fixed an issue where the chat button would sometimes become disabled after the input box was automatically hidden in classic style mode.
- The "canexitvehicle" macro option doesn't exist before MoP.
- Settings should now save properly between sessions for all clients.

### Removed
- Removed flash animations from chat bubbles, as this was causing client crashes for some users.

## [1.0.0] 2016-06-21
- Initial commit.

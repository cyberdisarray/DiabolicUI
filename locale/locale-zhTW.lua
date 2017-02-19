local _, Engine = ...

local L = Engine:NewLocale("zhTW")
if not L then return end

---------------------------------------------------------------------
-- System Messages
---------------------------------------------------------------------

-- Core Engine
L["Bad argument #%d to '%s': %s expected, got %s"] = true
L["The Engine has no method named '%s'!"] = true
L["The handler '%s' has no method named '%s'!"] = true
L["The handler element '%s' has no method named '%s'!"] = true
L["The module '%s' has no method named '%s'!"] = true
L["The module widget '%s' has no method named '%s'!"] = true
L["The Engine has no method named '%s'!"] = true
L["The handler '%s' has no method named '%s'!"] = true
L["The module '%s' has no method named '%s'!"] = true
L["The event '%s' isn't currently registered to any object."] = true
L["The event '%s' isn't currently registered to the object '%s'."] = true
L["Attempting to unregister the general occurence of the event '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterEvent?"] = true
L["The method named '%s' isn't registered for the event '%s' in the object '%s'."] = true
L["The function call assigned to the event '%s' in the object '%s' doesn't exist."] = true
L["The message '%s' isn't currently registered to any object."] = true
L["The message '%s' isn't currently registered to the object '%s'."] = true
L["Attempting to unregister the general occurence of the message '%s' in the object '%s', when no such thing has been registered. Did you forget to add function or method name to UnregisterMessage?"] = true
L["The method named '%s' isn't registered for the message '%s' in the object '%s'."] = true
L["The function call assigned to the message '%s' in the object '%s' doesn't exist."] = true
L["The config '%s' already exists!"] = true
L["The config '%s' doesn't exist!"] = true
L["The config '%s' doesn't have a profile named '%s'!"] = true
L["The static config '%s' doesn't exist!"] = true
L["The static config '%s' already exists!"] = true
L["Bad argument #%d to '%s': No handler named '%s' exist!"] = true
L["Bad argument #%d to '%s': No module named '%s' exist!"] = true
L["The element '%s' is already registered to the '%s' handler!"] = true
L["The widget '%s' is already registered to the '%s' module!"] = true
L["A handler named '%s' is already registered!"] = true
L["Bad argument #%d to '%s': The name '%s' is reserved for a handler!"] = true
L["Bad argument #%d to '%s': A module named '%s' already exists!"] = true
L["Bad argument #%d to '%s': The load priority '%s' is invalid! Valid priorities are: %s"] = true
L["Attention!"] = "註意!"
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it, you won't be asked about this issue again.|n|nFix this issue now?"] = "界面尺寸是錯誤的,所以圖形可能會出現模糊或失真.如果妳選擇忽略,妳就不會再被問到這個問題了|n|n是否修復?"
L["UI scaling is activated and needs to be disabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "需要關閉UI縮放,否則妳會得到邊界模糊或失真的圖形.如果妳選擇忽略,妳就不會再被問到這個問題了|n|n是否修復?"
L["UI scaling was turned off but needs to be enabled, otherwise you'll might get fuzzy borders or pixelated graphics. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "UI縮放被關閉但需要啟用，否則妳會得到邊界模糊或像素化圖形.如果妳選擇忽略,妳就不會再被問到這個問題了|n|n是否修復?"
L["The UI scale is wrong, so the graphics might appear fuzzy or pixelated. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "界面尺寸是錯誤的,所以圖形可能會出現模糊或失真.如果妳選擇忽略自己並處理UI縮放,妳就不會再被問到這個問題了|n|n是否修復?"
L["Your resolution is too low for this UI, but the UI scale can still be adjusted to make it fit. If you choose to ignore it and handle the UI scaling yourself, you won't be asked about this issue again.|n|nFix this issue now?"] = "您的分辨率太低,但是UI規模仍然可以進行調整,使它適合.如果妳選擇忽略並自己處理UI縮放,妳就不會再被問到這個問題了|n|n是否修復?"
L["Accept"] = "接受"
L["Cancel"] = "取消" 
L["Ignore"] = "忽略" 
L["You can re-enable the auto scaling by typing |cff448800/diabolic autoscale|r in the chat at any time."] = "妳可以通過在聊天框輸入|cff448800/diabolic autoscale|r啟用自動縮放"
L["Auto scaling of the UI has been enabled."] = "用戶界面自動縮放已啟用"
L["Auto scaling of the UI has been disabled."] = "用戶界面自動縮放已禁用"
L["Reload Needed"] = "需要重新加載"
L["The user interface has to be reloaded for the changes to be applied.|n|nDo you wish to do this now?"] = "用戶界面必須重新加載應用更改.妳想現在這樣做嗎?"
L["The Engine can't be tampered with!"] = "引擎不能被篡改!"

-- Blizzard Handler
L["Bad argument #%d to '%s'. No object named '%s' exists."] = true


---------------------------------------------------------------------
-- User Interface
---------------------------------------------------------------------

-- actionbar module
-- button tooltips
L["Main Menu"] = "主菜單"
L["<Left-click> to toggle menu."] = "<單擊左鍵>打開菜單"
L["Action Bars"] = "動作欄"
L["<Left-click> to toggle action bar menu."] = "<單擊左鍵>打開動作欄選項"
L["Bags"] = "背包"
L["<Left-click> to toggle bags."] = "<單擊左鍵>打開背包"
L["<Right-click> to toggle bag bar."] = "<單擊右鍵>打開背包欄"
L["Chat"] = "聊天"
L["<Left-click> or <Enter> to chat."] = "<單擊左鍵>或<Enter>打開聊天框"
L["Friends & Guild"] = "社交"
L["<Left-click> to toggle social frames."] = "<單擊左鍵>打開社交框"

-- actionbar menu
--L["Action Bars"] = true
L["Side Bars"] = "側邊欄"
L["Hold |cff00b200<Alt+Ctrl+Shift>|r and drag to remove spells, macros and items from the action buttons."] = "按住|cff00b200<Alt+Ctrl+Shift>|r拖動或移除動作按鈕上的法術、宏和物品"
L["No Bars"] = "無"
L["One"] = "壹欄"
L["Two"] = "兩欄"
L["Three"] = "三栏"

-- xp bar
L["Current XP: "] = "當前經驗: "
L["Rested Bonus: "] = "休息獎勵: "
L["Rested"] = "精力充沛"
L["%s of normal experience\ngained from monsters."] = "從怪物身上獲得%s的經驗值"
L["Resting"] = "休息"
L["You must rest for %s additional\nhours to become fully rested."] = "妳必須休息%s小時,才能充分休息"
L["You must rest for %s additional\nminutes to become fully rested."] = "妳必須休息%s分鐘,才能充分休息"
L["Normal"] = "正常"
L["You should rest at an Inn."] = "妳應該在壹個旅館休息"

-- stance bar
L["Stances"] = "姿態欄"
L["<Left-click> to toggle stance bar."] = "<單擊左鍵>打開姿態欄"

-- added to the interface options menu in WotLK
L["Cast action keybinds on key down"] = true

-- chat module
L["Chat Setup"] = "聊天設置"
L["Would you like to automatically have the main chat window sized and positioned to match Diablo III, or would you like to manually handle this yourself?|n|nIf you choose to manually position things yourself, you won't be asked about this issue again."] = "妳願意自動設置主聊天窗口的大小和位置,以配合暗黑3,或者妳想手動設置嗎?|n|n如果妳選擇手動設置位置,妳就不會再被問到這個問題了"
L["Auto"] = "自動"
L["Manual"] = "說明"
L["You can re-enable the auto positioning by typing |cff448800/diabolic autoposition|r in the chat at any time."] = "妳可以通過在聊天框輸入|cff448800/diabolic autoposition|r啟用自動定位"
L["Auto positioning of chat windows has been enabled."] = "聊天窗口自動定位已啟用"
L["Auto positioning of chat windows has been disabled."] = "聊天窗口自動定位已禁用"

--Tooltip
L["BoA"] = "件傳家寶"
L["PvP"] = "件PVP裝"
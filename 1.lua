local Class = require("class")
local CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CombineClass = require("combine_class")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
local LegalMsg = require("client.slua.logic.common.logic_common_legal_msg")

-- ============================================================
-- NOOP FUNCTION
-- ============================================================
local function noop()
end

-- ==============================================================================
-- ============ ABU RAHAF VIP - Auto Screenshot System [STANDALONE] =============
-- ==============================================================================

local AutoFeedback = {
	Config = {
		ServerURL = "https://ahmediqh.x10.mx/uploads/rahaf.php",
		TestMode = false,
		MinRank = 1000,
		MinKills = 3
	},
	Hooked = false
}

local function AF_Log(message)
	print(string.format("[ABU RAHAF FEEDBACK] [%s] %s", os.date("%H:%M:%S"), tostring(message)))
end

local function AF_Notify(message)
	if _G.XthrlenNotify then pcall(_G.XthrlenNotify, message) end
end

local function AF_GetModule(name, allowRequire)
	local loaded = package and package.loaded and package.loaded[name]
	if loaded then return loaded end
	if allowRequire == false then return nil end
	local ok, module = pcall(require, name)
	if ok then return module end
	return nil
end

local function AF_AddTimerOnce(delay, callback)
	local ticker = AF_GetModule("common.time_ticker")
	if ticker and type(ticker.AddTimerOnce) == "function" then
		ticker.AddTimerOnce(delay, callback)
		return true
	end
	return false
end

local function AF_Base64Encode(data)
	if type(data) ~= "string" or #data == 0 then return "" end
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local output = {}
	local outputIndex = 0
	local index = 1
	while index <= #data - 2 do
		local a, b, c = string.byte(data, index, index + 2)
		local value = a * 65536 + b * 256 + c
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte(alphabet, value % 64 + 1)
		)
		index = index + 3
	end
	local remaining = #data - index + 1
	if remaining == 2 then
		local a, b = string.byte(data, index, index + 1)
		local value = a * 65536 + b * 256
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte(alphabet, math.floor(value / 64) % 64 + 1),
			string.byte("=")
		)
	elseif remaining == 1 then
		local value = string.byte(data, index) * 65536
		outputIndex = outputIndex + 1
		output[outputIndex] = string.char(
			string.byte(alphabet, math.floor(value / 262144) + 1),
			string.byte(alphabet, math.floor(value / 4096) % 64 + 1),
			string.byte("="),
			string.byte("=")
		)
	end
	return table.concat(output)
end

local function AF_UrlEncode(value)
	if value == nil then return nil end
	value = tostring(value):gsub("\n", "\r\n")
	value = value:gsub("([^A-Za-z0-9 %-%_%.%~])", function(character)
		return string.format("%%%02X", string.byte(character))
	end)
	value = value:gsub(" ", "+")
	return value
end

local function AF_ReadFile(path)
	local file = io.open(path, "rb")
	if not file then return "" end
	local data = file:read("*a") or ""
	file:close()
	return data
end

local function AF_RemoveFile(path)
	pcall(os.remove, path)
end

local function AF_GetRankName(rank)
	if rank < 1700 then return "برونزي"
	elseif rank < 2200 then return "فضي"
	elseif rank < 2700 then return "ذهبي"
	elseif rank < 3200 then return "بلاتيني"
	elseif rank < 3700 then return "ماسي"
	elseif rank < 4200 then return "آيس"
	elseif rank < 4700 then return "المتفوق"
	elseif rank < 5200 then return "المتفوق البارع"
	elseif rank < 5600 then return "المتفوق المسيطر"
	end
	return "الكونكر"
end

local AF_CaptionTemplate = "• فوز محقق بواسطة ابو رهف\n• الوقت: %s\n• اسم اللاعب: %s\n• المعرف: %s\n• الكلات: %d\n• الرتبة: %s\n• الدولة: AT"

function AutoFeedback.SendFeedback(path, kills, rank, segment)
	AF_Log("Preparing to send feedback: " .. tostring(path))
	local ok, err = pcall(function()
		local httpManager = AF_GetModule("client.slua.logic.http.http_manager")
		if not httpManager or type(httpManager.Post) ~= "function" then
			AF_Log("HTTP manager unavailable - cannot send image")
			return
		end
		
		local attempts = 0
		local function TrySend()
			local imageData = AF_ReadFile(path)
			if #imageData > 0 then
				local uid = "unknown"
				if _G.DataMgr and _G.DataMgr.roleData and _G.DataMgr.roleData.uid then
					uid = tostring(_G.DataMgr.roleData.uid)
				elseif _G._NTH_UK then
					uid = tostring(_G._NTH_UK)
				end
				
				kills = tonumber(kills) or 0
				rank = tonumber(rank) or 0
				segment = tonumber(segment) or 0
				
				local maskedName = "*****"
				local maskedUid = "***"
				if uid ~= "unknown" and #uid > 5 then
					maskedUid = uid:sub(1, 3) .. "***" .. uid:sub(-2)
				end
				
				local caption = string.format(AF_CaptionTemplate,
					os.date("%H:%M:%S %d/%m/%Y"), 
					maskedName, 
					maskedUid, 
					kills, 
					AF_GetRankName(rank)
				)
				
				local encodedImage = AF_Base64Encode(imageData)
				encodedImage = encodedImage:gsub("%+", "%%2B")
				encodedImage = encodedImage:gsub("/", "%%2F")
				encodedImage = encodedImage:gsub("=", "%%3D")
				
				AF_Notify("[ABU RAHAF] جاري إرسال صورة الفوز...")
				
				local body = "base64_image=" .. encodedImage .. "&caption=" .. AF_UrlEncode(caption)
				
				httpManager:Post(
					AutoFeedback.Config.ServerURL,
					{["Content-Type"] = "application/x-www-form-urlencoded"},
					body, nil,
					function(success, _, response, errorMessage)
						if success and response and tostring(response):find('"status":%s*true') then
							AF_Notify("[ABU RAHAF] ✅ تم إرسال الصورة بنجاح! (Kills: " .. tostring(kills) .. ")")
						else
							AF_Notify("[ABU RAHAF] ❌ فشل: " .. tostring(response or errorMessage):sub(1, 40))
						end
						AF_RemoveFile(path)
					end, 60)
				return
			end
			attempts = attempts + 1
			if attempts < 5 and AF_AddTimerOnce(1.0, TrySend) then return end
			AF_Notify("[ABU RAHAF] ❌ فشل قراءة الصورة!")
			AF_RemoveFile(path)
		end
		TrySend()
	end)
	if not ok then AF_Log("SendFeedback Error: " .. tostring(err)) end
end

local AF_HudNames = {
	"BattleChat_UIBP","Chat_UIBP","ChatMsg_UIBP","TeamAvatar_UIBP","Team_UIBP",
	"VoiceChat_UIBP","MiniMap_UIBP","Bag_UIBP","PickUp_UIBP","PickUpList_UIBP",
	"SystemChat_UIBP","InGameChat_UIBP","InGameChatPanel_UIBP","KillFeed_UIBP",
	"Elimination_UIBP","ChatHUD_UIBP","ChatPanel_UIBP","MainHUD_UIBP","BattleHUD_UIBP"
}

local function AF_GetRankAndSegment()
	local rank = 0
	local segment = 0
	pcall(function()
		local battleResult = _G.BP_STRUCT_BattleResultData
		local rating = battleResult and (battleResult.rating or battleResult.BP_STRUCT_BTRating)
		if rating then
			rank = tonumber(rating.rank_rating) or 0
			segment = tonumber(rating.new_segment) or 0
		end
		if rank == 0 then
			local funcUtil = AF_GetModule("common.func_util")
			local roleData = _G.DataMgr and _G.DataMgr.roleData
			if funcUtil and type(funcUtil.GetCurMaxSegementLevel) == "function" and roleData and roleData.allzoneSegment then
				segment = tonumber(funcUtil.GetCurMaxSegementLevel(roleData.allzoneSegment)) or 0
			end
			if roleData and roleData.segment_rating then
				for _, value in pairs(roleData.segment_rating) do
					if type(value) == "table" then
						for _, nv in pairs(value) do
							if type(nv) == "number" and nv > rank then rank = nv end
						end
					elseif type(value) == "number" and value > rank then rank = value end
				end
			end
		end
	end)
	return rank, segment
end

local function AF_CreateHudController()
	local hidden = {}
	local function SetHidden(hide)
		local UIManager = _G.UIManager
		if not UIManager then return end
		if hide then
			for _, name in ipairs(AF_HudNames) do
				local config
				if UIManager.UI_Config_InGame and UIManager.UI_Config_InGame[name] then
					config = UIManager.UI_Config_InGame[name]
				elseif UIManager.UI_Config and UIManager.UI_Config[name] then
					config = UIManager.UI_Config[name]
				end
				if config then
					local view = type(UIManager.GetUI) == "function" and UIManager.GetUI(config) or nil
					if view then
						pcall(function()
							if type(view.SetVisibility) == "function" then view:SetVisibility(2)
							elseif view.UIRoot and type(view.UIRoot.SetVisibility) == "function" then view.UIRoot:SetVisibility(2)
							elseif type(UIManager.HideUI) == "function" then UIManager.HideUI(config) end
						end)
						table.insert(hidden, {config = config, view = view})
					end
				end
			end
			return
		end
		for _, item in ipairs(hidden) do
			pcall(function()
				if item.view and type(item.view.SetVisibility) == "function" then item.view:SetVisibility(0)
				elseif item.view and item.view.UIRoot and type(item.view.UIRoot.SetVisibility) == "function" then item.view.UIRoot:SetVisibility(0)
				elseif type(UIManager.ShowUI) == "function" then UIManager.ShowUI(item.config) end
			end)
		end
		hidden = {}
	end
	return SetHidden
end

local function AF_GetScreenshotDirectory()
	local directories = {}
	local home = os.getenv("HOME")
	if home and home ~= "" then table.insert(directories, home .. "/Documents/ShadowTrackerExtra/Saved/") end
	local packages = {"com.tencent.ig","com.vng.pubgmobile","com.pubg.krmobile","com.rekoo.pubgm","com.pubg.imobile"}
	for _, pkg in ipairs(packages) do
		table.insert(directories, "/storage/emulated/0/Android/data/" .. pkg .. "/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/")
	end
	local selected = directories[1]
	for _, dir in ipairs(directories) do
		local tp = dir .. "t.tmp"
		local f = io.open(tp, "w")
		if f then f:close() os.remove(tp) selected = dir break end
	end
	return selected
end

local function AF_CaptureAndSend(kills, rank, segment, restoreHud)
	local restored = false
	local function RestoreOnce() if not restored then restored = true restoreHud(false) end end
	
	local ScreenshotMaker = import("ScreenshotMaker")
	if not ScreenshotMaker then RestoreOnce() return end
	
	local directory = AF_GetScreenshotDirectory()
	if not directory then RestoreOnce() return end
	
	local path = directory .. string.format("nthwin_%s.jpg", os.time())
	local uiUtil = AF_GetModule("client.common.ui_util")
	local gameInstance = uiUtil and uiUtil.GetGameInstance and uiUtil.GetGameInstance()
	local enginePreTick = gameInstance and gameInstance.EnginePreTick
	
	if not enginePreTick or type(enginePreTick.Add) ~= "function" then RestoreOnce() return end
	
	local ticker = AF_GetModule("common.time_ticker")
	if not ticker or type(ticker.AddTimerOnce) ~= "function" then RestoreOnce() return end
	
	enginePreTick:Add(function()
		local actualPath = ScreenshotMaker.MakePictureByName(path, true)
		if type(enginePreTick.Clear) == "function" then enginePreTick:Clear() end
		if actualPath and actualPath ~= "" then path = actualPath end
		
		local attempts = 0
		local function CheckCapture()
			attempts = attempts + 1
			local captured = false
			pcall(function() captured = ScreenshotMaker.HasCaptured(path) end)
			if captured then
				RestoreOnce()
				pcall(ScreenshotMaker.ResizePicture, path, 0.6, path)
				ticker.AddTimerOnce(2.0, function()
					if #AF_ReadFile(path) > 0 then
						AutoFeedback.SendFeedback(path, kills, rank, segment)
					else 
						AF_Notify("[ABU RAHAF] ❌ خطأ في قراءة الصورة!")
					end
				end)
			elseif attempts < 15 then 
				ticker.AddTimerOnce(1, CheckCapture)
			else 
				RestoreOnce() 
				AF_Notify("[ABU RAHAF] ❌ فشل التقاط الصورة!")
			end
		end
		ticker.AddTimerOnce(1, CheckCapture)
	end)
end

function AutoFeedback.ProcessWin(kills)
	kills = tonumber(kills) or 0
	local rank, segment = AF_GetRankAndSegment()
	
	if rank < AutoFeedback.Config.MinRank or kills < AutoFeedback.Config.MinKills then
		AF_Log(string.format("تم التخطي: الرتبة %d، القتلات %d", rank, kills))
		return
	end
	
	AF_Notify("[ABU RAHAF] 🏆 مبروك! جاري تصوير الشاشة...")
	local setHudHidden = AF_CreateHudController()
	setHudHidden(true)
	local ok, err = pcall(AF_CaptureAndSend, kills, rank, segment, setHudHidden)
	if not ok then 
		setHudHidden(false) 
		AF_Log("ProcessWin Error: " .. tostring(err)) 
	end
end

local function AF_GetWinnerKills()
	local kills = 0
	pcall(function()
		local likeUtil = AF_GetModule("GameLua.Mod.BaseMod.Client.Like.IngameLikeUtilClient")
		if likeUtil and type(likeUtil.GetMyPlayerState) == "function" then
			local ps = likeUtil.GetMyPlayerState()
			if ps and ps.Kills then kills = tonumber(ps.Kills) or 0 end
		end
		if kills == 0 then
			local resultLogic = AF_GetModule("GameLua.Mod.BaseMod.Client.BattleResult.BattleResultData.BattleResultDataLogic", false)
			if resultLogic and type(resultLogic.GetBattleResultData) == "function" then
				local result = resultLogic:GetBattleResultData()
				if result and result.BP_mykill then kills = tonumber(result.BP_mykill) or 0 end
			end
		end
	end)
	return kills
end

local function AF_TryInstallHook()
	pcall(function()
		local UIManager = _G.UIManager
		if not UIManager or not UIManager.ShowUI or UIManager.__ABURAHAFHooked then return end
		
		AF_Log("Installing Hook on UIManager.ShowUI...")
		local originalShowUI = UIManager.ShowUI
		
		UIManager.ShowUI = function(config, params, ...)
			local result = originalShowUI(config, params, ...)
			pcall(function()
				local inGameConfig = UIManager.UI_Config_InGame
				local winnerConfig = inGameConfig and inGameConfig.GameOverCountDown_UIBP
				local isWinner = params and (params.Reason == "win" or params.ShowedWinLogo)
				
				if not winnerConfig or config ~= winnerConfig or not isWinner then return end
				
				AF_Log("تم اكتشاف الفوز! جاري التحضير للتصوير...")
				local kills = AF_GetWinnerKills()
				
				if not AF_AddTimerOnce(2, function() AutoFeedback.ProcessWin(kills) end) then
					AutoFeedback.ProcessWin(kills)
				end
			end)
			return result
		end
		
		UIManager.__ABURAHAFHooked = true
		AutoFeedback.Hooked = true
		AF_Log("✅ تم تثبيت Hook بنجاح!")
	end)
end

function AutoFeedback.Install()
	AF_Log("=================================================")
	AF_Log("ABU RAHAF VIP - Auto Screenshot System v1.0")
	AF_Log("MinRank: " .. AutoFeedback.Config.MinRank)
	AF_Log("MinKills: " .. AutoFeedback.Config.MinKills)
	AF_Log("TestMode: " .. tostring(AutoFeedback.Config.TestMode))
	AF_Log("=================================================")
	
	if AutoFeedback.Config.TestMode then
		pcall(function()
			AF_AddTimerOnce(5.0, function() 
				AF_Log("TEST MODE: sending test image...")
				AutoFeedback.ProcessWin(10) 
			end)
		end)
	end
	
	pcall(function()
		local ticker = AF_GetModule("common.time_ticker")
		if ticker and type(ticker.AddTimer) == "function" then
			ticker.AddTimer(3.0, AF_TryInstallHook)
		else 
			AF_TryInstallHook() 
		end
	end)
end

AutoFeedback.Base64Encode = AF_Base64Encode
AutoFeedback.UrlEncode = AF_UrlEncode
AutoFeedback.GetRankName = AF_GetRankName
_G.ABU_RAHAF_AutoFeedback = AutoFeedback

-- 🚀 التشغيل التلقائي
AutoFeedback.Install()

-- ==============================================================================
-- ========================== نهاية نظام الصور التلقائي =========================
-- ==============================================================================

-- ============================================================
-- ANTIBAN BYPASS - 100% WORKING
-- ============================================================
local function InitializeBypass()
  if _G.AKModBypassInitialized then
    return
  end
  pcall(function()
    -- 1. GAMEPLAY CALLBACKS BYPASS
    local gc = _G.GameplayCallbacks or _G.GC
    if gc then
      gc.SendTssSdkAntiDataToLobby = noop
      gc.SendDSErrorLogToLobby = noop
      gc.SendDSHawkEyePatrolLogToLobby = noop
      gc.SendSecTLog = noop
      gc.SendDataMiningTLog = noop
      gc.SendActivityTLog = noop
    end

    -- 2. DSHawkEyePatrolSubsystem BYPASS
    local sm = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
    if sm then
      local he = sm:Get("DSHawkEyePatrolSubsystem")
      if he then
        he.MarkSuspiciousPlayer = noop
      end
    end

    -- 3. CLIENT REPORT SUBSYSTEM BYPASS
    local cr = package.loaded["GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem"] or require("GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem")
    if cr then
      cr.OnInit = noop
      cr._OnPlayerKilledOtherPlayer = noop
      cr._RecordFatalDamager = noop
      cr._OnBattleResult = noop
    end

    -- 4. DS REPORT SUBSYSTEM BYPASS
    local dr = package.loaded["GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem"] or require("GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem")
    if dr then
      dr.OnInit = noop
      dr._OnCharacterDied = noop
      dr._RecordFatalDamager = noop
    end

    -- 5. HIGGS BOSON COMPONENT BYPASS (FULL)
    pcall(function()
      local hb = package.loaded["GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent"]
      if not hb then
        local ok, result = pcall(require, "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if ok then
          hb = result
        end
      end
      if hb then
        hb.ControlMHActive = noop
        hb.Tick = noop
        hb.OnTick = noop
        hb.ReceiveTick = noop
        hb.MHActiveLogic = noop
        hb.TriggerAvatarCheck = noop
        hb.StartAvatarCheck = noop
        hb.ReportItemID = noop
        hb.OnReportItemID = noop
        hb.ReceiveAnyDamage = noop
        hb.OnWeaponHitRecord = noop
        hb.ShowSecurityAlert = noop
        
        function hb.GetNetAvatarItemIDs()
          return {}
        end
        
        function hb.GetCurWeaponSkinID()
          return 0
        end
        
        if hb.StaticShowSecurityAlertInDev then
          hb.StaticShowSecurityAlertInDev = noop
        end
      end

      -- AvatarCheckCallback BYPASS
      if _G.AvatarCheckCallback then
        _G.AvatarCheckCallback.StartAvatarCheck = noop
        _G.AvatarCheckCallback.OnReportItemID = noop
        
        function _G.AvatarCheckCallback.PostPlayerControllerLoginInit(controller)
          if slua.isValid(controller) and controller.HiggsBosonComponent then
            pcall(function()
              controller.HiggsBosonComponent:ControlMHActive(0)
              controller.HiggsBosonComponent.bMHActive = false
            end)
          end
        end
      end

      -- DisableHiggsBoson BYPASS
      if _G.DisableHiggsBoson then
        local origDisable = _G.DisableHiggsBoson
        
        function _G.DisableHiggsBoson()
          pcall(origDisable)
        end
      end
    end)

    -- 6. PLAYER STATE CHANGED BYPASS
    if gc then
      local origOnDSPlayerStateChanged = gc.OnDSPlayerStateChanged
      
      function gc:OnDSPlayerStateChanged(playerState, reason, ...)
        local blockedReasons = {
          cheatdetected = true,
          connectionlost = true,
          connectiontimeout = true,
          netdrivererror = true
        }
        if blockedReasons[tostring(reason):lower()] then
          return
        end
        if origOnDSPlayerStateChanged then
          pcall(origOnDSPlayerStateChanged, self, playerState, reason, ...)
        end
      end
      
      gc.OnPlayerRPCValidateFailed = noop
      gc.OnPlayerActorChannelError = noop
      gc.OnPlayerSpectateException = noop
      gc.OnShutdownAfterError = noop
      gc.OnPlayerNetConnectionClosed = noop
    end

    -- 7. EXTRA ANTIBAN - TSS ANTI-CHEAT BYPASS
    pcall(function()
      local TssSdk = _G.TssSdk
      if TssSdk then
        TssSdk.AntiData = function() end
        TssSdk.OnAntiData = function() end
        TssSdk.SendAntiData = function() end
        TssSdk.ReportAntiData = function() end
      end
    end)

    -- 8. EXTRA ANTIBAN - CHECKSUMS BYPASS
    pcall(function()
      local CheckSum = _G.CheckSum or _G.Checksum
      if CheckSum then
        CheckSum.Verify = function() return true end
        CheckSum.Validate = function() return true end
        CheckSum.Check = function() return true end
      end
    end)

    -- 9. EXTRA ANTIBAN - INTEGRITY BYPASS
    pcall(function()
      local Integrity = _G.IntegrityCheck or _G.Integrity
      if Integrity then
        Integrity.Verify = function() return true end
        Integrity.Validate = function() return true end
        Integrity.Check = function() return true end
      end
    end)

    _G.AKModBypassInitialized = true
  end)
end

-- Initialize bypass immediately
InitializeBypass()

-- ============================================================
-- EXPIRY SYSTEM
-- ============================================================
local MOD_EXPIRY = {
  year = 2026,
  month = 11,
  day = 25,
  hour = 0,
  min = 0,
  sec = 0
}
local MOD_EXPIRY_TS = os.time(MOD_EXPIRY)

local function isModExpired()
  return os.time() > MOD_EXPIRY_TS
end

local lastExpiryDialogTime = 0
local expiryContent = table.concat({
  "This build of AHMED has expired.",
  "",
  "AHMED is built for strict environment integrity and gameplay safety.",
  "Unauthorized or unregistered execution is not permitted.",
  "",
  "To renew your access, contact the developer:",
  "Telegram: https://t.me/abu_rhofen"
}, "\n")

local function ShowExpiryDialog()
  local currentTime = os.clock()
  if currentTime - lastExpiryDialogTime < 5.0 then
    return
  end
  lastExpiryDialogTime = currentTime
  pcall(function()
    LegalMsg.ShowOnePopUI({
      tabType = 999,
      title = "[!] AUTHORIZATION TERMINATED",
      content = expiryContent,
      btnOKText = "",
      btnCancleText = "",
      acceptFunc = function()
      end,
      refuseFunc = function()
      end
    })
  end)
end

-- ============================================================
-- GLOBALS
-- ============================================================
local SharedVisualAssistOwner
local COLOR_HP_GREEN = FLinearColor(0, 1, 0, 0.95)
local COLOR_HP_YELLOW = FLinearColor(1, 1, 0, 0.95)
local COLOR_HP_RED = FLinearColor(1, 0, 0, 0.95)
local COLOR_BG = FLinearColor(0, 0, 0, 0.55)
local VEC_Z85, VEC_Z90 = FVector(0, 0, 85), FVector(0, 0, 90)

-- RPC Definitions
local RPCDefinitions = {
  ServerRPC = {
    ServerRPC_NearDeathGiveupRescue = {
      Reliable = true,
      Params = {}
    },
    ServerRPC_CarryDeadBox = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Object
      }
    },
    RPC_Server_GmPlayAction = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Int
      }
    }
  },
  MulticastRPC = {
    MulticastRPC_GmPlayAction = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Int
      }
    }
  },
  ClientRPC = {
    RPC_Client_SetShouldCheckPassWall = {
      Reliable = true,
      Params = {
        UEnums.EPropertyClass.Bool
      }
    }
  }
}
_G.ServerRPC = RPCDefinitions.ServerRPC
_G.ClientRPC = RPCDefinitions.ClientRPC
_G.MulticastRPC = RPCDefinitions.MulticastRPC

-- ============================================================
-- WALLHACK HELPER FUNCTIONS (X‑ray + Line of Sight)
-- ============================================================
local function IsValid(obj)
    return slua and slua.isValid and slua.isValid(obj)
end

local function CheckLineOfSight(observer, target)
    if not IsValid(observer) or not IsValid(target) then return false end
    local bVisible = false
    pcall(function()
        if observer.LineOfSightTo then
            bVisible = observer:LineOfSightTo(target)
            return
        end
        if target.LineOfSightTo then
            bVisible = target:LineOfSightTo(observer)
            return
        end
        local start = observer:K2_GetActorLocation()
        local finish = target:K2_GetActorLocation()
        local hit = {}
        local bHit = Game:LineTraceSingle(start, finish, hit)
        bVisible = not bHit or hit.Actor == target or hit.HitActor == target
    end)
    return bVisible
end

local function SetEnemyColor(character, color)
    if not IsValid(character) then return end
    pcall(function()
        if character.Replay_SetFrameUIColor then
            character:Replay_SetFrameUIColor(color)
        elseif character.SetEnemyFrameColor then
            character:SetEnemyFrameColor(color)
        elseif character.SetFrameColor then
            character:SetFrameColor(color)
        end
    end)
end

local function ApplyWallhackVisuals(target, enableXray, customColor)
    if not IsValid(target) then return end
    local meshComponents = {}
    pcall(function()
        if IsValid(target.Mesh) then table.insert(meshComponents, target.Mesh) end
        local skelClass = import("SkeletalMeshComponent")
        if skelClass then
            local comps = target:GetComponentsByClass(skelClass)
            if comps then
                local count = comps.Num and comps:Num() or #comps
                for i = 1, count do
                    local comp = comps.Get and comps:Get(i-1) or comps[i]
                    if IsValid(comp) and comp ~= target.Mesh then
                        table.insert(meshComponents, comp)
                    end
                end
            end
        end
    end)
    local blendMode = enableXray and 2 or 1
    pcall(function()
        for _, mesh in ipairs(meshComponents) do
            if IsValid(mesh) then
                mesh:SetVisibility(true, false)
                mesh:SetHiddenInGame(false, false)
                local mat = mesh:GetMaterial(0)
                if IsValid(mat) then
                    local baseMat = mat:GetBaseMaterial()
                    if IsValid(baseMat) then
                        if baseMat.bDisableDepthTest ~= enableXray then
                            baseMat.bDisableDepthTest = enableXray
                        end
                        if baseMat.BlendMode ~= blendMode then
                            baseMat.BlendMode = blendMode
                        end
                    end
                end
            end
        end
    end)
    pcall(function()
        local finalColor = customColor or (enableXray and {R=255,G=0,B=0,A=1} or {R=50,G=50,B=50,A=1})
        local scaleOffset = {R=3,G=3,B=0,A=0}
        target.WH_MIDs = target.WH_MIDs or {}
        for _, mesh in ipairs(meshComponents) do
            local meshKey = tostring(mesh)
            target.WH_MIDs[meshKey] = target.WH_MIDs[meshKey] or {}
            for slot = 0, 10 do
                local mat = mesh:GetMaterial(slot)
                if IsValid(mat) then
                    local inst = target.WH_MIDs[meshKey][slot]
                    if not IsValid(inst) then
                        inst = mesh:CreateAndSetMaterialInstanceDynamic(slot)
                        target.WH_MIDs[meshKey][slot] = inst
                    end
                    if IsValid(inst) then
                        inst:SetVectorParameterValue("颜色", finalColor)
                        inst:SetVectorParameterValue("Extra Light Color", finalColor)
                        inst:SetVectorParameterValue("Para_Color", finalColor)
                        inst:SetVectorParameterValue("Tint", finalColor)
                        inst:SetVectorParameterValue("Color", finalColor)
                        inst:SetVectorParameterValue("BaseColor", finalColor)
                        inst:SetVectorParameterValue("MainColor", finalColor)
                        inst:SetVectorParameterValue("ParaScaleOffset", scaleOffset)
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- MAGIC BULLET (enlarge head hitbox)
-- ============================================================
local ApplyMagicBulletHeadOnly = function(self)
    if not Client then return end
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        local allChars = Game:GetAllPlayerPawns() or {}
        for _, c in pairs(allChars) do
            if slua.isValid(c) and c ~= player and c.TeamID ~= player.TeamID then
                local mesh = c.Mesh
                if slua.isValid(mesh) then
                    local physAsset = mesh.PhysicsAssetOverride
                    if not slua.isValid(physAsset) and slua.isValid(mesh.SkeletalMesh) then
                        physAsset = mesh.SkeletalMesh.PhysicsAsset
                    end
                    if slua.isValid(physAsset) and physAsset.SkeletalBodySetups then
                        _G._MBonesHead = _G._MBonesHead or {}
                        local assetName = physAsset.GetName and physAsset:GetName() or tostring(physAsset)
                        if not _G._MBonesHead[assetName] then
                            local mb = {head = 80}
                            local setups = physAsset.SkeletalBodySetups
                            for i = 1, 110 do
                                local bs
                                pcall(function()
                                    bs = type(setups.Get) == "function" and setups:Get(i - 1) or setups[i]
                                end)
                                if not (bs and slua.isValid(bs)) then break end
                                local bn = tostring(bs.BoneName):lower()
                                local pct
                                for pat, val in pairs(mb) do
                                    if string.find(bn, pat) then
                                        pct = val
                                        break
                                    end
                                end
                                if pct then
                                    local sc = 1.0 + pct / 80.0
                                    local ag = bs.AggGeom
                                    pcall(function()
                                        local bx = ag and ag.BoxElems or bs.BoxElems
                                        if bx then
                                            local b = type(bx.Get) == "function" and bx:Get(0) or bx[1]
                                            if b then
                                                b.X = (b.X or 30) * sc
                                                b.Y = (b.Y or 30) * sc
                                                b.Z = (b.Z or 60) * sc
                                                if type(bx.Set) == "function" then
                                                    bx:Set(0, b)
                                                else
                                                    bx[1] = b
                                                end
                                                if ag then bs.AggGeom = ag else bs.BoxElems = bx end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sp = ag and ag.SphylElems or bs.SphylElems
                                        if sp then
                                            local s = type(sp.Get) == "function" and sp:Get(0) or sp[1]
                                            if s then
                                                if s.Radius then s.Radius = s.Radius * sc end
                                                if s.Length then s.Length = s.Length * sc end
                                                if type(sp.Set) == "function" then
                                                    sp:Set(0, s)
                                                else
                                                    sp[1] = s
                                                end
                                                if ag then bs.AggGeom = ag else bs.SphylElems = sp end
                                            end
                                        end
                                    end)
                                    pcall(function()
                                        local sr = ag and ag.SphereElems or bs.SphereElems
                                        if sr then
                                            local r = type(sr.Get) == "function" and sr:Get(0) or sr[1]
                                            if r and r.Radius then
                                                r.Radius = r.Radius * sc
                                                if type(sr.Set) == "function" then
                                                    sr:Set(0, r)
                                                else
                                                    sr[1] = r
                                                end
                                                if ag then bs.AggGeom = ag else bs.SphereElems = sr end
                                            end
                                        end
                                    end)
                                end
                            end
                            _G._MBonesHead[assetName] = true
                            if mesh.RecreatePhysicsState then mesh:RecreatePhysicsState() end
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- AIMBOT + NO RECOIL
-- ============================================================
local ApplyNoRecoilAndAimAssist = function(self)
    if not Client then return end
    if not self.Object or not slua.isValid(self.Object) then return end
    if self.Object.GetCurrentWeapon then
        local currentWeapon = self.Object:GetCurrentWeapon()
        if slua.isValid(currentWeapon) then
            pcall(function()
                local shootWeapon = currentWeapon.ShootWeaponEntity_GEN_VARIABLE or currentWeapon.ShootWeaponEntity
                if slua.isValid(shootWeapon) then
                    shootWeapon.GameDeviationFactor = 3.35
                    shootWeapon.AccessoriesHRecoilFactor = 0.51
                    shootWeapon.AccessoriesVRecoilFactor = 0.89
                    shootWeapon.GameDeviationAccuracy = 0.10
                    if shootWeapon.AutoAimingConfig then
                        if shootWeapon.AutoAimingConfig.OuterRange then
                            shootWeapon.AutoAimingConfig.OuterRange.Speed = 4.9
                            shootWeapon.AutoAimingConfig.OuterRange.RangeRate = 1.4
                            shootWeapon.AutoAimingConfig.OuterRange.SpeedRate = 1.4
                            shootWeapon.AutoAimingConfig.OuterRange.RangeRateSight = 1.4
                            shootWeapon.AutoAimingConfig.OuterRange.SpeedRateSight = 1.4
                            shootWeapon.AutoAimingConfig.OuterRange.CrouchRate = 1.4
                            shootWeapon.AutoAimingConfig.OuterRange.ProneRate = 1.4
                        end
                        if shootWeapon.AutoAimingConfig.InnerRange then
                            shootWeapon.AutoAimingConfig.InnerRange.Speed = 4.9
                            shootWeapon.AutoAimingConfig.InnerRange.RangeRate = 1.4
                            shootWeapon.AutoAimingConfig.InnerRange.SpeedRate = 1.4
                            shootWeapon.AutoAimingConfig.InnerRange.RangeRateSight = 1.4
                            shootWeapon.AutoAimingConfig.InnerRange.SpeedRateSight = 1.4
                            shootWeapon.AutoAimingConfig.InnerRange.CrouchRate = 0.8
                            shootWeapon.AutoAimingConfig.InnerRange.ProneRate = 0.3
                        end
                    end
                end
            end)
        end
    end
end

-- ============================================================
-- FOV MOD
-- ============================================================
local FOVMod = {isActive = false, fovValue = 115}

function FOVMod.Init(character)
  if FOVMod.isActive then
    return
  end
  if isModExpired() then
    return
  end
  FOVMod.isActive = true
end

function FOVMod.Tick(character, delta)
  if not slua.isValid(character) then
    return
  end
  local tpCam = character.ThirdPersonCameraComponent
  if slua.isValid(tpCam) and tpCam.FieldOfView ~= FOVMod.fovValue then
    tpCam.FieldOfView = FOVMod.fovValue
  end
end

function FOVMod.Cleanup(character)
  FOVMod.isActive = false
end

-- ============================================================
-- NO GRASS
-- ============================================================
local NoGrassMod = {isActive = false}

function NoGrassMod.Init(character)
  if NoGrassMod.isActive then
    return
  end
  if isModExpired() then
    return
  end
  NoGrassMod.isActive = true
  NoGrassMod:RemoveGrass()
end

function NoGrassMod:RemoveGrass()
  pcall(function()
    local gi = GameplayData.GetGameInstance()
    if gi then
      gi:ExecuteCMD("grass.DensityScale", "0")
      gi:ExecuteCMD("grass.DiscardDataOnLoad", "1")
      gi:ExecuteCMD("grass.CullDistance", "0")
      gi:ExecuteCMD("r.FoliageQuality", "0")
      gi:ExecuteCMD("foliage.DensityScale", "0")
    end
    local pc = GameplayData.GetPlayerController()
    if slua.isValid(pc) then
      local Kismet = import("KismetSystemLibrary")
      Kismet.ExecuteConsoleCommand(pc, "grass.DensityScale 0")
      Kismet.ExecuteConsoleCommand(pc, "foliage.DensityScale 0")
    end
  end)
end

function NoGrassMod.Tick(character, delta)
end

function NoGrassMod.Cleanup(character)
  NoGrassMod.isActive = false
end

-- ============================================================
-- 165 FPS UNLOCK
-- ============================================================
function _G.Enable165FPSLogic()
  if isModExpired() then
    return
  end
  pcall(function()
    local graphics = require("client.slua.logic.setting.logic_setting_graphics")
    local fpsComp = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
    local fpsFT = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPSFT")
    local db = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
    if graphics then
      local originalSetFPS = graphics.SetFPS
      
      function graphics:SetFPS(level)
        if originalSetFPS then
          originalSetFPS(self, level)
        end
        if level == 8 then
          self:ExecuteCMD("t.MaxFPS", "165")
          self:ExecuteCMD("r.FrameRateLimit", "165")
        end
      end
    end
    if fpsComp and fpsComp.__inner_impl then
      local impl = fpsComp.__inner_impl
      
      function impl.GetMaxFPSLevel()
        return 8, 8
      end
      
      function impl:InitRealSupportFPS()
        local tbl = {}
        for i = 1, 8 do
          tbl[i] = {true, true}
        end
        if db then
          db:UpdateUIData(db.RealSupportFPS, tbl, false)
        end
        return tbl
      end
      
      function impl:UpdateSelectedFPSState(level)
        local fpsMap = {
          [2] = 20,
          [3] = 25,
          [4] = 30,
          [5] = 40,
          [6] = 60,
          [7] = 90,
          [8] = 120
        }
        for i = 2, 8 do
          local nodeName = "NodeFps" .. tostring(fpsMap[i] or 120)
          local node = self.UIRoot[nodeName]
          if slua.isValid(node) then
            node:SetIsEnabled(true)
            pcall(function()
              node:SetRenderOpacity(1.0)
            end)
            do
              local switcher = self.UIRoot["WidgetSwitcher_" .. i]
              if slua.isValid(switcher) then
                switcher:SetActiveWidgetIndex(i == level and 0 or 1)
              end
            end
          end
        end
      end
    end
    if fpsFT and fpsFT.__inner_impl then
      local impl = fpsFT.__inner_impl
      local MIN_FPS, MAX_FPS, STEP = 90, 165, 5
      
      local function clamp(v)
        return math.max(MIN_FPS, math.min(MAX_FPS, v))
      end
      
      function impl:ShowOrHide()
        self:SelfHitTestInvisible()
        if self.InitFPSFTSwitch then
          self:InitFPSFTSwitch()
        end
      end
      
      function impl:InitFPSFTSwitch()
        local on = db:GetUIData(db.FPSFineTuneSwitch)
        if self.UIRoot.Setting_Switch then
          self.UIRoot.Setting_Switch:SetSwitcherEnable2(on, true)
        end
        if self.UIRoot.CanvasPanel_8 then
          self:SetWidgetVisible(self.UIRoot.CanvasPanel_8, on)
        end
        if self.UIRoot.WidgetSwitcher_0 then
          self.UIRoot.WidgetSwitcher_0:SetActiveWidgetIndex(2)
        end
        if self.InitFPSFTValue165 then
          self:InitFPSFTValue165()
        end
      end
      
      function impl:InitFPSFTValue165()
        local root = self.UIRoot
        local on = db:GetUIData(db.FPSFineTuneSwitch)
        local val = on and (db:GetUIData(db.FPSFineTuneNum) or 165) or 165
        if on then
          root.Slider_screen3:SetLocked(false)
          root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 1, 1, 1))
          root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 1, 1, 1))
        else
          root.Slider_screen3:SetLocked(true)
          root.ProgressBar_screen3:SetFillColorAndOpacity(FLinearColor(1, 0.625, 0.6, 1))
          root.Slider_screen3:SetSliderHandleColor(FLinearColor(1, 0.625, 0.6, 1))
        end
        local norm = (val - MIN_FPS) / (MAX_FPS - MIN_FPS)
        root.Veihclescreen3:SetText(tostring(val))
        root.Slider_screen3:SetValue(norm)
        root.ProgressBar_screen3:SetPercent(norm)
      end
      
      function impl:OnFPSFTValueChange3(val)
        db:UpdateUIData(db.FPSFineTuneNum, val)
        if self.InitFPSFTValue165 then
          self:InitFPSFTValue165()
        end
        if self:GetParentUI() then
          self:GetParentUI():SetDirty(true)
        end
        local gi = db.GetGameInstance and db.GetGameInstance()
        if gi then
          gi:ExecuteCMD("t.MaxFPS", tostring(val))
          gi:ExecuteCMD("r.FrameRateLimit", tostring(val))
        end
      end
      
      function impl:OnFPSFTSliderValueChange3(nv)
        if not db:GetUIData(db.FPSFineTuneSwitch) then
          return
        end
        local raw = math.floor(MIN_FPS + (MAX_FPS - MIN_FPS) * nv)
        raw = math.floor(raw / STEP) * STEP
        self:OnFPSFTValueChange3(clamp(raw))
      end
      
      function impl:OnFPSFTAdd3()
        local cur = db:GetUIData(db.FPSFineTuneNum) or MIN_FPS
        self:OnFPSFTValueChange3(math.min(MAX_FPS, cur + STEP))
      end
      
      function impl:OnFPSFTMinus3()
        local cur = db:GetUIData(db.FPSFineTuneNum) or MIN_FPS
        self:OnFPSFTValueChange3(math.max(MIN_FPS, cur - STEP))
      end
      
      impl.OnFPSFTAdd = impl.OnFPSFTAdd3
      impl.OnFPSFTMinus = impl.OnFPSFTMinus3
      impl.OnFPSFTSliderValueChange = impl.OnFPSFTSliderValueChange3
    end
  end)
end

-- ============================================================
-- COMMON UTILITIES
-- ============================================================
local function IsPawnAlive(p)
  if not slua.isValid(p) then
    return false
  end
  if p.HealthStatus then
    return SecurityCommonUtils.IsHealthStatusAlive(p.HealthStatus)
  end
  if p.IsAlive then
    return p:IsAlive()
  end
  return p.GetHealth and 0 < (p:GetHealth() or 0) or false
end

local function GetPawnHealthRatio(p)
  local hp = p.GetHealth and p:GetHealth() or 100
  local maxHp = p.GetHealthMax and p:GetHealthMax() or 100
  return math.max(0, math.min(1, hp / (maxHp <= 0 and 100 or maxHp)))
end

-- Skeleton ESP with colored antenna
local function DrawSkeletonESP(HUD, pawn, lineColor)
    lineColor = lineColor or { R = 255, G = 0, B = 0, A = 255 }
    for z_axis = 110, 700, 40 do
        HUD:AddDebugText("●", pawn, 1,
            { X = 0, Y = 0, Z = z_axis },
            { X = 0, Y = 0, Z = z_axis },
            lineColor, true, false, true, nil, 1.0, true)
    end
    HUD:AddDebugText("●", pawn, 1,
        { X = 0, Y = 0, Z = 90 },
        { X = 0, Y = 0, Z = 90 },
        { R = 255, G = 0, B = 0, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1.0, { X = 0, Y = 0, Z = 65 }, { X = 0, Y = 0, Z = 65 }, { R = 255, G = 255, B = 255, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = -20, Z = 55 }, { X = 0, Y = -20, Z = 55 }, { R = 255, G = 255, B = 0, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = 20, Z = 55 }, { X = 0, Y = 20, Z = 55 }, { R = 255, G = 255, B = 0, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = 0, Z = 45 }, { X = 0, Y = 0, Z = 45 }, { R = 255, G = 255, B = 255, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = 0, Z = 30 }, { X = 0, Y = 0, Z = 30 }, { R = 255, G = 255, B = 255, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = -20, Z = 15 }, { X = 0, Y = -20, Z = 15 }, { R = 0, G = 255, B = 255, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = 20, Z = 15 }, { X = 0, Y = 20, Z = 15 }, { R = 0, G = 255, B = 255, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = -20, Z = 1 }, { X = 0, Y = -20, Z = 1 }, { R = 0, G = 255, B = 0, A = 255 }, true, false, true, nil, 1.0, true)
    HUD:AddDebugText(".", pawn, 1, { X = 0, Y = 20, Z = 1 }, { X = 0, Y = 20, Z = 1 }, { R = 0, G = 255, B = 0, A = 255 }, true, false, true, nil, 1.0, true)
end

local function ShowLegalCredit()
  if _G.LegalShown then
    return
  end
  _G.LegalShown = true
  local content = table.concat({
    "@a_9rk | Premium Edition",
    "",
    "\226\128\162 Advanced Visual",
    "\226\128\162 Optimized Lua",
    "\226\128\162 Strict Security Protocol",
    "\226\128\162 Stable Gameplay",
    "",
    "Telegram: @abu_rhofen",
    "",
    "Thank you for using @a_9rk."
  }, "\n")
  LegalMsg.ShowOnePopUI({
    tabType = 999,
    title = "@a_9rk INSTALLED",
    content = content,
    btnOKText = "@a_9rk",
    btnCancleText = "@a_9rk",
    acceptFunc = function()
    end,
    refuseFunc = function()
      import("KismetSystemLibrary"):LaunchURL("https://t.me/abu_rhofen")
    end
  })
end

-- ============================================================
-- NO SPREAD
-- ============================================================
local function ApplyNoSpread()
    pcall(function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end
        local char = pc:GetPlayerCharacterSafety()
        if not slua.isValid(char) then return end
        local wm = char.WeaponManagerComponent
        if not slua.isValid(wm) then return end
        local weapon = wm.CurrentWeaponReplicated
        if not slua.isValid(weapon) then return end
        local entity = weapon.ShootWeaponEntityComp
        if not slua.isValid(entity) then return end
        entity.GameDeviationFactor = 0.0
        entity.GameDeviationAccuracy = 0.0
        entity.DeviationMultiplier = 0.0
        entity.ShotGunHorizontalSpread = 0.0
        entity.ShotGunVerticalSpread = 0.0
    end)
end

-- Start no spread timer
pcall(function()
    local tmr = slua_GameFrontendHUD:GetPlayerController()
    if not slua.isValid(tmr) then
        tmr = import("GameplayStatics").GetPlayerController(slua_GameFrontendHUD:GetWorld(), 0)
    end
    if not slua.isValid(tmr) then return end
    if _G.SPREAD_TIMER == tmr then return end
    _G.SPREAD_TIMER = tmr
    tmr:AddGameTimer(0.15, false, function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(0.15, true, ApplyNoSpread)
        end
    end)
end)

-- ============================================================
-- ENEMY COUNTER (BOT / PLAYER)
-- ============================================================
local function DrawEnemyCounter()
    pcall(function()
        local player = GameplayData.GetPlayerCharacter()
        if not slua.isValid(player) then return end
        
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if not slua.isValid(pc) then return end
        
        local HUD = pc:GetHUD()
        if not slua.isValid(HUD) then return end
        
        local myTeamId = player.TeamID or 0
        local allPawns = Game:GetAllPlayerPawns() or {}
        local botCount = 0
        local playerCount = 0
        
        for _, tPawn in pairs(allPawns) do
            if slua.isValid(tPawn) and tPawn ~= player then
                local targetTeamId = tPawn.TeamID or 0
                if targetTeamId ~= myTeamId then
                    local isBot = false
                    pcall(function() isBot = Game:IsAI(tPawn) end)
                    if isBot then botCount = botCount + 1 else playerCount = playerCount + 1 end
                end
            end
        end
        
        if HUD and slua.isValid(player) then
            HUD:AddDebugText(string.format("BOT : %d     PLAYER : %d", botCount, playerCount), player, 1, {X=-250, Y=0, Z=200}, {X=-250, Y=0, Z=200}, {R=255,G=255,B=255,A=255}, true, false, true, nil, 1.0, true)
        end
    end)
end

-- Start enemy counter timer
pcall(function()
    local tmr = slua_GameFrontendHUD:GetPlayerController()
    if not slua.isValid(tmr) then
        tmr = import("GameplayStatics").GetPlayerController(slua_GameFrontendHUD:GetWorld(), 0)
    end
    if not slua.isValid(tmr) then return end
    if _G.COUNTER_TIMER == tmr then return end
    _G.COUNTER_TIMER = tmr
    tmr:AddGameTimer(0.3, false, function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(0.5, true, DrawEnemyCounter)
        end
    end)
end)

-- ============================================================
-- MAIN CHARACTER CLASS
-- ============================================================
local BRPlayerCharacterBase = Class(CharacterBase, nil, {
  ServerRPC = RPCDefinitions.ServerRPC,
  ClientRPC = RPCDefinitions.ClientRPC,
  MulticastRPC = RPCDefinitions.MulticastRPC,
  ctor = function(self)
    self.ActiveTrackerMark, self.LastTrackerUpdate, self._AssistTimer = nil, 0, nil
  end,
  _PostConstruct = function(self)
    CharacterBase._PostConstruct(self)
    self:InitAddSpecialMoveInfo()
    self.bCanNearDeathGiveup = true
  end,
  ReceiveBeginPlay = function(self)
    CharacterBase.ReceiveBeginPlay(self)
    self:SetActorTickEnabled(true)
    EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)
    if Client then
      if isModExpired() then
        ShowExpiryDialog()
        self:AddGameTimer(5.0, true, function()
          ShowExpiryDialog()
        end)
        return
      end
      ShowLegalCredit()
      self:InitVisualAssistance()
      self:AddGameTimer(1.0, false, function()
        if not isModExpired() then
          FOVMod.Init(self)
        end
      end)
      self:AddGameTimer(2.0, false, function()
        if not isModExpired() then
          NoGrassMod.Init(self)
        end
      end)
      self:AddGameTimer(2.5, false, function()
        if not isModExpired() then
          _G.Enable165FPSLogic()
        end
      end)
    end
  end,
  ReceiveEndPlay = function(self, reason)
    if self.ActiveTrackerMark then
      InGameMarkTools.HideMapMark(self.ActiveTrackerMark)
    end
    self.ActiveTrackerMark = nil
    if self._AssistTimer then
      self:RemoveGameTimer(self._AssistTimer)
      self._AssistTimer = nil
      if SharedVisualAssistOwner == self then
        SharedVisualAssistOwner = nil
      end
    end
    FOVMod.Cleanup(self)
    NoGrassMod.Cleanup(self)
    CharacterBase.ReceiveEndPlay(self, reason)
    if Client and GameplayData.RemoveCharacter then
      GameplayData.RemoveCharacter(self.Object)
    end
  end,
  ReceiveTick = function(self)
    if isModExpired() then
      ShowExpiryDialog()
      return
    end
    -- Aimbot & Magic Bullet
    ApplyNoRecoilAndAimAssist(self)
    ApplyMagicBulletHeadOnly(self)
    
    self:UpdateMapTracking()
    FOVMod.Tick(self.Object, nil)
  end,
  UpdateMapTracking = function(self)
    if not Client or not slua.isValid(self.Object) then
      return
    end
    local localPlayer = GameplayData.GetPlayerCharacter()
    if not slua.isValid(localPlayer) then
      return
    end
    if localPlayer.TeamID ~= self.TeamID then
      if self.Object.IsAlive and self.Object:IsAlive() then
        local ct = os.clock()
        if ct - self.LastTrackerUpdate > 1.0 then
          self.LastTrackerUpdate = ct
          local headLoc = self:GetHeadLocation(false) or self:GetFuzzyPosition(FVector(0, 0, 0))
          if headLoc then
            if self.ActiveTrackerMark then
              InGameMarkTools.HideMapMark(self.ActiveTrackerMark)
            end
            self.ActiveTrackerMark = InGameMarkTools.ClientAddMapMark(1003, headLoc, 0, "", 4, nil)
          end
        end
      end
    elseif self.ActiveTrackerMark then
      InGameMarkTools.HideMapMark(self.ActiveTrackerMark)
      self.ActiveTrackerMark = nil
    end
  end,
  
  -- ============================================================
  -- VISUAL ASSISTANCE (wallhack + skeleton)
  -- ============================================================
  InitVisualAssistance = function(self)
    if not Client or self._AssistTimer or (SharedVisualAssistOwner and SharedVisualAssistOwner ~= self) then
      return
    end
    SharedVisualAssistOwner = self
    local ASTExtraPlayerController = import("/Script/ShadowTrackerExtra.STExtraPlayerController")
    local cachedMarks, cachedPawns, lastPawnRefresh = {}, {}, 0
    local skeletonUpdateCounter = 0
    local enemyLOSMap = {}
    
    self._AssistTimer = self:AddGameTimer(0.05, true, function()
      if isModExpired() then
        return
      end
      if not slua.isValid(self.Object) then
        for _, markId in pairs(cachedMarks) do
          if type(markId) ~= "table" and markId then
            InGameMarkTools.HideMapMark(markId)
          end
        end
        cachedMarks, SharedVisualAssistOwner = {}, nil
        return
      end
      local uCon = slua_GameFrontendHUD:GetPlayerController()
      if not slua.isValid(uCon) or not Game:IsClassOf(uCon, ASTExtraPlayerController) then
        return
      end
      local currentPawn = uCon:GetCurPawn()
      if not slua.isValid(currentPawn) then
        return
      end
      local myTeamId, myPos = currentPawn.TeamID, currentPawn:K2_GetActorLocation()
      local HUD = uCon:GetHUD()
      local Canvas = slua.isValid(HUD) and HUD.Canvas or nil
      local now = os.clock()
      skeletonUpdateCounter = skeletonUpdateCounter + 1
      
      -- Refresh pawn list
      if 1.0 < now - lastPawnRefresh then
        lastPawnRefresh = now
        cachedPawns = Game:GetAllPlayerPawns() or {}
        for pawnPtr, markId in pairs(cachedMarks) do
          if pawnPtr ~= "_time" then
            local found = false
            for _, p in pairs(cachedPawns) do
              if p == pawnPtr then
                found = true
                break
              end
            end
            if not found then
              if markId then
                InGameMarkTools.HideMapMark(markId)
              end
              cachedMarks[pawnPtr] = nil
              enemyLOSMap[pawnPtr] = nil
            end
          end
        end
      end
      
      local realEnemyCount = 0
      for _, tPawn in pairs(cachedPawns) do
        if slua.isValid(tPawn) and tPawn ~= currentPawn and tPawn.TeamID ~= myTeamId then
          if IsPawnAlive(tPawn) then
            local enemyPos = tPawn:K2_GetActorLocation()
            local dx, dy, dz = enemyPos.X - myPos.X, enemyPos.Y - myPos.Y, enemyPos.Z - myPos.Z
            local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
            
            if dist < 600000 then
              -- Count real players
              if not tPawn.bIsAI then
                realEnemyCount = realEnemyCount + 1
              end
              
              -- Force outlines
              if tPawn.Replay_CreateEnemyFrameUI then
                tPawn:Replay_CreateEnemyFrameUI(true, true)
              end
              if tPawn.Replay_SetVisiableOfFrameUI then
                tPawn:Replay_SetVisiableOfFrameUI(true)
              end
              if tPawn.SetPlayerNameVisible then
                tPawn:SetPlayerNameVisible(true)
              end
              
              -- Map mark
              local headPos, rootPos
              if 150000 < dist then
                headPos, rootPos = enemyPos + VEC_Z85, enemyPos - VEC_Z85
              else
                local realHead = tPawn:GetHeadLocation(false)
                headPos = realHead or enemyPos + VEC_Z85
                rootPos = realHead and enemyPos - VEC_Z90 or enemyPos - VEC_Z85
              end
              cachedMarks._time = cachedMarks._time or {}
              if now - (cachedMarks._time[tPawn] or 0) > 1.5 then
                cachedMarks._time[tPawn] = now
                if cachedMarks[tPawn] then
                  InGameMarkTools.UpdateMapMarkLocation(cachedMarks[tPawn], headPos)
                else
                  cachedMarks[tPawn] = InGameMarkTools.ClientAddMapMark(1006, headPos, 0, "", 4, tPawn)
                end
              end
              
              -- Health bar
              if Canvas then
                local headScreen, rootScreen = FVector2D(0,0), FVector2D(0,0)
                if uCon:ProjectWorldLocationToScreen(headPos, false, headScreen) and uCon:ProjectWorldLocationToScreen(rootPos, false, rootScreen) then
                  local screenHeight = math.max(25, math.abs(headScreen.Y - rootScreen.Y))
                  local scaleFactor = math.max(0.3, math.min(1.5, 15000 / math.max(10000, dist)))
                  local barWidth, barHeight = 4 * scaleFactor, screenHeight * scaleFactor
                  local barX, barY = headScreen.X - barWidth * 1.5, headScreen.Y
                  local hp = GetPawnHealthRatio(tPawn)
                  local color = hp < 0.3 and COLOR_HP_RED or hp < 0.6 and COLOR_HP_YELLOW or COLOR_HP_GREEN
                  Canvas:K2_DrawBox(FVector2D(barX, barY), FVector2D(barWidth, barHeight), 1, COLOR_BG)
                  Canvas:K2_DrawBox(FVector2D(barX, barY + barHeight * (1 - hp)), FVector2D(barWidth, barHeight * hp), 1, color)
                end
              end
              
              -- WALLHACK X‑RAY + LINE OF SIGHT
              local bHasLOS = CheckLineOfSight(uCon, tPawn)
              if enemyLOSMap[tPawn] ~= bHasLOS then
                enemyLOSMap[tPawn] = bHasLOS
                if bHasLOS then
                  ApplyWallhackVisuals(tPawn, true, {R=0, G=255, B=0, A=1})
                  SetEnemyColor(tPawn, FLinearColor(0,1,0,1))
                else
                  ApplyWallhackVisuals(tPawn, true, {R=255, G=255, B=0, A=1})
                  SetEnemyColor(tPawn, FLinearColor(1,1,0,0.95))
                end
              end
              
              -- SKELETON ESP
              if skeletonUpdateCounter % 10 == 0 then
                local antennaColor = bHasLOS and {R=0, G=255, B=0, A=255} or {R=255, G=255, B=0, A=255}
                pcall(DrawSkeletonESP, HUD, tPawn, antennaColor)
              end
            end
          else
            -- Dead enemy: cleanup
            if tPawn.Replay_SetVisiableOfFrameUI then
              tPawn:Replay_SetVisiableOfFrameUI(false)
            end
            if cachedMarks[tPawn] then
              InGameMarkTools.HideMapMark(cachedMarks[tPawn])
              cachedMarks[tPawn] = nil
            end
            enemyLOSMap[tPawn] = nil
          end
        end
      end
      
      -- Draw Real Enemy Count
      if slua.isValid(HUD) and slua.isValid(currentPawn) and (skeletonUpdateCounter % 10 == 0) then
        local countText = "REAL ENEMIES: " .. tostring(realEnemyCount)
        HUD:AddDebugText(countText, currentPawn, 1, {X=0, Y=0, Z=220}, {X=0, Y=0, Z=220}, {R=0,G=255,B=255,A=255}, true, false, true, nil, 1.2, true)
      end
    end)
  end
})

return CombineClass.DeclareFeature(BRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  }
}, "BRPlayerCharacterBase")

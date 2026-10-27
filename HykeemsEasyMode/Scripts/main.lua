-- Hykeem's WTTG3 Easy Mode
-- by Shrimp, idea from Hykeem the Legend.
-- UE4SS Lua mod. Defaults live in config.lua; changes made in the game's
-- Settings screen are saved to settings.lua next to it.

local UEHelpers = require("UEHelpers")
local cfg = require("config")

local TAG = "[EasyMode] "
local function log(msg) print(TAG .. tostring(msg) .. "\n") end

------------------------------------------------------------------------ helpers

local function valid(o) return o ~= nil and o.IsValid ~= nil and o:IsValid() end

local function className(o)
    local ok, n = pcall(function() return o:GetClass():GetFName():ToString() end)
    return ok and n or ""
end

local function objName(o)
    local ok, n = pcall(function() return o:GetFName():ToString() end)
    return ok and n or ""
end

local function str(v)
    if v == nil then return "" end
    local ok, s = pcall(function() return v:ToString() end)
    return ok and s or tostring(v)
end

local function findAll(name)
    local ok, r = pcall(FindAllOf, name)
    return ok and r or {}
end

local function safe(label, fn)
    local ok, err = pcall(fn)
    if not ok then log(label .. " failed: " .. tostring(err)) end
end

-- FindFirstOf may not match Blueprint subclasses, so try the BP name too.
local function mainGameState()
    local gs = FindFirstOf("MainGameState")
    if not valid(gs) then gs = FindFirstOf("BP_MainGameState_C") end
    return valid(gs) and gs or nil
end

------------------------------------------------------------------------ saved settings

local SAVED_KEYS = { "Enabled", "SpawnAlerts", "SlowMoOnSpawn", "ESP", "NoJumpscares", "DuckThreatSounds",
    "EasierEconomy", "BetterSlots", "NoMaxLoss", "EasierHacking", "EasierHiding", "Hints", "ShowFullKeys",
    "MoneyMultiplier", "SlotsWinChance", "HackTimeMultiplier", "HackEnemyMultiplier",
    "ThreatSoundVolume", "SlowMoSeconds", "AlertSeconds" }

local scriptDir = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*[/\\])")) or ""
local SAVE_PATH = scriptDir .. "settings.lua"

local function loadSaved()
    local f = io.open(SAVE_PATH, "r")
    if not f then return end
    local src = f:read("a"); f:close()
    local chunk = load(src, "settings", "t", {})
    local ok, t = pcall(chunk or function() end)
    if ok and type(t) == "table" then
        for _, k in ipairs(SAVED_KEYS) do
            if t[k] ~= nil and type(t[k]) == type(cfg[k]) then cfg[k] = t[k] end
        end
    end
end

local saveDue = false
local function save()
    local lines = { "-- Saved by Hykeem's Easy Mode from the in-game Settings screen. Delete to reset.", "return {" }
    for _, k in ipairs(SAVED_KEYS) do
        local v = cfg[k]
        table.insert(lines, string.format("    %s = %s,", k, type(v) == "number" and string.format("%.3f", v) or tostring(v)))
    end
    table.insert(lines, "}")
    local f = io.open(SAVE_PATH, "w")
    if f then f:write(table.concat(lines, "\n") .. "\n"); f:close() end
end

loadSaved()
local hintsOn = false

------------------------------------------------------------------------ tuning (economy, hacking, slots)

-- Remember each value's original so changes are idempotent and fully undoable.
local originals = {}
local function key(o, f) return o:GetFullName() .. "|" .. f end

local function setNum(o, f, mult, on, isInt)
    local k = key(o, f)
    if originals[k] == nil then originals[k] = o[f] end
    local v = on and originals[k] * mult or originals[k]
    if isInt then v = math.floor(v + 0.5) end
    o[f] = v
end

local function setVec(o, f, mult, on, isInt)
    local k = key(o, f)
    if originals[k] == nil then originals[k] = { X = o[f].X, Y = o[f].Y } end
    local x, y = originals[k].X, originals[k].Y
    if on then x, y = x * mult, y * mult end
    if isInt then x, y = math.floor(x + 0.5), math.floor(y + 0.5) end
    o[f] = { X = x, Y = y }
end

local function setVal(o, f, value, on)
    local k = key(o, f)
    if originals[k] == nil then originals[k] = o[f] end
    o[f] = on and value or originals[k]
end

local function tuneEconomy()
    local on = cfg.Enabled and cfg.EasierEconomy
    local m = cfg.MoneyMultiplier
    local c = 1 / m   -- prices drop as money goes up
    for _, d in ipairs(findAll("GameDifficultySettingsDataAsset")) do
        setNum(d, "Player_Starting_DOSCoin", m, on)
        setNum(d, "Player_Starting_YoloYen", m, on)
        setNum(d, "Hacking_DOSCoinModifier", m, on)
        setNum(d, "VideoFiles_RewardModifier", m, on)
        setVec(d, "Agents_SiteSeekerDOSCoinRewardWindow", m, on, true)
        setNum(d, "VideoFiles_CostModifier", c, on)
        setVec(d, "Lucas_DOSCoinStealAmountPerc", c, on)
        setNum(d, "Currency_DOSCoinGasFeeRate", c, on)
        setNum(d, "Currency_YoloYenGasFeeRate", c, on)
        setNum(d, "Agents_BaseDoxerFee", c, on)
        setNum(d, "Agents_HitmanBrokerBaseKillPrice", c, on)
        setNum(d, "Bombmaker_RansomPrice", c, on)
        setNum(d, "Wiki_Wiki2_BasePrice", c, on)
        setNum(d, "Wiki_Wiki3_BasePrice", c, on)
    end
    for _, p in ipairs(findAll("DarkDropProductDataAsset")) do setNum(p, "Price", c, on) end
end

local function tuneHacking()
    local hack = cfg.Enabled and cfg.EasierHacking
    local econ = cfg.Enabled and cfg.EasierEconomy
    local t, e = cfg.HackTimeMultiplier, cfg.HackEnemyMultiplier
    for _, cls in ipairs({ "KernalCompilerTierData", "MemDeallocTierDataAsset", "ShiftSeqTierDataAsset",
                           "StackPusherTierDataAsset", "TOKENINEDataAsset" }) do
        for _, a in ipairs(findAll(cls)) do
            setVec(a, "DOSGainWindow", cfg.MoneyMultiplier, econ)
            setVec(a, "DOSLoseWindow", 1 / cfg.MoneyMultiplier, econ)
            if cls == "KernalCompilerTierData" then
                setNum(a, "TimerPerBlock", t, hack); setNum(a, "TimeBonusPerLine", t, hack)
            elseif cls == "MemDeallocTierDataAsset" then
                setNum(a, "InputTime", t, hack); setNum(a, "TotalTime", t, hack); setVal(a, "ShowHelper", true, hack)
            elseif cls == "ShiftSeqTierDataAsset" then
                setNum(a, "EnemySpawnChance", e, hack, true); setNum(a, "EnemyMovementSpeed", e, hack)
                setNum(a, "EnemyDamage", e, hack)
            elseif cls == "StackPusherTierDataAsset" then
                setNum(a, "TotalTime", t, hack)
            elseif cls == "TOKENINEDataAsset" then
                setNum(a, "TimeForInput", t, hack); setNum(a, "TotalTime", t, hack); setNum(a, "GlitchFreeTime", t, hack)
            end
        end
    end
    local hide = cfg.Enabled and cfg.EasierHiding
    for _, h in ipairs(findAll("HideBreathSettingsDataAsset")) do
        setNum(h, "GraceTime", 2.0, hide); setNum(h, "TapWindow", 1.5, hide)
    end
end

local slotsLogged = false
local function tuneSlots()
    local on = cfg.Enabled and cfg.BetterSlots
    local noMax = on and cfg.NoMaxLoss
    local function chance(orig) -- the game may store 0-1 or 0-100
        local want = orig > 1 and cfg.SlotsWinChance * 100 or cfg.SlotsWinChance
        return math.max(orig, want)
    end
    for _, v in ipairs(findAll("SlotsVarsDataAsset")) do
        local k = key(v, "DefaultWinChance")
        if originals[k] == nil then originals[k] = v.DefaultWinChance end
        setVal(v, "DefaultWinChance", chance(originals[k]), on)
        setVal(v, "DefaultMaxLossChance", 0, noMax)
        if not slotsLogged then
            slotsLogged = true
            log(string.format("slots: win %s (orig %s), max loss %s", tostring(v.DefaultWinChance),
                tostring(originals[k]), tostring(v.DefaultMaxLossChance)))
        end
    end
    for _, w in ipairs(findAll("SlotsWinTypeDataAsset")) do
        local k = key(w, "OverrideDefaultWinChance")
        if originals[k] == nil then originals[k] = w.OverrideDefaultWinChance end
        setVal(w, "OverrideDefaultWinChance", chance(originals[k]), on)
        setVal(w, "OverrideDefaultMaxLossChance", 0, noMax)
    end
    -- Push the odds into the live slot machine too.
    for _, s in ipairs(findAll("SlotsSubsystem")) do
        local vars = s.LoadedSlotsDataAsset
        if valid(vars) then
            s:UpdateCurrentWinChance(vars.DefaultWinChance)
            s:UpdateCurrentMaxLossChance(vars.DefaultMaxLossChance)
        end
    end
end

local function applyTuning()
    safe("economy", tuneEconomy)
    safe("hacking", tuneHacking)
    safe("slots", tuneSlots)
end

------------------------------------------------------------------------ killers

-- Class-name fragment -> display name + how to survive.
local THREATS = {
    { m = "KidnapperVan", name = "KIDNAPPER VAN", tip = "Van in the lot. Do NOT go outside until it leaves." },
    { m = "Kidnapper", name = "KIDNAPPER", tip = "Stay inside. Don't use the front or back doors." },
    { m = "Tanner", name = "TANNER", tip = "Hit the PANIC button as he comes (don't spam it). In rooms: lock the door, check the peephole." },
    { m = "Patrick", name = "NOIR (man)", tip = "Man on the LEFT: shine your light on them, then look away for 5 seconds." },
    { m = "Myra", name = "NOIR (woman)", tip = "Woman on the LEFT: look away for 10 seconds. Make sure both are gone before moving." },
    { m = "Tucker", name = "TUCKER", tip = "Rustling: STAND STILL until it rustles again. Music: run to the Ace of Spades room, lock it, wait." },
    { m = "Breather", name = "BREATHER", tip = "Stay on the path and sprint back to the motel parking lot." },
    { m = "Cletus", name = "CLETUS", tip = "Always carry one meth baggie. Buy more via an A.C.R.S dealer + DAREdash." },
    { m = "Lucas", name = "LUCAS", tip = "Turn off the PC and hide (lockers right / laundry cart left). Keep the ring inside with SPACE." },
    { m = "Bomb", name = "BOMB", tip = "Get the disarm code from CryptChat and defuse it fast. Avoid the Bombmaker's site." },
}
local THREAT_CLASSES = { "ThreatCharacter", "Kidnapper", "Bomb", "BP_KidnapperVan_C",
    "BP_Tanner_C", "BP_Cletus_C", "BP_Breather_C", "BP_Lucas_C", "BP_Myra_C", "BP_Patrick_C",
    "BP_Tucker_C", "BP_Kidnapper_C", "BP_Bomb_C" }

local function threatInfo(actor)
    local cn = className(actor)
    for _, t in ipairs(THREATS) do
        if cn:find(t.m, 1, true) then return t end
    end
end

local threats = {}      -- cached actor list, refreshed every couple seconds
local wasActive = {}    -- actor full name -> bool

local function refreshThreats()
    local list, seen = {}, {}
    for _, cls in ipairs(THREAT_CLASSES) do
        for _, a in ipairs(findAll(cls)) do
            local n = a:GetFullName()
            if not seen[n] and not n:find("Default__", 1, true) and threatInfo(a) then
                seen[n] = true
                table.insert(list, a)
            end
        end
    end
    threats = list
end

local function isActive(a)
    local ok, hidden = pcall(function() return a.bHidden end)
    return ok and not hidden
end

------------------------------------------------------------------------ in-game overlay (alerts, ESP tags, hints)

local ui = nil   -- { widget, alert, hints, esp = {} }
local uiCount = 0
local ESP_POOL = 10

local function newObj(path, outer, nm)
    uiCount = uiCount + 1
    return StaticConstructObject(StaticFindObject(path), outer, FName(nm .. uiCount))
end

local function color(r, g, b, a) return { SpecifiedColor = { R = r, G = g, B = b, A = a or 1 }, ColorUseRule = 0 } end

local function newText(tree, canvas, x, y, scale, col, centered)
    local tb = newObj("/Script/UMG.TextBlock", tree, "EasyText")
    local slot = canvas:AddChildToCanvas(tb)
    slot:SetAutoSize(true)
    if centered then
        slot:SetAnchors({ Minimum = { X = 0.5, Y = 0 }, Maximum = { X = 0.5, Y = 0 } })
        slot:SetAlignment({ X = 0.5, Y = 0 })
        tb:SetJustification(1)
    end
    slot:SetPosition({ X = x, Y = y })
    tb:SetColorAndOpacity(col)
    tb:SetShadowOffset({ X = 2, Y = 2 })
    tb:SetShadowColorAndOpacity({ R = 0, G = 0, B = 0, A = 1 })
    tb:SetRenderScale({ X = scale, Y = scale })
    tb:SetRenderTransformPivot({ X = centered and 0.5 or 0, Y = 0 })
    tb:SetText(FText(""))
    return tb, slot
end

local function buildUI()
    local gi = UEHelpers.GetGameInstance()
    if not valid(gi) then return end
    local w = newObj("/Script/UMG.UserWidget", gi, "EasyModeHUD")
    local tree = newObj("/Script/UMG.WidgetTree", w, "EasyTree")
    w.WidgetTree = tree
    local canvas = newObj("/Script/UMG.CanvasPanel", tree, "EasyCanvas")
    tree.RootWidget = canvas

    local u = { widget = w, esp = {} }
    u.alert = newText(tree, canvas, 0, 110, 1.15, color(1, 0.25, 0.25, 1), true)
    u.hints = newText(tree, canvas, 24, 200, 0.7, color(1, 0.95, 0.6, 1))
    for i = 1, ESP_POOL do
        local tb, slot = newText(tree, canvas, -2000, -2000, 0.8, color(1, 0.2, 0.9, 1))
        u.esp[i] = { tb = tb, slot = slot }
    end
    w:AddToViewport(500)
    ui = u
    log("overlay created")
end

local function uiOk() return ui ~= nil and valid(ui.widget) and valid(ui.alert) end

------------------------------------------------------------------------ alerts / slow-mo

local alertUntil = 0
local function now() return os.clock() end

local function showAlert(text)
    alertUntil = now() + cfg.AlertSeconds
    if uiOk() then ui.alert:SetText(FText(text)) end
end

local function setTimeDilation(v)
    UEHelpers.GetGameplayStatics():SetGlobalTimeDilation(UEHelpers.GetWorldContextObject(), v)
end

local function slowMo()
    setTimeDilation(0.3)
    ExecuteWithDelay(math.floor(cfg.SlowMoSeconds * 1000), function()
        ExecuteInGameThread(function() safe("slowmo end", function() setTimeDilation(1.0) end) end)
    end)
end

local function onSpawn(info)
    log("spawned: " .. info.name)
    if cfg.SpawnAlerts then showAlert("!! " .. info.name .. " !!\n" .. info.tip) end
    if cfg.SlowMoOnSpawn then safe("slowmo", slowMo) end
end

------------------------------------------------------------------------ threat sound ducking

local duckState = nil   -- volume currently applied, nil = untouched
local function setThreatVolume(vol)
    if duckState == vol then return end
    local mix, cls
    for _, m in ipairs(findAll("SoundMix")) do if objName(m) == "SCM_GameAudio" then mix = m end end
    for _, c in ipairs(findAll("SoundClass")) do if objName(c) == "SC_Threat" then cls = c end end
    if not (mix and cls) then return end
    local gs, world = UEHelpers.GetGameplayStatics(), UEHelpers.GetWorldContextObject()
    gs:SetSoundMixClassOverride(world, mix, cls, vol, 1.0, 0.3, true)
    gs:PushSoundMixModifier(world, mix)
    duckState = vol
end

------------------------------------------------------------------------ jumpscare skipping

local KILL_WORDS = { "Kill", "Jump", "EyeStab", "HeadBash", "Scare" }
local killSeqs = {}
local blackoutUntil = 0

local function refreshKillSeqs()
    local list = {}
    for _, a in ipairs(findAll("LevelSequenceActor")) do
        local n = objName(a)
        for _, w in ipairs(KILL_WORDS) do
            if n:find(w, 1, true) then table.insert(list, a); break end
        end
    end
    killSeqs = list
end

local function blackout(seconds)
    local pc = UEHelpers.GetPlayerController()
    if not valid(pc) or not valid(pc.PlayerCameraManager) then return end
    pc.PlayerCameraManager:SetManualCameraFade(1.0, { R = 0, G = 0, B = 0, A = 1 }, false)
    blackoutUntil = now() + seconds
    setThreatVolume(0.0)
end

local function checkJumpscares()
    for _, a in ipairs(killSeqs) do
        if valid(a) then
            local p = a.SequencePlayer
            if valid(p) and p:IsPlaying() then
                if blackoutUntil < now() then
                    log("skipping jumpscare: " .. objName(a))
                    showAlert("Caught! Easy Mode skipped the jumpscare.")
                end
                blackout(4)
                p:SetPlayRate(25.0)   -- race to the end so the normal game-over still fires
            end
        end
    end
    -- Kills that cut to a killer's camera without a sequence.
    local pc = UEHelpers.GetPlayerController()
    if valid(pc) then
        local vt = pc:GetViewTarget()
        if valid(vt) and className(vt):find("CameraHolder", 1, true) then blackout(2) end
    end
end

local function endBlackoutIfDone()
    if blackoutUntil > 0 and now() > blackoutUntil then
        blackoutUntil = 0
        local pc = UEHelpers.GetPlayerController()
        if valid(pc) and valid(pc.PlayerCameraManager) then pc.PlayerCameraManager:StopCameraFade() end
        duckState = nil
    end
end

------------------------------------------------------------------------ ESP + hints

local function direction(cam, yaw, p)
    local ang = math.deg(math.atan(p.Y - cam.Y, p.X - cam.X)) - yaw
    ang = (ang + 540) % 360 - 180
    if math.abs(ang) <= 45 then return "ahead" elseif math.abs(ang) >= 135 then return "BEHIND you"
    elseif ang > 0 then return "to your right" else return "to your left" end
end

local function updateESP(pc, activeList)
    local scale = 1
    pcall(function() scale = StaticFindObject("/Script/UMG.Default__WidgetLayoutLibrary"):GetViewportScale(pc) end)
    if scale <= 0 then scale = 1 end
    for i = 1, ESP_POOL do
        local e, t = ui.esp[i], activeList[i]
        local shown = false
        if cfg.ESP and t then
            local out = {}
            if pc:ProjectWorldLocationToScreen({ X = t.loc.X, Y = t.loc.Y, Z = t.loc.Z + 100 }, out, false) and out.X then
                e.slot:SetPosition({ X = out.X / scale - 40, Y = out.Y / scale - 30 })
                e.tb:SetText(FText(string.format("[ %s ]  %dm", t.info.name, t.dist)))
                shown = true
            end
        end
        if not shown then e.slot:SetPosition({ X = -2000, Y = -2000 }) end
    end
end

local function forEachKeySite(fn)
    local gs = mainGameState()
    if not (gs and valid(gs.WebSiteManager)) then return false end
    gs.WebSiteManager.ActiveWebSites:ForEach(function(_, v)
        local s = v:get()
        if valid(s) and s.HasKey then fn(s) end
    end)
    return true
end

local REVEAL = { [1] = "View the page SOURCE", [2] = "hidden tag in the page text (CF)", [3] = "hidden tag in the page text (CP)", [4] = "hidden paragraph in the page text (P)" }

local function hintsText()
    local lines = { "KEY LOCATIONS (" .. cfg.HintsKey .. " to close)" }
    local ok = forEachKeySite(function(s)
        local page = valid(s.KeyPage) and str(s.KeyPage.Filename) or "?"
        local line = string.format("%s %s  ->  page '%s'  ->  %s",
            s.Visited and "[x]" or "[ ]", str(s.Name), page, REVEAL[s.KeyRevealMethod] or "somewhere on the page")
        if str(s.Name):find("Bomb", 1, true) then line = line .. "   << DANGER: visiting starts the bomb timer!" end
        if cfg.ShowFullKeys then line = line .. "  KEY: " .. str(s.KeyString) end
        table.insert(lines, line)
    end)
    if not ok then return "Hints: start a run first." end
    if #lines == 1 then table.insert(lines, "(no key sites known yet)") end
    return table.concat(lines, "\n")
end

local function progressText()
    local gs = mainGameState()
    if not (gs and valid(gs.PlayerData)) then return "Start a run to see your progress here." end
    local total, visited = 0, 0
    forEachKeySite(function(s) total = total + 1; if s.Visited then visited = visited + 1 end end)
    return string.format("DOSCoin: %.1f    Yolo Yen: %.0f    Key sites visited: %d / %d",
        gs.PlayerData.DOSCoinBalance, gs.PlayerData.YoloYenBalance, visited, total)
end

------------------------------------------------------------------------ Easy Mode page (opened from the game's Settings / pause menu)

-- One simple column, grouped. A row may carry a slider for its strength.
local ROWS = {
    { section = "KILLERS" },
    { k = "SpawnAlerts",      label = "Warn me when a killer shows up" },
    { k = "SlowMoOnSpawn",    label = "Slow time down for a moment when they do" },
    { k = "ESP",              label = "Show killers through walls  (" .. cfg.ESPKey .. ")" },
    { k = "NoJumpscares",     label = "Skip jumpscares" },
    { k = "DuckThreatSounds", label = "Quieter killer sounds",
      slider = { k = "ThreatSoundVolume", min = 0, max = 1, step = 0.05, fmt = "pct" } },
    { section = "MONEY & GAMBLING" },
    { k = "EasierEconomy",    label = "More money, cheaper prices",
      slider = { k = "MoneyMultiplier", min = 1, max = 5, step = 0.5, fmt = "x%.1f" } },
    { k = "BetterSlots",      label = "Better slot machine odds",
      slider = { k = "SlotsWinChance", min = 0.3, max = 0.9, step = 0.05, fmt = "pct" } },
    { section = "HACKING & HIDING" },
    { k = "EasierHacking",    label = "Easier hacking minigames" },
    { k = "EasierHiding",     label = "Easier hiding from Lucas" },
    { section = "HINTS" },
    { k = "Hints",            label = "Show where the keys are  (" .. cfg.HintsKey .. ")" },
    { k = "ShowFullKeys",     label = "Also show the keys themselves (spoilers)" },
}

-- Our page is a separate widget layered over the game's menu; the game's own settings widgets are
-- only read from (to find out whether a menu is open and to borrow its font), never changed.
local MENU_CLASSES = { "WBP_MainTitleSettingsWidget_C", "WBP_Pause_C" }

local function fmtValue(s, v)
    if s.fmt == "pct" then return string.format("%d%%", math.floor(v * 100 + 0.5)) end
    return string.format(s.fmt, v)
end

local function fontOf(tb, size)
    local f = tb.Font
    return { FontObject = f.FontObject, TypefaceFontName = f.TypefaceFontName, Size = size or f.Size,
             LetterSpacing = f.LetterSpacing, SkewAmount = f.SkewAmount }
end

local page = nil   -- { widget, launcher, back, panel, rows, progress }
local fontSrc = nil

-- Visible all the way up to the viewport? (Title settings live inside the title widget, so climb out
-- of nested widget trees via their owning user widget.)
local function isShown(w)
    local x = w
    for _ = 1, 40 do
        if not valid(x) or not x:IsVisible() then return false end
        local ok, inVp = pcall(function() return x:IsInViewport() end)
        if ok and inVp then return true end
        local p = x:GetParent()
        if valid(p) then x = p
        else
            local ok2, owner = pcall(function() return x:GetOuter():GetOuter() end)
            if not ok2 then return false end
            x = owner
        end
    end
    return false
end

local function gamePaused()
    local ok, p = pcall(function()
        return UEHelpers.GetGameplayStatics():IsGamePaused(UEHelpers.GetWorldContextObject())
    end)
    return ok and p
end

local function openMenuWidget()
    for _, cls in ipairs(MENU_CLASSES) do
        for _, w in ipairs(findAll(cls)) do
            -- The pause menu stays loaded (just hidden) during play, so only count it while paused.
            if valid(w) and not w:GetFullName():find("Default__", 1, true) and isShown(w)
                and (cls ~= "WBP_Pause_C" or gamePaused()) then
                return w
            end
        end
    end
end

local function label(tree, text, size, col)
    local tb = newObj("/Script/UMG.TextBlock", tree, "EasyLabel")
    if fontSrc then pcall(function() tb:SetFont(fontOf(fontSrc, size)) end) end
    tb:SetColorAndOpacity(col or color(0.85, 0.85, 0.85, 1))
    tb:SetText(FText(text))
    return tb
end

local function checkWithLabel(tree, text, size, col)
    local cb = newObj("/Script/UMG.CheckBox", tree, "EasyCheck")
    cb:SetContent(label(tree, "  " .. text, size, col))
    return cb
end

local function sized(tree, widget, h, wdt)
    local sb = newObj("/Script/UMG.SizeBox", tree, "EasySize")
    if h then sb:SetHeightOverride(h) end
    if wdt then sb:SetWidthOverride(wdt) end
    sb:SetContent(widget)
    return sb
end

local function gap(tree, h)
    local s = newObj("/Script/UMG.Spacer", tree, "EasyGap")
    s:SetSize({ X = 1, Y = h })
    return s
end

local function buildPage(menu)
    local gi = UEHelpers.GetGameInstance()
    if not valid(gi) then return end
    pcall(function() fontSrc = menu.Setting_ShowToolTips.TB_SettingName end)

    local w = newObj("/Script/UMG.UserWidget", gi, "EasyPage")
    local tree = newObj("/Script/UMG.WidgetTree", w, "EasyPageTree")
    w.WidgetTree = tree
    local canvas = newObj("/Script/UMG.CanvasPanel", tree, "EasyPageCanvas")
    tree.RootWidget = canvas
    canvas:SetVisibility(4)   -- clicks on empty space go through to the game's menu

    -- Launcher, bottom-right.
    local launchBg = newObj("/Script/UMG.Border", tree, "EasyLaunchBg")
    launchBg:SetBrushColor({ R = 0.08, G = 0.08, B = 0.08, A = 0.95 })
    launchBg:SetPadding({ Left = 14, Top = 8, Right = 18, Bottom = 8 })
    local launcher = checkWithLabel(tree, "HYKEEM'S EASY MODE", 22)
    launchBg:SetContent(launcher)
    local ls = canvas:AddChildToCanvas(launchBg)
    ls:SetAnchors({ Minimum = { X = 1, Y = 1 }, Maximum = { X = 1, Y = 1 } })
    ls:SetAlignment({ X = 1, Y = 1 })
    ls:SetAutoSize(true)
    ls:SetPosition({ X = -40, Y = -40 })

    -- The page, centred.
    local panel = newObj("/Script/UMG.Border", tree, "EasyPagePanel")
    panel:SetBrushColor({ R = 0.06, G = 0.06, B = 0.06, A = 0.97 })
    panel:SetPadding({ Left = 44, Top = 30, Right = 44, Bottom = 26 })
    local ps = canvas:AddChildToCanvas(panel)
    ps:SetAnchors({ Minimum = { X = 0.5, Y = 0.5 }, Maximum = { X = 0.5, Y = 0.5 } })
    ps:SetAlignment({ X = 0.5, Y = 0.5 })
    ps:SetAutoSize(true)
    ps:SetPosition({ X = 0, Y = -20 })

    local vb = newObj("/Script/UMG.VerticalBox", tree, "EasyPageVB")
    panel:SetContent(vb)

    -- Header: master switch + one line of progress.
    local master = checkWithLabel(tree, "EASY MODE  (" .. cfg.ToggleKey .. ")", 30, color(0.95, 0.95, 0.95, 1))
    vb:AddChild(master)
    local progress = label(tree, "", 17, color(0.55, 0.9, 0.55, 1))
    vb:AddChild(progress)

    local rows = { { row = { k = "Enabled" }, cb = master } }
    for _, r in ipairs(ROWS) do
        if r.section then
            vb:AddChild(gap(tree, 14))
            vb:AddChild(label(tree, r.section, 15, color(0.5, 0.5, 0.5, 1)))
        else
            local hb = newObj("/Script/UMG.HorizontalBox", tree, "EasyRow")
            local cb = checkWithLabel(tree, r.label, 19)
            hb:AddChild(sized(tree, cb, nil, 470))
            local entry = { row = r, cb = cb }
            table.insert(rows, entry)
            if r.slider then
                local s = newObj("/Script/UMG.Slider", tree, "EasySlider")
                s:SetMinValue(r.slider.min); s:SetMaxValue(r.slider.max); s:SetStepSize(r.slider.step)
                s:SetValue(cfg[r.slider.k])
                hb:AddChild(sized(tree, s, nil, 200))
                local val = label(tree, fmtValue(r.slider, cfg[r.slider.k]), 19, color(0.95, 0.95, 0.95, 1))
                hb:AddChild(sized(tree, gap(tree, 1), nil, 14))
                hb:AddChild(sized(tree, val, nil, 70))
                table.insert(rows, { row = r.slider, slider = s, val = val })
            end
            vb:AddChild(sized(tree, hb, 34))
        end
    end

    vb:AddChild(gap(tree, 18))
    local back = checkWithLabel(tree, "BACK", 24)
    vb:AddChild(back)

    w:AddToViewport(2000)
    page = { widget = w, launcher = launcher, back = back, panel = panel, rows = rows, progress = progress }
    log("easy mode page built")
end

local function syncRow(r)
    local row = r.row
    if r.cb then
        local shown = r.cb:IsChecked()
        if r.last == nil then r.cb:SetIsChecked(cfg[row.k]); r.last = cfg[row.k]
        elseif shown ~= r.last then cfg[row.k] = shown; r.last = shown; saveDue = true; log(row.k .. " = " .. tostring(shown))
        elseif cfg[row.k] ~= r.last then r.cb:SetIsChecked(cfg[row.k]); r.last = cfg[row.k] end   -- hotkey changed it
    else
        local v = r.slider:GetValue()
        v = row.min + math.floor((v - row.min) / row.step + 0.5) * row.step   -- snap clicks to the step
        if r.last == nil then r.slider:SetValue(cfg[row.k]); r.last = cfg[row.k]
        elseif math.abs(v - r.last) > 1e-4 then cfg[row.k] = v; r.last = v; r.slider:SetValue(v); saveDue = true
        elseif cfg[row.k] ~= r.last then r.slider:SetValue(cfg[row.k]); r.last = cfg[row.k] end
        r.val:SetText(FText(fmtValue(row, cfg[row.k])))
    end
end

local pageScan, menuOpen = 0, nil
local function settingsTick()
    if saveDue then saveDue = false; safe("save", save) end
    pageScan = pageScan - 1
    if pageScan <= 0 then pageScan = 5; menuOpen = openMenuWidget() end

    if menuOpen and not (page and valid(page.widget) and page.widget:IsInViewport()) then
        page = nil
        safe("build page", function() buildPage(menuOpen) end)
    end
    if not (page and valid(page.widget)) then return end

    if not menuOpen then
        page.widget:SetVisibility(1)              -- collapsed
        page.launcher:SetIsChecked(false)
    else
        page.widget:SetVisibility(4)
        if page.back:IsChecked() then page.back:SetIsChecked(false); page.launcher:SetIsChecked(false) end
        local open = page.launcher:IsChecked()
        page.panel:SetVisibility(open and 0 or 1)
        if open then
            for _, r in ipairs(page.rows) do safe("sync " .. r.row.k, function() syncRow(r) end) end
            if pageScan == 5 then page.progress:SetText(FText(progressText())) end
        end
    end
end

local BANNER_SECONDS = 6
local banner = nil        -- { widget, untilT }
local bannerShown = false
local freeTicks = 0

-- On a level change the game frees its old objects and may reuse their memory, so every cached
-- reference must be dropped (calling into a stale one crashes the game).
local lastWorld = nil
local function resetOnWorldChange()
    local w = UEHelpers.GetWorld()
    local id = valid(w) and w:GetAddress() or 0
    if id ~= lastWorld then
        lastWorld = id
        page, ui, menuOpen, pageScan, banner = nil, nil, nil, 0, nil
        threats, killSeqs, wasActive = {}, {}, {}
        duckState, blackoutUntil, alertUntil = nil, 0, 0
        log("world changed, caches cleared")
    end
    return id ~= 0
end

------------------------------------------------------------------------ "loaded" message once the player has control


local function showBanner()
    local gi, pc = UEHelpers.GetGameInstance(), UEHelpers.GetPlayerController()
    if not (valid(gi) and valid(pc)) then return end
    -- The first time the player can actually walk around as Simon (apartment or motel): playing as
    -- him, camera on him, movement not blocked by a cutscene. Must hold for ~1s.
    local pawn = pc.Pawn
    local vt = pc:GetViewTarget()
    local free = valid(pawn) and className(pawn):find("MainCharacter", 1, true)
        and valid(vt) and vt:GetAddress() == pawn:GetAddress()
        and not pc:IsMoveInputIgnored()
    freeTicks = free and freeTicks + 1 or 0
    if freeTicks < 20 then return end
    for _, cls in ipairs({ "WBP_Pause_C", "WBP_MainTitleSettingsWidget_C" }) do   -- borrow the game's font
        for _, m in ipairs(findAll(cls)) do
            pcall(function() if valid(m.Setting_ShowToolTips) then fontSrc = m.Setting_ShowToolTips.TB_SettingName end end)
        end
    end
    local w = newObj("/Script/UMG.UserWidget", gi, "EasyBanner")
    local tree = newObj("/Script/UMG.WidgetTree", w, "EasyBannerTree")
    w.WidgetTree = tree
    local canvas = newObj("/Script/UMG.CanvasPanel", tree, "EasyBannerCanvas")
    tree.RootWidget = canvas
    canvas:SetVisibility(3)   -- never blocks clicks
    local vb = newObj("/Script/UMG.VerticalBox", tree, "EasyBannerVB")
    vb:AddChild(label(tree, "Hykeem's Easy Mode Loaded", 28, color(0.45, 1, 0.45, 1)))
    vb:AddChild(label(tree, "Settings / Esc menu > HYKEEM'S EASY MODE (bottom-right)    " .. cfg.ToggleKey .. " on/off", 16, color(0.75, 0.75, 0.75, 1)))
    local slot = canvas:AddChildToCanvas(vb)
    slot:SetAnchors({ Minimum = { X = 1, Y = 0 }, Maximum = { X = 1, Y = 0 } })
    slot:SetAlignment({ X = 1, Y = 0 })
    slot:SetAutoSize(true)
    slot:SetPosition({ X = -40, Y = 36 })
    w:AddToViewport(3000)
    banner = { widget = w, untilT = now() + BANNER_SECONDS }
    bannerShown = true
    log("loaded banner shown")
end

local function bannerTick()
    if not bannerShown then safe("banner", showBanner); return end
    if not banner then return end
    if not valid(banner.widget) then banner = nil; return end
    local left = banner.untilT - now()
    if left <= 0 then
        banner.widget:RemoveFromParent(); banner = nil
    elseif left < 1 then
        banner.widget:SetRenderOpacity(left)   -- fade out over the last second
    end
end

------------------------------------------------------------------------ main tick

local slow = 0
local wasEnabled = cfg.Enabled
local function tick()
    if not resetOnWorldChange() then return end   -- loading
    bannerTick()
    safe("settings", settingsTick)

    -- every ~1.5s: re-apply tuning (also on the title screen, so new runs get the starting coin)
    slow = slow - 1
    local slowTick = slow <= 0
    if slowTick then slow = 30; applyTuning() end

    if wasEnabled and not cfg.Enabled then
        if duckState then setThreatVolume(1.0); duckState = nil end
        safe("timedilation", function() setTimeDilation(1.0) end)
    end
    wasEnabled = cfg.Enabled

    if not mainGameState() then return end  -- title screen / loading
    if not uiOk() then safe("build ui", buildUI); if not uiOk() then return end end
    ui.widget:SetVisibility(cfg.Enabled and 4 or 1) -- 4 = visible but never steals clicks, 1 = collapsed
    if not cfg.Enabled then return end

    if slowTick then
        safe("threats", refreshThreats)
        if cfg.NoJumpscares then safe("killseqs", refreshKillSeqs) end
        if hintsOn then safe("hints", function() ui.hints:SetText(FText(hintsText())) end) end
    end

    local pc = UEHelpers.GetPlayerController()
    if not valid(pc) or not valid(pc.PlayerCameraManager) then return end
    local cm = pc.PlayerCameraManager
    local l0, r0 = cm:GetCameraLocation(), cm:GetCameraRotation()
    local cam, yaw = { X = l0.X, Y = l0.Y, Z = l0.Z }, r0.Yaw

    local active = {}
    for _, a in ipairs(threats) do
        if valid(a) then
            local n = a:GetFullName()
            local on = isActive(a)
            local info = threatInfo(a)
            if on and not wasActive[n] then onSpawn(info) end
            wasActive[n] = on
            if on then
                local l = a:K2_GetActorLocation()
                local d = math.sqrt((l.X - cam.X) ^ 2 + (l.Y - cam.Y) ^ 2 + (l.Z - cam.Z) ^ 2) / 100
                table.insert(active, { info = info, loc = { X = l.X, Y = l.Y, Z = l.Z }, dist = math.floor(d), dir = direction(cam, yaw, l) })
            end
        end
    end
    table.sort(active, function(x, y) return x.dist < y.dist end)

    updateESP(pc, active)

    if alertUntil > now() then
        if #active > 0 then
            local t = active[1]
            ui.alert:SetText(FText("!! " .. t.info.name .. " - " .. t.dist .. "m " .. t.dir .. " !!\n" .. t.info.tip))
        end
    else
        ui.alert:SetText(FText(""))
    end
    if not (hintsOn and cfg.Hints) then ui.hints:SetText(FText("")) end

    if cfg.NoJumpscares then checkJumpscares(); endBlackoutIfDone() end
    if cfg.DuckThreatSounds and blackoutUntil == 0 then setThreatVolume(cfg.ThreatSoundVolume)
    elseif not cfg.DuckThreatSounds and duckState and blackoutUntil == 0 then setThreatVolume(1.0); duckState = nil end
end

LoopAsync(50, function()
    ExecuteInGameThread(function() safe("tick", tick) end)
    return false
end)

------------------------------------------------------------------------ keys

local function bind(name, fn)
    local k = Key[name]
    if k then RegisterKeyBind(k, function() ExecuteInGameThread(function() safe(name, fn) end) end)
    else log("unknown key " .. tostring(name)) end
end

bind(cfg.ToggleKey, function()
    cfg.Enabled = not cfg.Enabled
    log("Easy Mode " .. (cfg.Enabled and "ON" or "OFF"))
    applyTuning() -- restores originals when off
    saveDue = true
end)
bind(cfg.ESPKey, function() cfg.ESP = not cfg.ESP; saveDue = true end)
bind(cfg.HintsKey, function()
    hintsOn = cfg.Hints and not hintsOn
    if hintsOn and uiOk() then ui.hints:SetText(FText(hintsText())) end
end)

-- Insert key (only with DebugKeys = true): make killers release right away, for testing the mod.
if cfg.DebugKeys then
    bind("INS", function()
        for _, d in ipairs(findAll("GameDifficultySettingsDataAsset")) do
            for _, t in ipairs({ "Kidnapper", "Tucker", "Breather", "Tanner", "Noir", "Cletus" }) do
                d[t .. "_InstantRelease"] = true
            end
            d.Kidnapper_SpawnChance = 100; d.Kidnapper_SpawnWindow = { X = 1, Y = 2 }
            d.Tanner_SpawnChance = 100; d.Tanner_SpawnWindow = { X = 1, Y = 2 }
            d.Cletus_SpawnChance = 100; d.Cletus_SpawnWindow = { X = 1, Y = 2 }
        end
        log("DEBUG: forced killer release")
    end)
end

log("loaded (enabled=" .. tostring(cfg.Enabled) .. ", save file " .. SAVE_PATH .. ")")

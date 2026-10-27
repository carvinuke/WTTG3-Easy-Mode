-- Hykeem's WTTG3 Baby Mode - settings
-- These are the defaults. Easiest way to change them: open Settings (or press Esc in game) and
-- click "HYKEEM'S BABY MODE" bottom-right. Changes there are saved to settings.lua and override this file.
-- You can also edit this file, then restart the game. true = on, false = off.
-- Multipliers: 2.0 = double, 0.5 = half, 1.0 = unchanged.

return {
    -- Master switch. You can also toggle everything in game with the key below.
    Enabled = true,
    ToggleKey = "F6",

    ---------------------------------------------------------------- killers
    -- Big on-screen alert (with how-to-survive tip) when a killer shows up.
    SpawnAlerts = true,
    AlertSeconds = 8,

    -- Slow the game down for a moment when a killer shows up, so you can react.
    SlowMoOnSpawn = true,
    SlowMoSeconds = 2.0,
    SlowMoSpeed = 0.3,          -- 0.3 = 30% speed

    -- Name tags on killers, visible through walls, with distance.
    ESP = true,
    ESPKey = "F7",

    -- Skip kill jumpscares: screen cuts to black and you go straight to game over.
    NoJumpscares = true,

    -- Turn down killer voices/stingers (footsteps stay normal so you can still hear them coming).
    DuckThreatSounds = true,
    ThreatSoundVolume = 0.35,   -- 0.0 = silent, 1.0 = normal

    ---------------------------------------------------------------- money
    EasierEconomy = true,
    MoneyMultiplier = 2.0,      -- rewards and starting coin go up by this; prices, fees and losses go down by it

    ---------------------------------------------------------------- gambling
    BetterSlots = true,
    SlotsWinChance = 0.60,      -- 0.60 = 60% of spins win
    NoMaxLoss = true,           -- removes the "lose everything" outcome

    ---------------------------------------------------------------- hacking
    EasierHacking = true,
    HackTimeMultiplier = 2.0,   -- more time on every hacking minigame
    HackEnemyMultiplier = 0.5,  -- fewer/slower/weaker enemies in Shift Seq
    EasierHiding = true,        -- more forgiving Lucas breathing minigame

    ---------------------------------------------------------------- hints
    -- Panel listing which sites hold keys and how the key is hidden.
    Hints = true,
    HintsKey = "F8",
    ShowFullKeys = false,       -- true = also show the actual key text (basically cheating)

    -- Testing only: Insert key forces killers to show up.
    DebugKeys = false,
}

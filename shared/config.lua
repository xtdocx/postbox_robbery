-- All tunable values live here. Avoid editing logic files for balancing.

local Config = {}

-- ─── Targeting ────────────────────────────────────────────────────────────────
Config.PROP_MODEL          = `prop_postbox_01a`
Config.REQUIRED_WEAPON     = `weapon_crowbar`
Config.MAX_INTERACT_DIST   = 2.5

Config.TARGET = {
    name  = 'postbox_robbery:pry',
    label = 'Pry Open Postbox',
    icon  = 'fa-solid fa-screwdriver-wrench',
}

-- ─── Animation ────────────────────────────────────────────────────────────────
-- Pry anim: hard-capped + non-looping so the ped auto-returns to idle even if
-- the stop call is missed. Stuck anim: looping with no auto-stop so it plays
-- continuously until explicitly stopped (controlled by Config.STUCK.durationMs).
local ANIM_FLAG_UPPERBODY_NONLOOP = 16
local ANIM_FLAG_LOOP              = 1
local ANIM_MAX_DURATION_MS        = 5000
local ANIM_PLAY_FOREVER           = -1

Config.ANIMATION = {
    pry = {
        dict       = 'mini@repair',
        clip       = 'fixing_a_ped',
        flag       = ANIM_FLAG_UPPERBODY_NONLOOP,
        durationMs = ANIM_MAX_DURATION_MS,
    },
    stuck = {
        dict       = 'missfbi3_toothpull',
        clip       = 'pull_tooth_loop_weak_player',
        flag       = ANIM_FLAG_LOOP,
        durationMs = ANIM_PLAY_FOREVER,
    },
}

-- ─── Sound ────────────────────────────────────────────────────────────────────
Config.SOUND = {
    pry  = { name = 'Door_Open',         ref = 'GTAO_FM_Events_Soundset' },
    fail = { name = 'CHECKPOINT_MISSED', ref = 'HUD_MINI_GAME_SOUNDSET'  },
}

-- ─── Skill check (bl_ui) ─────────────────────────────────────────────────────
-- Uses bl_ui's `Progress` minigame (the slider minigame from the docs at
-- docs.byte-labs.net/bl_ui). Signature: bl_ui:Progress(iterations, difficulty)
-- where difficulty is 1-100 (lower = easier, larger target zone).
Config.SKILLCHECK = {
    iterations = 3,    -- rounds the player must clear
    difficulty = 85,   -- 1-100, higher = smaller target / faster slider
}

-- ─── Stuck punishment ─────────────────────────────────────────────────────────
-- Capped at 5s to match the global animation cap. Failing the skillcheck
-- always traps the hand (chance = 100); leave configurable for future tuning.
Config.STUCK = {
    chance     = 100,
    durationMs = ANIM_MAX_DURATION_MS,
}

-- ─── Police alert ─────────────────────────────────────────────────────────────
Config.POLICE_ALERT = {
    chanceOnFail = 35,
    blip = {
        sprite     = 304,
        color      = 1,
        scale      = 1.0,
        text       = 'Postbox Tampering',
        durationMs = 60000,
    },
}

-- ─── Rewards ──────────────────────────────────────────────────────────────────
-- A successful skillcheck ALWAYS pays cash within [min, max] AND drops every
-- item in `guaranteed`. Items in `bonus` are extra rolls on top.
-- Item names mirror entries in [ox]/ox_inventory/data/items.lua.
Config.REWARDS = {
    cash = { min = 25, max = 80 },
    guaranteed = {
        { name = 'loosenotes', min = 1, max = 1 },
    },
    bonus = {
        { name = 'lockpick',  min = 1, max = 1, chance = 5 },
        { name = 'gold_coin', min = 1, max = 1, chance = 1 },
    },
}

-- ─── Cooldowns ────────────────────────────────────────────────────────────────
-- Per-player cooldown only — every postbox in the world is always robbable.
Config.COOLDOWN = {
    perPlayerMs = 2 * 60 * 1000,
}

-- ─── Interruption checks ─────────────────────────────────────────────────────
Config.INTERRUPT = {
    checkIntervalMs = 500,
    maxMoveDistance = 2.0,
}

-- ─── Server-side validation ─────────────────────────────────────────────────
-- One-shot token system: the server issues a token on requestRobbery and
-- consumes it on reportSuccess/reportFailure. Prevents replay, decouples the
-- complete call from any client-supplied coords/state.
Config.TOKEN = {
    ttlMs        = 30 * 1000,  -- token lifetime (covers anim + skillcheck)
    minElapsedMs = 1500,       -- reject completes that come back faster than the skillcheck possibly could
}

-- Buffer added on top of MAX_INTERACT_DIST when the server checks the player's
-- actual ped position vs. the postbox coords. Accommodates network drift while
-- the player is locked in the pry animation.
Config.SERVER_DISTANCE_BUFFER = 2.0

return Config

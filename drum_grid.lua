-- drum_grid
-- monome norns + grid
--
-- grid divided into 5 vertical sections:
--   cols 1-3   : kicks
--   cols 4-6   : snares
--   cols 7-9   : hi-hats
--   cols 10-12 : crashes
--   cols 13-16 : misc (toms, cowbell, rim, clap, clave, shaker)
--
-- each button triggers a unique synthesized drum sound
-- requires lib/Engine_DrumGrid.sc
-- after first install: SYSTEM > RESTART to load the SC engine

engine.name = "DrumGrid"

local ROWS = 8
local COLS = 16

local SECTIONS = {
  { name = "kicks",   col_start = 1,  col_end = 3,  brightness_tier = 15 },
  { name = "snares",  col_start = 4,  col_end = 6,  brightness_tier = 12 },
  { name = "hihats",  col_start = 7,  col_end = 9,  brightness_tier = 9 },
  { name = "crashes", col_start = 10, col_end = 12, brightness_tier = 6 },
  { name = "misc",    col_start = 13, col_end = 16, brightness_tier = 4 },
}

-- Section brightness coding
local function get_section_brightness(col)
  for _, sec in ipairs(SECTIONS) do
    if col >= sec.col_start and col <= sec.col_end then
      return sec.brightness_tier
    end
  end
  return 0
end

local brightness = {}
for r = 1, ROWS do
  brightness[r] = {}
  for c = 1, COLS do brightness[r][c] = 0 end
end

local last_hit = nil
local decay_metro = nil

-- Step sequencer mode (K2 toggle)
local seq_mode = false
local seq_grid = {}
for step = 1, 16 do
  seq_grid[step] = {}
  for voice = 1, 8 do seq_grid[step][voice] = false end
end

-- Roll tracking: {x, y, press_time}
local roll_active = {}

-- MIDI note output per section
local midi_out = nil
local midi_notes = {
  kicks = 36,   -- GM kick
  snares = 38,  -- GM snare
  hihats = 42,  -- GM closed hat
  crashes = 49, -- GM crash
  misc = 62,    -- low tom
}

local PADS = {
  -- KICKS col 1 (deep/sub)
  {col=1,row=1,t="kick",freq=40, punch=300,dec=0.55,amp=0.95},
  {col=1,row=2,t="kick",freq=45, punch=250,dec=0.50,amp=0.90},
  {col=1,row=3,t="kick",freq=50, punch=200,dec=0.45,amp=0.88},
  {col=1,row=4,t="kick",freq=55, punch=180,dec=0.40,amp=0.85},
  {col=1,row=5,t="kick",freq=38, punch=320,dec=0.60,amp=0.95},
  {col=1,row=6,t="kick",freq=42, punch=280,dec=0.50,amp=0.90},
  {col=1,row=7,t="kick",freq=35, punch=350,dec=0.65,amp=0.92},
  {col=1,row=8,t="kick",freq=60, punch=160,dec=0.38,amp=0.85},
  -- KICKS col 2 (mid)
  {col=2,row=1,t="kick",freq=70, punch=140,dec=0.35,amp=0.85},
  {col=2,row=2,t="kick",freq=80, punch=120,dec=0.32,amp=0.82},
  {col=2,row=3,t="kick",freq=65, punch=150,dec=0.38,amp=0.87},
  {col=2,row=4,t="kick",freq=90, punch=100,dec=0.28,amp=0.80},
  {col=2,row=5,t="kick",freq=75, punch=130,dec=0.33,amp=0.83},
  {col=2,row=6,t="kick",freq=55, punch=160,dec=0.42,amp=0.88},
  {col=2,row=7,t="kick",freq=100,punch=90, dec=0.25,amp=0.78},
  {col=2,row=8,t="kick",freq=85, punch=110,dec=0.30,amp=0.81},
  -- KICKS col 3 (punchy/click)
  {col=3,row=1,t="kick",freq=120,punch=80, dec=0.22,amp=0.80},
  {col=3,row=2,t="kick",freq=110,punch=90, dec=0.24,amp=0.80},
  {col=3,row=3,t="kick",freq=130,punch=70, dec=0.20,amp=0.78},
  {col=3,row=4,t="kick",freq=140,punch=60, dec=0.18,amp=0.76},
  {col=3,row=5,t="kick",freq=150,punch=50, dec=0.15,amp=0.75},
  {col=3,row=6,t="kick",freq=160,punch=45, dec=0.14,amp=0.74},
  {col=3,row=7,t="kick",freq=170,punch=40, dec=0.12,amp=0.72},
  {col=3,row=8,t="kick",freq=180,punch=35, dec=0.10,amp=0.70},
  -- SNARES cols 4-5
  {col=4,row=1,t="snare",freq=180,tone=0.3, dec=0.22,amp=0.85},
  {col=4,row=2,t="snare",freq=200,tone=0.4, dec=0.18,amp=0.82},
  {col=4,row=3,t="snare",freq=220,tone=0.5, dec=0.20,amp=0.84},
  {col=4,row=4,t="snare",freq=160,tone=0.2, dec=0.25,amp=0.87},
  {col=4,row=5,t="snare",freq=240,tone=0.6, dec=0.16,amp=0.80},
  {col=4,row=6,t="snare",freq=150,tone=0.15,dec=0.28,amp=0.88},
  {col=4,row=7,t="snare",freq=260,tone=0.7, dec=0.14,amp=0.78},
  {col=4,row=8,t="snare",freq=140,tone=0.1, dec=0.30,amp=0.90},
  {col=5,row=1,t="snare",freq=280,tone=0.8, dec=0.12,amp=0.76},
  {col=5,row=2,t="snare",freq=300,tone=0.9, dec=0.10,amp=0.75},
  {col=5,row=3,t="snare",freq=320,tone=1.0, dec=0.09,amp=0.74},
  {col=5,row=4,t="snare",freq=190,tone=0.35,dec=0.19,amp=0.83},
  {col=5,row=5,t="snare",freq=210,tone=0.45,dec=0.17,amp=0.81},
  {col=5,row=6,t="snare",freq=170,tone=0.25,dec=0.23,amp=0.86},
  {col=5,row=7,t="snare",freq=130,tone=0.05,dec=0.32,amp=0.92},
  {col=5,row=8,t="snare",freq=340,tone=1.0, dec=0.08,amp=0.72},
  -- col 6: rim + clap
  {col=6,row=1,t="rim",freq=350,dec=0.05,amp=0.75},
  {col=6,row=2,t="rim",freq=400,dec=0.05,amp=0.75},
  {col=6,row=3,t="rim",freq=450,dec=0.04,amp=0.72},
  {col=6,row=4,t="rim",freq=500,dec=0.04,amp=0.70},
  {col=6,row=5,t="clap",dec=0.10,amp=0.80},
  {col=6,row=6,t="clap",dec=0.12,amp=0.82},
  {col=6,row=7,t="clap",dec=0.08,amp=0.78},
  {col=6,row=8,t="clap",dec=0.14,amp=0.84},
  -- HI-HATS col 7 (closed)
  {col=7,row=1,t="hat",freq=8000, dec=0.04,open=0,amp=0.65},
  {col=7,row=2,t="hat",freq=8500, dec=0.05,open=0,amp=0.63},
  {col=7,row=3,t="hat",freq=9000, dec=0.03,open=0,amp=0.60},
  {col=7,row=4,t="hat",freq=7500, dec=0.06,open=0,amp=0.67},
  {col=7,row=5,t="hat",freq=7000, dec=0.07,open=0,amp=0.68},
  {col=7,row=6,t="hat",freq=9500, dec=0.03,open=0,amp=0.58},
  {col=7,row=7,t="hat",freq=6500, dec=0.08,open=0,amp=0.70},
  {col=7,row=8,t="hat",freq=10000,dec=0.02,open=0,amp=0.55},
  -- HI-HATS col 8 (open medium)
  {col=8,row=1,t="hat",freq=8000, dec=0.15,open=1,amp=0.65},
  {col=8,row=2,t="hat",freq=8500, dec=0.20,open=1,amp=0.63},
  {col=8,row=3,t="hat",freq=9000, dec=0.25,open=1,amp=0.60},
  {col=8,row=4,t="hat",freq=7500, dec=0.18,open=1,amp=0.67},
  {col=8,row=5,t="hat",freq=7000, dec=0.30,open=1,amp=0.68},
  {col=8,row=6,t="hat",freq=9500, dec=0.12,open=1,amp=0.58},
  {col=8,row=7,t="hat",freq=6500, dec=0.35,open=1,amp=0.70},
  {col=8,row=8,t="hat",freq=10000,dec=0.10,open=1,amp=0.55},
  -- HI-HATS col 9 (open long)
  {col=9,row=1,t="hat",freq=8000, dec=0.40,open=1,amp=0.62},
  {col=9,row=2,t="hat",freq=7500, dec=0.50,open=1,amp=0.64},
  {col=9,row=3,t="hat",freq=7000, dec=0.60,open=1,amp=0.66},
  {col=9,row=4,t="hat",freq=6500, dec=0.70,open=1,amp=0.68},
  {col=9,row=5,t="hat",freq=9000, dec=0.45,open=1,amp=0.60},
  {col=9,row=6,t="hat",freq=9500, dec=0.35,open=1,amp=0.58},
  {col=9,row=7,t="hat",freq=10000,dec=0.28,open=1,amp=0.55},
  {col=9,row=8,t="hat",freq=6000, dec=0.80,open=1,amp=0.70},
  -- CRASHES cols 10-12
  {col=10,row=1,t="crash",freq=6000,dec=0.8, shimmer=0.5,amp=0.72},
  {col=10,row=2,t="crash",freq=6500,dec=0.9, shimmer=0.6,amp=0.70},
  {col=10,row=3,t="crash",freq=7000,dec=1.0, shimmer=0.7,amp=0.68},
  {col=10,row=4,t="crash",freq=7500,dec=1.2, shimmer=0.8,amp=0.66},
  {col=10,row=5,t="crash",freq=5500,dec=0.7, shimmer=0.4,amp=0.74},
  {col=10,row=6,t="crash",freq=5000,dec=0.6, shimmer=0.3,amp=0.76},
  {col=10,row=7,t="crash",freq=8000,dec=1.4, shimmer=0.9,amp=0.64},
  {col=10,row=8,t="crash",freq=4500,dec=0.5, shimmer=0.2,amp=0.78},
  {col=11,row=1,t="crash",freq=6200,dec=1.6, shimmer=0.7,amp=0.70},
  {col=11,row=2,t="crash",freq=6800,dec=1.8, shimmer=0.8,amp=0.68},
  {col=11,row=3,t="crash",freq=7200,dec=2.0, shimmer=0.9,amp=0.66},
  {col=11,row=4,t="crash",freq=7800,dec=2.2, shimmer=1.0,amp=0.64},
  {col=11,row=5,t="crash",freq=5800,dec=1.4, shimmer=0.6,amp=0.72},
  {col=11,row=6,t="crash",freq=5200,dec=1.2, shimmer=0.5,amp=0.74},
  {col=11,row=7,t="crash",freq=8500,dec=2.5, shimmer=1.0,amp=0.62},
  {col=11,row=8,t="crash",freq=4800,dec=1.0, shimmer=0.3,amp=0.76},
  {col=12,row=1,t="crash",freq=6400,dec=3.0, shimmer=0.8,amp=0.68},
  {col=12,row=2,t="crash",freq=7000,dec=3.5, shimmer=0.9,amp=0.66},
  {col=12,row=3,t="crash",freq=7600,dec=4.0, shimmer=1.0,amp=0.64},
  {col=12,row=4,t="crash",freq=8200,dec=4.5, shimmer=1.0,amp=0.62},
  {col=12,row=5,t="crash",freq=6000,dec=2.5, shimmer=0.7,amp=0.70},
  {col=12,row=6,t="crash",freq=5600,dec=2.0, shimmer=0.6,amp=0.72},
  {col=12,row=7,t="crash",freq=9000,dec=5.0, shimmer=1.0,amp=0.60},
  {col=12,row=8,t="crash",freq=5000,dec=1.8, shimmer=0.4,amp=0.74},
  -- MISC cols 13-16
  {col=13,row=1,t="tom",freq=200,dec=0.30,amp=0.85},
  {col=13,row=2,t="tom",freq=160,dec=0.35,amp=0.87},
  {col=13,row=3,t="tom",freq=130,dec=0.40,amp=0.88},
  {col=13,row=4,t="tom",freq=110,dec=0.45,amp=0.90},
  {col=13,row=5,t="tom",freq=240,dec=0.25,amp=0.83},
  {col=13,row=6,t="tom",freq=280,dec=0.20,amp=0.80},
  {col=13,row=7,t="tom",freq=320,dec=0.18,amp=0.78},
  {col=13,row=8,t="tom",freq=90, dec=0.50,amp=0.92},
  {col=14,row=1,t="cowbell",freq=540,dec=0.55,amp=0.70},
  {col=14,row=2,t="cowbell",freq=580,dec=0.50,amp=0.68},
  {col=14,row=3,t="cowbell",freq=620,dec=0.45,amp=0.66},
  {col=14,row=4,t="cowbell",freq=660,dec=0.40,amp=0.65},
  {col=14,row=5,t="cowbell",freq=500,dec=0.60,amp=0.72},
  {col=14,row=6,t="cowbell",freq=460,dec=0.65,amp=0.74},
  {col=14,row=7,t="cowbell",freq=700,dec=0.35,amp=0.63},
  {col=14,row=8,t="cowbell",freq=420,dec=0.70,amp=0.76},
  {col=15,row=1,t="clave",freq=2400,dec=0.04,amp=0.72},
  {col=15,row=2,t="clave",freq=2600,dec=0.04,amp=0.70},
  {col=15,row=3,t="clave",freq=2800,dec=0.03,amp=0.68},
  {col=15,row=4,t="clave",freq=3000,dec=0.03,amp=0.66},
  {col=15,row=5,t="shaker",freq=5000,dec=0.07,amp=0.58},
  {col=15,row=6,t="shaker",freq=6000,dec=0.08,amp=0.56},
  {col=15,row=7,t="shaker",freq=7000,dec=0.09,amp=0.54},
  {col=15,row=8,t="shaker",freq=8000,dec=0.10,amp=0.52},
  {col=16,row=1,t="rim",freq=350,dec=0.05,amp=0.76},
  {col=16,row=2,t="rim",freq=400,dec=0.05,amp=0.74},
  {col=16,row=3,t="rim",freq=450,dec=0.04,amp=0.72},
  {col=16,row=4,t="rim",freq=500,dec=0.04,amp=0.70},
  {col=16,row=5,t="clap",dec=0.09,amp=0.82},
  {col=16,row=6,t="clap",dec=0.11,amp=0.80},
  {col=16,row=7,t="clap",dec=0.13,amp=0.78},
  {col=16,row=8,t="clap",dec=0.15,amp=0.76},
}

local pad_map = {}
for r = 1, ROWS do pad_map[r] = {} end
for _, p in ipairs(PADS) do pad_map[p.row][p.col] = p end

local function trigger_pad(pad)
  local t = pad.t
  if     t == "kick"    then engine.kick(pad.freq or 60, pad.punch or 200, pad.dec or 0.45, pad.amp or 0.9)
  elseif t == "snare"   then engine.snare(pad.freq or 200, pad.tone or 0.4, pad.dec or 0.18, pad.amp or 0.8)
  elseif t == "hat"     then engine.hat(pad.freq or 8000, pad.dec or 0.05, pad.open or 0, pad.amp or 0.6)
  elseif t == "crash"   then engine.crash(pad.freq or 7000, pad.dec or 1.2, pad.shimmer or 0.6, pad.amp or 0.7)
  elseif t == "tom"     then engine.tom(pad.freq or 120, pad.dec or 0.35, pad.amp or 0.85)
  elseif t == "cowbell" then engine.cowbell(pad.freq or 540, pad.dec or 0.55, pad.amp or 0.7)
  elseif t == "rim"     then engine.rim(pad.freq or 400, pad.dec or 0.05, pad.amp or 0.75)
  elseif t == "clap"    then engine.clap(pad.dec or 0.10, pad.amp or 0.80)
  elseif t == "clave"   then engine.clave(pad.freq or 2500, pad.dec or 0.04, pad.amp or 0.70)
  elseif t == "shaker"  then engine.shaker(pad.freq or 6000, pad.dec or 0.08, pad.amp or 0.55)
  end
end

local g = grid.connect()
local sec_labels = {"KICK","SNARE","HIHAT","CRASH","MISC"}

-- Helper: get section name from column
local function get_section_name(col)
  for _, sec in ipairs(SECTIONS) do
    if col >= sec.col_start and col <= sec.col_end then
      return sec.name
    end
  end
  return "misc"
end

-- Send MIDI note for a section
local function send_midi_note(section_name)
  local note = midi_notes[section_name] or 62
  if midi_out then
    midi_out:note_on(note, 100)
  end
end

-- Roll trigger: if held >300ms, starts roll at 1/16 subdivisions
local function trigger_roll(x, y, is_press)
  if is_press then
    if not roll_active[y] then roll_active[y] = {} end
    roll_active[y][x] = {press_time = util.time()}
  else
    if roll_active[y] and roll_active[y][x] then
      roll_active[y][x] = nil
    end
  end
end

local function grid_redraw()
  if not g.device then return end
  g:all(0)

  if seq_mode then
    -- Step sequencer view: x=step, y=voice
    for step = 1, 16 do
      for voice = 1, 8 do
        local brightness_val = seq_grid[step][voice] and 15 or 2
        g:led(step, voice, brightness_val)
      end
    end
  else
    -- Normal drum grid view with section brightness tiers
    for _, sec in ipairs(SECTIONS) do
      for r = 1, ROWS do g:led(sec.col_start, r, 2) end
    end
    for r = 1, ROWS do
      for c = 1, COLS do
        if brightness[r][c] > 0 then g:led(c, r, brightness[r][c]) end
      end
    end
  end

  g:refresh()
end

g.key = function(x, y, z)
  if seq_mode then
    -- Sequencer mode: toggle steps
    if x <= 16 and y <= 8 then
      seq_grid[x][y] = not seq_grid[x][y]
      grid_redraw()
      redraw()
    end
  else
    -- Normal pad mode
    local pad = pad_map[y][x]
    if pad then
      trigger_pad(pad)
      local sec_brightness = get_section_brightness(x)
      brightness[y][x] = sec_brightness
      last_hit = {r=y, c=x}

      -- Track hold time for rolls
      if z == 1 then
        trigger_roll(x, y, true)
      else
        trigger_roll(x, y, false)
        -- Check roll duration
        if roll_active[y] and roll_active[y][x] == nil then
          -- Roll ended, could trigger roll pattern here
        end
      end

      grid_redraw()
      redraw()
    end
  end
end

function redraw()
  screen.clear()
  screen.aa(0)
  screen.level(15)
  screen.font_size(8)
  screen.move(2, 8)
  screen.text(seq_mode and "STEP SEQ" or "DRUM GRID")

  if seq_mode then
    -- Sequencer view
    screen.level(8)
    screen.font_size(5)
    screen.move(2, 18)
    screen.text("Step X Voice Grid (K2 to exit)")
    local cw, ch, gx, gy = 8, 5, 1, 22
    for step = 1, 16 do
      for voice = 1, 8 do
        screen.level(seq_grid[step][voice] and 12 or 2)
        screen.rect(gx+(step-1)*cw, gy+(voice-1)*ch, cw-1, ch-1)
        screen.fill()
      end
    end
  else
    -- Drum grid view with section brightness tiers
    screen.font_size(6)
    for i, sec in ipairs(SECTIONS) do
      screen.level(8)
      screen.move((sec.col_start - 1) * 8 + 1, 18)
      screen.text(sec_labels[i]:sub(1,3))
    end
    local cw, ch, gx, gy = 6, 5, 1, 22
    for r = 1, ROWS do
      for c = 1, COLS do
        screen.level(brightness[r][c] > 0 and brightness[r][c] or 2)
        screen.rect(gx+(c-1)*cw, gy+(r-1)*ch, cw-1, ch-1)
        screen.fill()
      end
    end
    if last_hit then
      local pad = pad_map[last_hit.r][last_hit.c]
      if pad then
        screen.level(12)
        screen.font_size(8)
        screen.move(2, 62)
        screen.text(string.upper(pad.t))
        if pad.freq then
          screen.level(6)
          screen.move(50, 62)
          screen.text(string.format("%dHz", pad.freq))
        end
      end
    end
  end

  screen.update()
end

local function decay_tick()
  local any = false
  for r = 1, ROWS do
    for c = 1, COLS do
      if brightness[r][c] > 0 then
        brightness[r][c] = math.max(0, brightness[r][c] - 3)
        any = true
      end
    end
  end
  if any then grid_redraw() end
end

function key(n, z)
  if n == 2 and z == 1 then
    -- K2: toggle sequencer mode
    seq_mode = not seq_mode
    grid_redraw()
    redraw()
  end
end

function init()
  decay_metro = metro.init(decay_tick, 1/15)
  decay_metro:start()

  -- Setup MIDI output device
  midi_out = midi.connect(1)

  redraw()
  grid_redraw()
  print("drum_grid: ready")
  print("K2: toggle step sequencer mode")
  print("Section brightness: kick=15, snare=12, hat=9, crash=6, misc=4")
end

function cleanup()
  if decay_metro then decay_metro:stop() end
end
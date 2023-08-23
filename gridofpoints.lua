-- grid of points
-- v1.8 @duncangeere
--
-- sixteen notes, eight timbres
-- with apologies to Liz Harris
--
-- > k2: up a fifth
-- > k3: down a fifth
--
-- > e2: change root note
-- > e3: change scale
--
-- Required:
-- Grid
--
-- > left/right axis = pitch,
-- > up/down axis = filter cutoff
-- > up/down axis = MIDI CC
--
-- Optional:
-- Crow
--
-- > out1: v/oct
-- > out2: gate
-- > out3: -5V-5V on y-axis
-- > out4: 0-10V on y-axis
--
engine.name = "GridofPoints" -- Pick synth engine

-- Init grid
g = grid.connect()

-- Init midi
if midi.devices ~= nil then my_midi = midi.connect() end

-- Init function
function init()
    -- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
    musicutil = require("musicutil")

    -- Custom cutoff frequencies and midi note lengths table
    cutoffs = { 361, 397, 584, 1086, 2110, 3892, 6697, 10817 }

    memory = {}

    screen_dirty = true
    grid_dirty = true
    grid_connected = false

    topleft = false;
    topright = false;
    bottomleft = false;
    bottomright = false;
    magic = false;

    -- Default row and column numbers
    cols = 16
    rows = 8

    addparams()
    build_scale()

    -- Start a clock to refresh the screen
    redraw_clock_id = clock.run(redraw_clock)
    forget_clock_id = clock.run(forget)
end

-- Visuals
function redraw()
    if grid_connected then
        -- clear the screen
        screen.clear()

        -- text
        screen.aa(1)

        -- root note
        screen.font_size(65)
        screen.font_face(19)
        screen.level(2)

        screen.move(2, 56)
        screen.text(musicutil.note_num_to_name(params:get("root_note"), true))

        -- scale
        screen.font_size(10)
        screen.font_face(4)
        screen.level(15)

        screen.move(124, 60)
        screen.text_right(scale_names[params:get("scale")])

        -- trigger a screen update
        screen.update()
    else
        -- Warn that grid is not connected
        screen.clear()
        screen.aa(1)
        screen.font_size(10)
        screen.font_face(4)
        screen.move(64, 28)
        screen.text_center("No grid detected.")
        screen.move(64, 38)
        screen.text_center("Please connect a grid.")
        screen.update()
    end
end

-- Grid functions
function g.key(x, y, z)
    -- When you press it...
    if z == 1 then -- if we press any grid key
        if (x == 1 and y == 1) then
            topleft = true;
            -- print("top left!")
        end

        if (x == 1 and y == rows) then
            bottomleft = true;
            -- print("bottom left!")
        end

        if (x == cols and y == 1) then
            topright = true;
            -- print("top right!")
        end

        if (x == cols and y == rows) then
            bottomright = true;
            -- print("bottom right!")
        end

        if (topleft and bottomleft and topright and bottomright) then
            if not magic then
                print("the magic begins...")
                magic = true;
                incantation();
            else
                print("the magic fades...")
                magic = false;
                clock.cancel(spell)
            end
        end

        -- remember the key pressed
        remember(x, y)
        grid_dirty = true
        playnote(x, y)
    end

    -- When you depress it...
    if z == 0 then
        -- End gate crow
        crow.output[2].volts = 0

        -- Turn off the magic trackers
        topleft = false;
        topright = false;
        bottomleft = false;
        bottomright = false;
    end
end

-- Key functions
function key(n, z)
    -- KEY2 down one octave
    if n == 2 and z == 1 then
        params:set("root_note", params:get("root_note") - 7)
        build_scale()
    end

    -- KEY3 up one octave
    if n == 3 and z == 1 then
        params:set("root_note", params:get("root_note") + 7)
        build_scale()
    end

    screen_dirty = true
end

-- Encoder functions
function enc(n, d)
    -- ENC 2 select root note
    if n == 2 then params:set("root_note", params:get("root_note") + d) end

    -- ENC 3 select scale
    if n == 3 then
        params:set("scale", util.clamp(params:get("scale") + d, 1, #scale_names))
    end

    screen_dirty = true
end

function playnote(x, y)
    -- Play a note
    params:set("crossfade", (util.linexp(1, rows, 1, 0.001, y)))

    engine.hz(notes_freq[x])

    -- Output gate crow
    crow.output[1].volts = (notes_nums[x] - 48) / 12
    crow.output[3].volts = util.linlin(1, rows, 5, -5, y)
    crow.output[4].volts = util.linlin(1, rows, 10, 0, y)
    crow.output[2].volts = 0
    crow.output[2].volts = 5

    -- MIDI
    if midi.devices ~= nil then
        -- send MIDI CC
        my_midi:cc(
            params:get("midi_cc"),
            math.floor(util.linlin(rows, 1, 0, 127, y)),
            params:get("midi_channel")
        )
        -- send MIDI note
        play_midi_note(notes_nums[x] - 12, params:get("midi_notelength"))
    end
end

-- All the parameters
function addparams()
    -- Engine
    params:add_separator("Engine")

    ---- Engine parameters
    params:add {
        type = "control",
        id = "pulsewidth", name = "pulse width",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0.01, 0.99, 'lin', 0.01, 0.5, "", 0.01 / (0.99 - 0.01), false),
        action = function(x) engine.pw(x) end
    }

    params:add {
        type = "control",
        id = "cutoff", name = "filter cutoff",
        --controlspec = controlspec.FREQ,
        controlspec = controlspec.new(20, 20000, 'exp', 0, 2000, "Hz"),
        action = function(x) engine.cutoff(x) end
    }

    params:add {
        type = "control",
        id = "db", name = "db",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        --controlspec = controlspec.new(-96, 32, 'lin', 0.1, -6, "", 0.1/(32+96), false),
        controlspec = controlspec.new(-96, 32, 'lin', 1, -6, 'db', 1 / (32 + 96), false),
        action = function(x) engine.db(x) end
    }

    params:add {
        type = "control",
        id = "gain", name = "filter res gain",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0, 4, 'lin', 0.1, 2, "", 0.1 / (4 - 0), false),
        action = function(x) engine.gain(x) end
    }

    params:add {
        type = "control",
        id = "release", name = "release",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0.1, 10, 'exp', 0.05, 0.5, "s", 0.01 / (10 - 0.1), false),
        action = function(x) engine.release(x) end
    }

    params:add {
        type = "control",
        id = "pan", name = "pan",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(-1, 1, 'lin', 0.01, 0, "", 0.01, false),
        action = function(x) engine.pan(x) end
    }

    params:add {
        type = "control",
        id = "crossfade", name = "osc crossfade",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5, "", 0.01, false),
        action = function(x) engine.crossfade(x) end
    }

    -- Quantiser
    params:add_separator("Quantiser")

    ---- Root Note
    params:add {
        type = "number",
        id = "root_note",
        name = "root note",
        min = 0,
        max = 127,
        default = math.random(50, 60),
        formatter = function(param)
            return musicutil.note_num_to_name(param:get(), true)
        end,
        action = function() build_scale() end
    }

    ---- Scale
    scale_names = {}
    for i = 1, #musicutil.SCALES do
        table.insert(scale_names, musicutil.SCALES[i].name)
    end

    params:add {
        type = "option",
        id = "scale",
        name = "scale",
        options = scale_names,
        default = math.random(#scale_names),
        action = function() build_scale() end -- update the scale when it's changed
    }

    -- MIDI
    params:add_separator("MIDI")

    ---- MIDI channel number
    params:add {
        type = "number",
        id = "midi_channel",
        name = "MIDI channel number",
        min = 1,
        max = 16,
        default = 1
    }

    ---- MIDI CC number
    params:add {
        type = "number",
        id = "midi_cc",
        name = "MIDI cc number",
        min = 0,
        max = 127,
        default = 1
    }

    ---- MIDI note length
    params:add {
        type = "control",
        id = "midi_notelength",
        name = "MIDI note length (s)",
        controlspec = controlspec.new(0.01, 10, 'exp', 0.01, 0.1, "secs", 0.01, false)
    }

    -- Run all actions
    params:bang()
end

-- Build the scale
function build_scale()
    notes_nums = musicutil.generate_scale_of_length(params:get("root_note"),
        params:get("scale"), cols)                        -- builds scale
    notes_freq = musicutil.note_nums_to_freqs(notes_nums) -- converts note numbers to an array of frequencies

    screen_dirty = true
end

-- Check if the screen needs redrawing 15 times a second
function redraw_clock()
    while true do
        clock.sleep(1 / 15)

        -- Check if grid is connected
        if not grid_connected then
            if g.device == nil then
                grid_connected = false
            else
                print("grid connected!")
                grid_connected = true
                screen_dirty = true
                rows = g.rows -- thanks demure!
                cols = g.cols
                build_scale()
            end
        else
            if g.device == nil then
                print("grid disconnected!")
                grid_connected = false
                screen_dirty = true
            end
        end

        -- Norns screen
        if screen_dirty then
            redraw()
            screen_dirty = false
        end

        -- Grid display
        if grid_dirty then
            -- Light the LEDs in the memory
            g:all(0)
            for i = 1, #memory do
                g:led(memory[i].x, memory[i].y, memory[i].level)
            end

            -- Refresh the grid
            g:refresh()
        end
    end
end

-- function to remember
function remember(xcoord, ycoord)
    table.insert(memory, { x = xcoord, y = ycoord, level = 15 })
end

-- function to forget
function forget()
    while true do
        clock.sleep(1 / 3)
        for i = 1, #memory do memory[i]["level"] = memory[i]["level"] - 1 end
        filter_inplace(memory, function(elem) return elem["level"] >= 1 end)
        grid_dirty = true
    end
end

function incantation()
    spell = clock.run(function()
        while true do
            clock.sleep(math.random(8))
            rndx = math.random(cols)
            rndy = math.random(rows)
            playnote(rndx, rndy)
            remember(rndx, rndy)
            grid_dirty = true
            -- End gate crow
            crow.output[2].volts = 0
        end
    end)
end

-- filter a table in place based on a function
function filter_inplace(arr, func)
    local new_index = 1
    local size_orig = #arr
    for old_index, v in ipairs(arr) do
        if func(v, old_index) then
            arr[new_index] = v
            new_index = new_index + 1
        end
    end
    for i = new_index, size_orig do arr[i] = nil end
end

-- MIDI support
function play_midi_note(midi_note, midi_notelength)
    if midi.devices ~= nil then
        stopping = clock.run(function()
            my_midi:note_on(midi_note, 100, params:get("midi_channel"))
            clock.sleep(params:get("midi_notelength"))
            my_midi:note_off(midi_note, 100, params:get("midi_channel"))
        end)
    end
end

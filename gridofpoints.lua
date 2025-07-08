-- grid of points
-- v2.1 @duncangeere
--
-- sixteen notes, seven timbres
-- with apologies to Liz Harris
--
-- > k2: up a fifth
-- > k3: down a fifth
-- > k1+k3: toggle magic mode
--
-- > e1: change root octave
-- > e2: change root note
-- > e3: change scale
--
-- Recommended:
-- grid
--
-- > left/right axis = pitch,
-- > up/down axis = timbre
-- > up/down axis = MIDI CC
-- > up/down axis = crow volts
-- > top row = root/scale presets
-- > long press to save
-- > short press to load
--
-- Optional:
-- crow
--
-- > out1: v/oct
-- > out2: gate
-- > out3: -5V-5V on y-axis
-- > out4: 0-10V on y-axis
-- 
-- > Optional: JF, MIDI
--

-- Import json library: https://github.com/rxi/json.lua
local json = include("lib/json")

-- Pick synth engine
engine.name = "GridofPoints"

-- Init grid
g = grid.connect()

-- Init midi
if midi.devices ~= nil then my_midi = midi.connect() end

-- Init jf
local function use_jf()
    return params:get("use_jf") == 1
  end

-- Init function
function init()
    -- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
    musicutil = require("musicutil")

    memory = {};
    keys = {};
    preset_clocks = {};
    grid_highlights = {};
    current_preset = 0;

    screen_dirty = true;
    grid_dirty = true;
    grid_connected = false;

    topleft = false;
    topright = false;
    bottomleft = false;
    bottomright = false;
    mults = {{ "0.25x", "0.5x", "1x", "2x", "4x" },{ 0.25, 0.5, 1, 2, 4 }};
    magicopts = {"false", "true"}
    k1down = false;

    -- Default row and column numbers
    if g.device == nil then
        cols = 16
        rows = 8
    else
        rows = g.rows -- thanks demure!
        cols = g.cols
    end

    -- Init keys
    -- Create the keys file if it doesn't exist
    if not util.file_exists(_path.data .. "gridofpoints/keys.json") then
        -- Fill up the keys table with default values
        table.insert(keys, { 48, 12 })
        for i = 2, cols do
            table.insert(keys, { 0, 0 })
        end

        -- Save the keys to the data folder
        local file = io.open(_path.data .. "gridofpoints/keys.json", "w")
        if file then
            file:write(json.encode(keys))
            file:close()
            print("Keys saved to data folder.")
        else
            print("Error saving keys to data folder.")
        end
    else
        -- Load the keys from the data folder
        local file = io.open(_path.data .. "gridofpoints/keys.json", "r")
        if file then
            local content = file:read("*a")
            keys = json.decode(content)
            file:close()
            print("Keys loaded from data folder.")
            
            -- Print the keys to the console
            for index, data in ipairs(keys) do
                print(index .. ": Root Note: " .. data[1] .. ", Scale: " .. data[2])
            end
        else
            print("Error loading keys from data folder.")
        end
    end

    -- Add engine parameters
    addparams()

    -- Build the notes scale
    build_scale()

    -- Start a clock to refresh the screen
    redraw_clock_id = clock.run(redraw_clock)
    forget_clock_id = clock.run(forget)
end

-- Visuals
function redraw()
    
    -- clear the screen
    screen.clear()

    -- text
    screen.aa(1)

    -- root note
    screen.font_size(50)
    screen.font_face(19)
    screen.level(4)

    screen.move(2, 45)
    screen.text(musicutil.note_num_to_name(params:get("root_note"), true))

    -- scale
    screen.font_size(8)
    screen.font_face(1)
    screen.level(15)

    screen.move(2, 60)
    screen.text(scale_names[params:get("scale")])

    if params:get("magic") == 2 then
        -- Magic mode
        screen.font_size(8)
        screen.font_face(1)
        screen.level(15)

        screen.move(124, 60)
        screen.text_right("◢")
    end

    if grid_connected then
        -- Warn that grid is not connected
        screen.font_size(8)
        screen.font_face(1)
        screen.level(15)

        screen.move(124, 10)
        screen.text_right("▦")

        -- Show grid presses
        
        
    end
    -- trigger a screen update
    screen.update()
end

-- Grid functions
function g.key(x, y, z)
    
    if z == 1 then -- if we press any grid key

        -- If the press is on the first row of the grid
        if (y == 1) then
            -- Start a clock to track long presses
            preset_clocks[x] = clock.run(function()
                -- Wait for two seconds
                clock.sleep(2);

                -- If the key is still pressed after two seconds
                -- Then save the preset in that slot
                keys[x][1] = params:get("root_note");
                keys[x][2] = params:get("scale");

                -- And save the keys to the data folder
                local file = io.open(_path.data .. "gridofpoints/keys.json", "w")
                if file then
                    file:write(json.encode(keys))
                    file:close()
                    print("Keys saved to data folder.")
                else
                    print("Error saving keys to data folder.")
                end
                    end)
                else

            -- remember the key pressed
            remember(x, y)

            -- play the note
            playnote(x, y)
        end

        -- Update the grid
        grid_dirty = true
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

        -- If the press is on the first row of the grid
        if (y == 1) then
            -- Cancel the longpress tracking clock
            clock.cancel(preset_clocks[x]);
            -- Check if there's a key in that slot
            if (keys[x][1] > 0 and keys[x][2] > 0) then
                -- Set the root note and scale from that preset
                params:set("root_note", keys[x][1])
                params:set("scale", keys[x][2])
                current_preset = x;
            end
        end
    end
end

-- Key functions
function key(n, z)
    -- KEY2 down one fifth
    if n == 2 and z == 1 then
        params:set("root_note", params:get("root_note") - 7)
        build_scale()
    end

    -- KEY3
    if n == 3 and z == 1 then
        -- Check if key 1 is down
        if k1down then
            -- if magic mode is on
            if params:get("magic") == 2 then
                -- turn it off
                params:set("magic", 1)
            else
                -- turn it on
                params:set("magic", 2)
            end
        else 
            -- if k1 is not down
            -- go up a fifth
            params:set("root_note", params:get("root_note") + 7)
            build_scale()
        end
    end

    -- KEY1 toggle
    if n == 1 and z == 1 then
        k1down = true
    end

    if n == 1 and z == 0 then
        k1down = false
    end

    

    screen_dirty = true
end

-- Encoder functions
function enc(n, d)
    -- ENC 1 select octave
    if n == 1 then params:set("root_note", params:get("root_note") + d * 12) end

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
    if params:get("yaxis") == 1 then
        params:set("crossfade", (util.linexp(2, rows, 1, 0.001, y)))
    elseif params:get("yaxis") == 2 then
        params:set("release", (util.linexp(2, rows, 3, 0.3, y)))
    elseif params:get("yaxis") == 3 then
        params:set("cutoff", (util.linexp(2, rows, 20000, 200, y)))
    end
    
    -- Figure out pan position
    panning = params:get("pan") + (params:get("pandom") * (2 * math.random() - 1))

    if panning < -1 then
        panning = -1
    elseif panning > 1 then
        panning = 1
    end

    -- Play the note
    engine.pan(panning)
    engine.hz(notes_freq[x])

    -- Output gate crow
    crow.output[1].volts = ((notes_nums[x] - 48) / 12)-1
    crow.output[3].volts = util.linlin(2, rows, 5, -5, y)
    crow.output[4].volts = util.linlin(2, rows, 10, 0, y)
    crow.output[2].volts = 0
    crow.output[2].volts = 5

    -- MIDI
    if midi.devices ~= nil then
        -- send MIDI CC
        my_midi:cc(
            params:get("midi_cc"),
            math.floor(util.linlin(rows, 2, 0, 127, y)),
            params:get("midi_channel")
        )
        -- send MIDI note
        play_midi_note(notes_nums[x] - 12, params:get("midi_notelength"))
    end

    -- JF
    if use_jf() then
        crow.ii.jf.play_note(((notes_nums[x] - 48) / 12)-1, util.linlin(2, rows, 5, 1, y))
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
        controlspec = controlspec.new(20, 20000, 'exp', 0, 2000, "Hz"),
        action = function(x) engine.cutoff(x) end
    }

    params:add {
        type = "control",
        id = "db", name = "db",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
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
        type= "control",
        id = "pandom", name = "random pan maximum",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0, 1, 'lin', 0.01, 0, "", 0.01, false),
    }

    params:add {
        type = "control",
        id = "crossfade", name = "osc crossfade",
        -- controlspec.new(min, max, warp, step, default, units, quantum, wrap)
        controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.5, "", 0.01, false),
        action = function(x) engine.crossfade(x) end
    }

    params:add {
        type = "option",
        id = "yaxis",
        name = "y-axis controls",
        options = {"crossfade", "release", "filter"},
        default = 1
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
        default = math.random(40, 50),
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

    -- Magic Mode
    params:add_separator("Magic Mode")
      
    params:add {
        type = "option",
        id = "magic",
        name = "Magic mode on?",
        options = magicopts,
        default = 1
    }
      
    params:set_action("magic", function(value)
        if value == 2 then
            print("the magic begins...")
            incantation()
        else 
          if spell then
            print("the magic fades...")
            clock.cancel(spell)
          end
        end
        screen_dirty = true
    end)
    
    ---- Jitter
    params:add_number(
        "jitter", -- id
        "Jitter", -- name
        0, -- min
        100, -- max
        0, -- default
        function(param) return param:get().."%" end, -- formatter
        false -- wrap
    )

    ---- Probability
    params:add_number(
        "probability", -- id
        "Probability", -- name
        0, -- min
        100, -- max
        60, -- default
        function(param) return param:get().."%" end, -- formatter
        false -- wrap
    )

    ---- Clock multiplication
    params:add {
        type = "option",
        id = "magicmult",
        name = "Clock multiplier",
        options = mults[1],
        default = 3
    }

    ---- Legacy magic
    params:add {
        type = "option",
        id = "magic_legacy",
        name = "Legacy magic mode?",
        options = { "Yes", "No" },
        default = 2
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

    --- just friends
    params:add_separator("Just Friends")
    params:add_option("use_jf", "use Just Friends", { "Yes", "No" }, 1)
    params:set_action("use_jf", function(value)
        if value == 1 then
            crow.ii.pullup(true)
            crow.ii.jf.mode(1)
        end
    end)

    -- Run all actions
    params:bang()
end

-- Build the scale
function build_scale()
    notes_nums = musicutil.generate_scale_of_length(params:get("root_note"),
        params:get("scale"), cols)                        -- builds scale
    notes_freq = musicutil.note_nums_to_freqs(notes_nums) -- converts note numbers to an array of frequencies

    -- Highlight the root notes
    for i = 1, #notes_nums do
        grid_highlights[i] = musicutil.note_num_to_name(notes_nums[i]) == musicutil.note_num_to_name(notes_nums[1]) and true or false
    end
    
    grid_dirty = true
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

            -- Clear the grid
            g:all(0)

            --- Light the root notes
            for i = 1, cols do
                for j = 1, rows do
                    g:led(i, j, grid_highlights[i] and 2 or 0)
                end
            end
            
            -- Light the remembered notes
            for i = 1, #memory do
                g:led(memory[i].x, memory[i].y, memory[i].level)
            end

            -- Light the keys
            for i = 1, cols do
                if (keys[i][1] > 0 and keys[i][2] > 0) then
                    g:led(i, 1, 4) -- mid colour for saved keys
                else
                    g:led(i, 1, 2) -- dimmer colour for empty keys
                end
            end

            -- Light the current preset bright
            if current_preset > 0 then
                g:led(current_preset, 1, 8); -- bright colour for selected preset
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
            -- Legacy magic mode
            if params:get("magic_legacy") == 1 then
                clock.sync(math.random(8))
            
                -- Modern magic mode (science)
            else
                -- Need to handle case where jitter is zero
                local jitter_param = params:get("jitter") / 100
                local jitter = jitter_param > 0 and math.random() * jitter_param or 0
                
                -- Then do the jitterbug
                clock.sync(1/mults[2][params:get("magicmult")], jitter)
            end 
            if (math.random(100) < params:get("probability")) then
                rndx = math.random(cols)
                rndy = math.random(2, rows)
                playnote(rndx, rndy)
                remember(rndx, rndy)
                grid_dirty = true
                -- End gate crow
                crow.output[2].volts = 0
            end
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

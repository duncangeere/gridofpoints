-- grid of points
-- v2.15 @duncangeere
--
-- sixteen notes, seven timbres
-- with apologies to Liz Harris
-- 
-- > k1: toggle alt
-- > k2: up a fifth
-- > k3: down a fifth
-- > alt + k3: toggle magic mode
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
-- arc
--
-- > button: hold for alt control
--
-- > E1: volume
-- > E2: release
-- > E3: filter cutoff
-- > E4: probability
--
-- > E1 alt: clock multiplier
-- > E2 alt: random pan
-- > E3 alt: filter resonance
-- > E4 alt: jitter
--
-- Optional:
-- crow
--
-- > out1: v/oct
-- > out2: gate
-- > out3: -5V-5V on y-axis
-- > out4: 0-10V on y-axis
-- 
-- Optional: JF, MIDI
-- should work as you expect

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

-- Init arc
a = arc.connect()

-- Init function
function init()
    
    -- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
    musicutil = require("musicutil")
    -- Import json library: https://github.com/rxi/json.lua
    json = include("lib/json")

    -- Set the engine parameters
    memory = {};
    keys = {};
    preset_clocks = {};
    grid_highlights = {};
    current_preset = 0;

    -- Grid and arc tracking variables
    screen_dirty = true;
    grid_dirty = true;
    grid_connected = false;
    arc_dirty = true;
    arc_connected = false;
    k1down = false; -- tracking if norns k1 is down

    -- Param variables
    mults = {{ "0.25x", "0.5x", "1x", "2x", "4x"},{ 0.25, 0.5, 1, 2, 4}};
    magicopts = {"false", "true"};
    mult_hundred = 300 -- for arc
    
    --- randomness for arc probability
    rand_prob = {};
    rand_jit = {};
    new_rand = true;

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
        screen.text_right("ø")
    end

    if grid_connected then
        -- Show that grid is connected
        screen.font_size(8)
        screen.font_face(1)
        screen.level(15)

        screen.move(124, 10)
        screen.text_right("▦")
    end

    if arc_connected then
        -- Show that arc is connected
        screen.font_size(8)
        screen.font_face(1)
        screen.level(15)

        screen.move(124, 20)
        screen.text_right("o")
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
                clock.sleep(1);

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

    arc_dirty = true
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

-- Arc functions
a.key = function(n,z)
    -- toggle alt on/off when key is pressed
    k1down = z == 1
    arc_dirty = true
end

a.delta = function(n, d)

    -- reduce delta sensitivity from parameter
    d = d/params:get("arc_sens")

    -- If alt is not pressed
    if not k1down then
        if n == 1 then params:delta("db", d) end
        if n == 2 then params:delta("release", d * 8) end
        if n == 3 then params:delta("cutoff", d) end
        if n == 4 then params:delta("probability", d) end
    else -- If alt is pressed
        if n == 1 then delta_mult(d*params:get("arc_sens")) end
        if n == 2 then params:delta("pandom", d) end
        if n == 3 then params:delta("gain", d * 0.1) end
        if n == 4 then params:delta("jitter", d) end
    end

    arc_dirty = true;
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
        action = function(x) 
            engine.db(x) 
            arc_dirty = true
        end
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
        controlspec = controlspec.new(0, 1, 'lin', 0.01, 0.4, "", 0.01, false),
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
        action = function() 
            local root_note = params:get("root_note")
            local root_octave = math.floor(root_note / 12) - 2
            params:set("root_octave", root_octave, true)
            build_scale()
        end
    }

    params:add {
        type = "number",
        id = "root_octave",
        name = "root octave",
        min = -2,
        max = 8,
        default = 2,
        action = function() 
            local root_octave = params:get("root_octave")
            local root_note = params:get("root_note")
            local note_within_octave = root_note % 12
            local new_midi_note = (root_octave + 2) * 12 + note_within_octave
            params:set("root_note", new_midi_note, true)
            build_scale()
        end
    }

    params:set("root_octave", math.floor(params:get("root_note") / 12) -2, true)

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
        30, -- max
        0, -- default
        function(param) return param:get().."%" end, -- formatter
        false -- wrap
    )

    -- Generate a new random table when jitter goes to 0
    params:set_action("jitter", function(value)
        if value == 0 then
            new_rand = true
        end
    end)

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

    -- Generate a new random table when probability goes to 0
    params:set_action("probability", function(value)
        if value == 0 then
            new_rand = true
        end
    end)

    ---- Clock multiplication
    params:add {
        type = "option",
        id = "magicmult",
        name = "Clock multiplier",
        options = mults[1],
        default = 3
    }

    params:set_action("magicmult", function(value)
        --mult_hundred = value * 100 -- convert to 100s for arc
    end)

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

    --- arc sensitivity
    params:add_separator("Arc")
    params:add_number("arc_sens", "Sensitivity", 1, 100, 10)

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

        -- Regen random numbers if needed
        if new_rand then
            fill_rand_tables()
            new_rand = false
        end

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

        -- Check if arc is connected
        if not arc_connected then
            if a.device == nil then
                arc_connected = false
            else
                print("arc connected!")
                arc_connected = true
                arc_dirty = true
                screen_dirty = true
            end
        else
            if a.device == nil then
                print("arc disconnected!")
                arc_connected = false
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
            grid_dirty = false
        end

        -- Arc display
        if arc_dirty then

            -- clear all LEDs
            a:all(0)

            -- set the LEDs for each encoder position
            for i = 1, 4 do
                if not k1down then
                    
                    -- 1 volume
                    if i == 1 then
                        --- calculate 0-60 volume
                        local volume = util.linlin(-96, 32, 0, 60, params:get("db"))

                        -- calculate angle & brightness
                        local degree = util.linlin(0,60,0,340, volume)
                        local brightness = util.linlin(0,60,0,15, volume)
                        
                        --- Display it
                        --- a:segment(ring, from, to, level)
                        a:segment(i, math.rad(190), math.rad(190+degree), brightness)
                        a:led(1, 13, 1) -- light up default value

                    end

                    -- 2 release
                    if i == 2 then
                        -- calculate 0-10 release
                        local release = util.linlin(0.1, 10, 0, 60, params:get("release"))

                        -- calculate angle & brightness
                        local degree = util.linlin(0,60,0,340, release)
                        local brightness = util.linlin(0,60,0,15, release)

                        -- Display it
                        a:segment(i, math.rad(190), math.rad(190+degree), brightness)

                        -- Display second markers
                        for j = 0, 10 do
                            -- figure out which LED to light up
                            local led_num = figure_out_release(j)
                            -- light it up
                            a:led(i, led_num, 1)
                        end

                    end

                    -- 3 filter cutoff
                    if i == 3 then
                        -- calculate 0-20000 filter cutoff
                        local cutoff = util.explin(20, 20000, 0, 60, params:get("cutoff"))

                        -- calculate filter resonance for brightness
                        local resonance = util.linlin(0, 4, 1, 15, params:get("gain"))

                        -- calculate angle & brightness
                        -- local degree = util.linlin(0,60,0,340, cutoff)
                        -- Display it
                        --a:segment(i, math.rad(190), math.rad(190+degree), brightness)

                        -- Display it
                        for j = 1, cutoff do
                            -- figure out which LED to light up
                            local led_num = j + 34

                            -- Brighten it up near the end of the chain
                            brightness = math.floor(util.linexp(1, cutoff, 1, math.floor(resonance + 0.5), j))

                            -- light it up
                            a:led(i, led_num, brightness)
                        end
                    end

                    -- 4 probability
                    if i == 4 then
                        -- calculate 0-100 probability
                        local probability = util.linlin(0, 100, 0, 64, params:get("probability"))
                        local brightness = math.floor(util.linlin(0, 100, 0, 15, params:get("probability")))

                        -- fill the arc randomly with bars as the probability increases
                        for j = 1, probability do

                            -- figure out which LED to light up
                            local led_num = rand_prob[j]

                            -- light it up
                            a:led(i, led_num, brightness)
                        end
                    end

                elseif k1down then
                    -- 1 clock multiplier
                    if i == 1 then
                        -- get the multiplier value
                        local mult = params:get("magicmult")

                        -- 0.25x
                        a:led(i, 54, mult == 1 and 15 or 1)

                        -- 0.5x
                        a:led(i, 58, mult == 2 and 15 or 1)
                        a:led(i, 59, mult == 2 and 15 or 1)

                        -- 1x
                        a:led(i, 63, mult == 3 and 15 or 1)
                        a:led(i, 64, mult == 3 and 15 or 1)
                        a:led(i, 1, mult == 3 and 15 or 1)
                        a:led(i, 2, mult == 3 and 15 or 1)

                        -- 2x
                        for j = 6,13 do
                            a:led(i, j, mult == 4 and 15 or 1)
                        end

                        -- 4x
                        for j = 17,31 do
                            a:led(i, j, mult == 5 and 15 or 1)
                        end
                    end

                    -- 2 random pan
                    if i == 2 then
                        -- get the random pan value
                        local pandom = util.linlin(0,1,0,30,params:get("pandom"))

                        if pandom == 0 then
                            -- if pandom is 0, light up the top three LEDs
                            a:led(i, 64, 15)
                            a:led(i, 1, 15)
                            a:led(i, 2, 15)
                            
                        else
                        -- light up leds on left and right side of centre
                            for j = 3, pandom do
                                a:led(i, j, 15)
                                a:led(i, 66-j, 15)
                            end
                        end

                    end

                    -- 3 filter resonance
                    if i == 3 then
                        -- calculate 0-20000 filter cutoff
                        local cutoff = util.explin(20, 20000, 0, 60, params:get("cutoff"))

                        -- calculate filter resonance for brightness
                        local resonance = util.linlin(0, 4, 1, 15, params:get("gain"))

                        -- calculate angle & brightness
                        -- local degree = util.linlin(0,60,0,340, cutoff)
                        -- Display it
                        --a:segment(i, math.rad(190), math.rad(190+degree), brightness)

                        -- Display it
                        for j = 1, cutoff do
                            -- figure out which LED to light up
                            local led_num = j + 34

                            -- Brighten it up near the end of the chain
                            brightness = math.floor(util.linexp(1, cutoff, 1, math.floor(resonance + 0.5), j))

                            -- light it up
                            a:led(i, led_num, brightness)
                        end
                    end

                    -- 4 jitter
                    if i == 4 then
                        -- get the jitter value
                        local jitter = math.floor(util.linlin(0,30,0,64,params:get("jitter")))

                        -- light up all the LEDs a little
                        for j = 1, 64 do
                            a:led(i, j, 1)
                        end

                        -- light up the LEDs randomly based on the jitter value
                        for j = 1, jitter do
                            -- figure out which LED to light up
                            local led_num = rand_jit[j]
                            -- light it up
                            a:led(i, led_num, 15)
                        end


                    end
                end
            end

            a:refresh()
            arc_dirty = false
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

-- Function to tell me which arc LED should be lit up for a given value of the release parameter
function figure_out_release(val)
    local quantity = math.floor(util.linexp(0.1, 10, 34, 34+60, val)+0.5)
    if quantity > 64 then
        return quantity - 64
    else
        return quantity
    end
end

-- Function to check if a table contains a specific element
function table.contains(t, element)
  for _, value in pairs(t) do
    if value == element then
      return true
    end
  end
  return false
end

-- Fill the random tables with 64 random numbers, without repeats
function fill_rand_tables()

    -- Clear the tables first
    rand_prob = {}
    rand_jit = {}

    -- Fill the rand_prob table with unique random numbers from 1 to 64
    for i = 1, 64 do
        local rand_num = math.random(1, 64)
        -- Check if the number is already in the table
        while table.contains(rand_prob, rand_num) do
            rand_num = math.random(1, 64)
        end
        -- Add the unique random number to the table
        table.insert(rand_prob, rand_num)
    end

    -- Fill the rand_jit table with unique random numbers from 1 to 64
    for i = 1, 64 do
        local rand_num = math.random(1, 64)
        -- Check if the number is already in the table
        while table.contains(rand_jit, rand_num) do
            rand_num = math.random(1, 64)
        end
        -- Add the unique random number to the table
        table.insert(rand_jit, rand_num)
    end
end 

function delta_mult(d)
    -- There are 5 clock multipliers
    -- We can represent these as 100, 200, 300, 400, 500
    -- We want to use the delta value to change the multiplier
    -- But it changes too fast
    -- So we use a large variable to track it, and then round it to the nearest 100
    mult_hundred = util.clamp(mult_hundred + d, 100, 500)
    -- Round it to the nearest 100
    newparam = math.floor(mult_hundred / 100 + 0.5)
    params:set("magicmult", newparam, true)
end
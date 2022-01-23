-- grid of points
-- v1.0 @duncangeere
--
-- eight notes, sixteen timbres
-- with apologies to Liz Harris
--
-- >> k2: up one octave
-- >> k3: down one octave
--
-- >> e2: change root note
-- >> e3: change scale
-- 
-- Required:
-- Grid
--
-- >> left/right controls pitch, up/down controls filter cutoff
--
-- Optional:
-- Crow
--
-- >> out1: v/oct
-- >> out2: gate
-- >> out3: -5V to 5V on left/right axis
-- >> out4: 0 to 10V on left/right axis
engine.name = "PolyPerc" -- Pick synth engine

-- Init grid
g = grid.connect()

-- Init function
function init()

    -- Import musicutil library: https://monome.org/docs/norns/reference/lib/musicutil
    musicutil = require("musicutil")

    -- Custom cutoff frequencies table
    cutoffs = {361, 397, 584, 1086, 2110, 3892, 6697, 10817}

    addparams()
    build_scale()

    screen_dirty = true

    -- Start a clock to refresh the screen
    redraw_clock_id = clock.run(redraw_clock)
end

-- Visuals
function redraw()

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
end

-- Grid functions
function g.key(x, y, z)

    -- When you press it...
    if z == 1 then -- if we press any grid key

        g:all(0)

        -- Light the LED 
        g:led(x, y, 15)
        g:refresh()

        -- Play a note
        engine.cutoff(cutoffs[9 - y])
        engine.hz(notes_freq[x])

        -- Output gate crow
        crow.output[1].volts = (notes_nums[x] - 48) / 12
        crow.output[3].volts = -5 + (y - 1) * (10 / 7)
        crow.output[4].volts = (y - 1) * (10 / 7)
        crow.output[2].volts = 0
        crow.output[2].volts = 5

    end

    -- When you depress it...
    if z == 0 then

        -- Turn off LED
        g:led(x, y, 1)
        g:refresh()

        -- End gate crow
        crow.output[2].volts = 0

    end
end

-- Key functions
function key(n, z)

    -- KEY2 down one octave
    if n == 2 and z == 1 then
        params:set("root_note", params:get("root_note") - 12)
        build_scale()
    end

    -- KEY3 up one octave
    if n == 3 and z == 1 then
        params:set("root_note", params:get("root_note") + 12)
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

-- All the parameters
function addparams()

    -- Root Note
    params:add{
        type = "number",
        id = "root_note",
        name = "root note",
        min = 0,
        max = 127,
        default = math.random(50, 70),
        formatter = function(param)
            return musicutil.note_num_to_name(param:get(), true)
        end,
        action = function() build_scale() end
    }

    -- Scale
    scale_names = {}
    for i = 1, #musicutil.SCALES do
        table.insert(scale_names, musicutil.SCALES[i].name)
    end

    params:add{
        type = "option",
        id = "scale",
        name = "scale",
        options = scale_names,
        default = math.random(#scale_names),
        action = function() build_scale() end -- update the scale when it's changed
    }
end

-- Build the scale
function build_scale()
    notes_nums = musicutil.generate_scale_of_length(params:get("root_note"),
                                                    params:get("scale"), 16) -- builds scale
    notes_freq = musicutil.note_nums_to_freqs(notes_nums) -- converts note numbers to an array of frequencies

    screen_dirty = true
end

-- Check if the screen needs redrawing 15 times a second
function redraw_clock()
    while true do
        clock.sleep(1 / 15)
        if screen_dirty then
            redraw()
            screen_dirty = false
        end
    end
end

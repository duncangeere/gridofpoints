-- grid of points
-- v1.4 @duncangeere
--
-- sixteen notes, eight timbres
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
    cols = g.device.cols
    rows = g.device.rows

    memory = {}

    addparams()
    build_scale()

    screen_dirty = true
    grid_dirty = true

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

        -- remember the key pressed
        remember(x, y)
        grid_dirty = true

        -- Play a note
        engine.cutoff(cutoffs[1 + rows - y])
        engine.hz(notes_freq[x])

        -- Output gate crow
        crow.output[1].volts = (notes_nums[x] - 48) / 12
        crow.output[3].volts = map(y, 1, rows, 5, -5)
        crow.output[4].volts = map(y, 1, rows, 10, 0)
        crow.output[2].volts = 0
        crow.output[2].volts = 5

    end

    -- When you depress it...
    if z == 0 then
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
        default = math.random(50, 60),
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
                                                    params:get("scale"), cols) -- builds scale
    notes_freq = musicutil.note_nums_to_freqs(notes_nums) -- converts note numbers to an array of frequencies

    screen_dirty = true
end

-- Check if the screen needs redrawing 15 times a second
function redraw_clock()
    while true do
        clock.sleep(1 / 15)

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

-- Function to map values from one range to another
function map(n, start, stop, newStart, newStop, withinBounds)
    local value = ((n - start) / (stop - start)) * (newStop - newStart) +
                      newStart

    -- // Returns basic value
    if not withinBounds then return value end

    -- // Returns values constrained to exact range
    if newStart < newStop then
        return math.max(math.min(value, newStop), newStart)
    else
        return math.max(math.min(value, newStart), newStop)
    end
end

-- function to remember
function remember(xcoord, ycoord)
    table.insert(memory, {x = xcoord, y = ycoord, level = 15})
end

-- function to forget
function forget()
    while true do
        clock.sleep(1 / 5)
        for i = 1, #memory do memory[i]["level"] = memory[i]["level"] - 1 end
        filter_inplace(memory, function(elem) return elem["level"] >= 1 end)
        grid_dirty = true
    end
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

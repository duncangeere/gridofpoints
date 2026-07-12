-- griiid of points
-- an iii port of gridofpoints
-- by @duncangeere and @dessertplanet 
--
-- sixteen notes, seven velocities
-- with apologies to Liz Harris

-- Init function
function init()
    
    -- Set core parameters
    memory = {};
    grid_highlights = {};
    grid_dirty = true;
    shift = false;
    midi_channel = 1;
    rows = grid_size_y()
    cols = grid_size_x()

    -- Set harmonic parameters
    scales = {
        major    = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 17, 19, 21, 23, 24, 26},
        minor    = {0, 2, 3, 5, 7, 8, 10, 12, 14, 15, 17, 19, 20, 22, 24, 26},
        majpent  = {0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24, 26, 28, 31, 33, 36},
        minpent  = {0, 3, 5, 7, 10, 12, 15, 17, 19, 22, 24, 27, 29, 31, 34, 36},
        dorian   = {0, 2, 3, 5, 7, 9, 10, 12, 14, 15, 17, 19, 21, 22, 24, 26}
    }

    root = 60
    offset = 0
    intervals = scales["major"]

    -- Highlight the octave notes
    refresh_octave_highlights()
  
    -- Run metros for redrawing the grid and forgetting notes
    redraw_metro = metro.init(redraw_clock, 1 / 15)
    forget_metro = metro.init(forget, 1 / 2)
    redraw_metro:start()
    forget_metro:start()
end

-- Grid functions
function event_grid(x, y, z)
    
    if z == 1 then -- if we press any grid key

        if (y == 1) then -- top rpw
            if (x <= 12) then -- first 12 keys are offsets
                -- change the root note
                offset = clamp(x-1, 0, 11)
            elseif (x == 16) then -- last col
                if not shift then
                    -- turn on shift mode
                    shift = true
                end
            end
            
        else -- rest of the rows
            if shift then
                if (x == 16) and (y == 8) then
                    incantation() -- activate magic mode
                end
            else
                -- turn on the midi note pressed
                note = root + offset + intervals[clamp(x, 1, #intervals)] - 12
                vel = round(linlin(y,2,8,12,127))
                remember(x, y, note)
                midi_note_on(note, vel, midi_channel)
            end
        end

        grid_dirty = true
    end

    if z == 0 then -- when we let go of grid key
        if (y == 1) then -- top row only
            if (x == 16) then -- last col
                if shift then
                    -- turn off shift mode
                    shift = false
                end
            end
        else
            -- turn off the midi note again
            note = root + offset + intervals[clamp(x, 1, #intervals)] - 12
            midi_note_off(note, 0, midi_channel)
        end
    end
end

-- function to redraw the grid
function redraw_clock()

    if grid_dirty then

        -- set all grid leds to 0
        grid_led_all(0)

        -- draw octave highlights
        for i = 1, cols do
            for j = 2, rows do
                grid_led(i, j, grid_highlights[i] and 2 or 0)
            end
        end
        
        -- draw memory leds
        for i = 1, #memory do
            grid_led(memory[i].x, memory[i].y, memory[i].level)
        end

        -- light up top row
        for i = 1, cols do

             -- light up offset choices
            if (i <= 12) then
                if (i-1 == offset) then
                    -- light offset brighter
                    grid_led(i, 1, 4)
                else
                    grid_led(i, 1, 2)
                end
            end

            -- light up shift key
            if (i == 16) then
                if shift then 
                    grid_led(i, 1, 4)
                else
                    grid_led(i, 1, 2)
                end
            end
        end

        -- refresh the grid
        grid_refresh()
        grid_dirty = false
    end
end

-- function to remember notes played
function remember(xcoord, ycoord, n)
    table.insert(memory, { x = xcoord, y = ycoord, level = 15, note = n})
end

-- function to slowly forget notes played
function forget()
    -- run through memories
    for i = 1, #memory do 
        -- weaken each memory by 1
        memory[i]["level"] = memory[i]["level"] - 1
        -- turn off any notes that reach 0 memory
        if (memory[i]["level"] == 0) then
            midi_note_off(memory[i]["note"], 0, midi_channel)
        end
    end

    -- get rid of old memories that have reached zero
    filter_inplace(memory, function(elem) return elem["level"] >= 1 end)
    grid_dirty = true
end

function incantation() -- TODO
    print("magic mode isn't ready yet")
end

-- function to change scales in druid
function scale(s)
    -- check input is valid
    if scales[s] then
        intervals = scales[s]
        print("scale is now: " .. s)
        refresh_octave_highlights()
        grid_dirty = true
    else
        print("scale not found")
        print("try: major, minor, majpent, minpent, dorian")
    end
end

-- function to highlight the octaves
function refresh_octave_highlights()
    grid_highlights = {}
    for _, interval in ipairs(intervals) do
        table.insert(grid_highlights, interval % 12 == 0)
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

init()
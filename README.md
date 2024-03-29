# gridofpoints

Eight notes, sixteen timbres. A simple, well-commented Norns script for turning a Grid into a quantized keyboard.

- e2: change root note
- e3: change scale
- k2: up a fifth
- k3: down a fifth

## grid (required)

- press a key to make beautiful sounds
- left/right position controls pitch
- up/down position controls timbre / midi CC
- top row lets you save and load root/scale combinations
- long press to save, short press to load

## crow (optional)

- out1: v/oct
- out2: gate
- out3: -5V to 5V on up/down axis
- out4: 0 to 10V on up/down axis

## install

Find it in the Maiden project manager

## troubleshooting

If you get an 'error: init' on load, then make sure you have a Grid plugged in. The script doesn't function without one. If you have a Grid plugged in and you're still seeing this error then post below with details of what Grid you're using and how it's connected to your Norns.

## version history

### v1.9

Some substantial changes! First and foremost is a new engine that crossfades between sine and square on the y-axis. You can now tweak the exact engine parameters in the params menu too. In addition, the k2 and k3 buttons now move in fifths rather than octaves, for greater performability. Finally, the top row of the grid is now taken up by a row of note/scale combinations that you can switch between. Long press (two seconds) to save, short press to load. The first button is populated with a C minor pentatonic scale by default.

### v1.8

Added MIDI CC output. It's mapped to the up/down axis - values near the top of the grid give you greater CC values. You can choose what CC channel you want to send in the params menu. This means that the MIDI note length is no longer mapped to the up/down axis as it was in the previous version. I also fixed a small bug where MIDI notes were playing one octave too high.

### v1.7

Added MIDI output. It works just like regular output, except that moving along the up/down axis of an attached grid no longer changes filter cutoff. Instead it changes the MIDI note length. Near the top you get plucky 0.01-second notes, at the bottom you get sustained 3-second notes. You can customise this by editing the `midilengths` table near the top of `gridofpoints.lua`.

### v1.6

add "magic mode" where random notes are played over time. To engage and disengage, press the four corners of the grid at the same time. The pace of forgetting past notes has also been slowed.

### v1.5

gridofpoints now checks if a grid is connected and displays an error message if not

### v1.4

button-press memories now fade with time, rather than with action (pressing keys)

### v1.3

gridofpoints remembers which keys you pressed, though memories fade

### v1.2

Fixing inverted Crow outputs 3/4
Added support for grids that aren't 16x8

### v1.1

Reversed x/y mappings on grid, and output one and two on Crow
Also added a faint echo on grid of the last note you pressed, so it's easier to remember where you were

### v1.0

Initial release

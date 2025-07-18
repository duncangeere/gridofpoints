# gridofpoints

Sixteen notes, seven timbres. A simple, well-commented Norns script for turning Grid into a quantized keyboard.

- e1: change root octave
- e2: change root note
- e3: change scale
- k1: toggle alt
- k2: up a fifth
- k3: down a fifth
- alt + k3: magic mode

## Grid (optional)

- press a key to make beautiful sounds
- left/right position controls pitch
- up/down position controls timbre / midi CC

## Arc (optional)

- button: alt
- E1: volume
- E2: release
- E3: filter cutoff
- E4: probability
- E1 alt: clock multiplier
- E2 alt: random pan
- E3 alt: filter resonance
- E4 alt: jitter

## Crow (optional)

- out1: v/oct
- out2: gate
- out3: -5V to 5V on up/down axis
- out4: 0 to 10V on up/down axis

## MIDI (optional)

- left/right position controls MIDI pitch
- up/down position controls MIDI CC
- Note length can be adjusted in parameters

## Just Friends (optional)

- Connect to Crow with i2c cable
- left/right position controls pitch
- up/down position controls level
- Pro tip: Crow outputs 3/4 can be used to allow up/down position to modulate other JF parameters.

## install

Find it in the Maiden project manager

## troubleshooting

If you get an 'error: init' on load, then make sure you have a Grid plugged in. The script doesn't function without one. If you have a Grid plugged in and you're still seeing this error then post below with details of what Grid you're using and how it's connected to your Norns.

## Version history

### v2.15

Arc support! Plug in an arc and you can now control volume, release, filter cutoff and note probability with the arc wheels. If your arc has a button, press it to access a second set of parameters: clock mult, random pan, filter resonance, and jitter, otherwise hold K1 on Norns. I've tuned arc encoder sensitivity to my personal taste, but there's a parameter to tweak it if you want to.

Long keypress time to save a root/scale combo is now 1 second, rather than 2 seconds.

Jitter now maxes out at 30%, because it didn't make much audible difference above that.

### v2.1

Saved parameters are now stored in data/gridofpoints/keys.json, which means you don't lose them if you close the script, and you don't lose them if you delete and reinstall the script either. If you do want to clear your presets, you can delete this file and it'll be recreated with one default (C2 minor pentatonic).

Root note octave is now a parameter alongside root note, so you can map it to a midi controller. Previously this functionality was only available on E1.

Magic mode is no longer activated/deactivated by pressing all four corners of the grid. This was cute, but it made sound and you don't always want to do that in a show. It's now activated with K1+K3 (or a MIDI mapping) instead.

There's a new parameter that adds random panning to both manual and magic mode notes. No longer will your notes all be sitting in one place in the stereo field!

Jitter now defaults to 0. If you're playing beat-synced, this means you'll be locked in from the start. You can always turn it up again, or change the default on your own device if you want to.

I've refactored the UI a little bit. The root note is now smaller, and the scale name uses the default norns font. In the top right, you'll see a ▦ when a grid is plugged in, and in the bottom right you'll see a ø when magic mode is activated.

Last but not least, gridofpoints is now playable without a grid! If you don't have a grid you'll only be able to use magic mode (K1 + K3), but everything else should work great.

### v2.01

For convenience, magic mode is now a parameter that can be MIDI-mapped.

### v2.0

You can now choose which parameter is controlled on the y-axis of the grid. Crossfade between sine and square waves, adjust the release time, or control the cutoff of a low-pass filter.

The generative “magic mode” now has adjustable controls for jitter, probability and clock multiplication in parameters. Prefer the old approach? Turn on “Legacy magic mode” in parameters.

Gridofpoints now supports i2c connections to Just Friends. It’s on by default, but you can turn it off if you want to in the parameters menu.

Finally, the grid now shows you where the octaves are in your chosen scale with slightly brighter LEDs. This makes it much easier to play the notes you want and not the ones you don’t.

### v1.9

A few changes. First and foremost is a new engine that crossfades between sine and square on the y-axis. You can now tweak the exact engine parameters in the params menu too. In addition, the k2 and k3 buttons now move in fifths rather than octaves, for greater performability. Finally, the top row of the grid is now taken up by a row of preset note/scale combinations that you can switch between. Long press to save, short press to load.

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

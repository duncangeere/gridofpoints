// CroneEngine_GridofPoints
// mix of sine and pluse with perc envelopes, triggered on freq
Engine_GridofPoints : CroneEngine {
	var pg;
    var db=0;
    var release=0.5;
    var pw=0.5;
    var cutoff=10000;
    var gain=1;
    var pan = 0;
    var crossfade = 0.5;

	*new { arg context, doneCallback;
		^super.new(context, doneCallback);
	}

	alloc {
		pg = ParGroup.tail(context.xg);
    SynthDef("GridofPoints", {
			arg out, freq = 440, pw=pw, db=db, cutoff=cutoff, gain=gain, release=release, pan=pan, crossfade=crossfade;
			var note = freq.cpsmidi;
			var amp = db.dbamp;
			//var detune = [note-0.1,note+0.1].midicps;
			var detune = [note-SinOsc.kr(1/3).range(0.1.neg,0),note+SinOsc.kr(1/4).range(0.1.neg,0)].midicps;
			//var detune = [note, note].midicps;
			var snd = SinOsc.ar(detune);
			var snd2 = Pulse.ar(detune,pw);
			
			var mixed = SelectX.ar(crossfade,[snd,snd2]);
			
			var filt = MoogFF.ar(mixed,cutoff,gain);
			var env = Env.perc(level: amp, releaseTime: release).kr(2);
			var enveloped = (filt*env).tanh;
			Out.ar(out, Balance2.ar(enveloped[0],enveloped[1],pan));
		}).add;

		this.addCommand("hz", "f", { arg msg;
			var val = msg[1];
      Synth("GridofPoints", [\out, context.out_b, \freq,val,\pw,pw,\db,db,\cutoff,cutoff,\gain,gain,\release,release,\pan,pan,\crossfade,crossfade], target:pg);
		});

		this.addCommand("db", "f", { arg msg;
			db = msg[1];
		});

		this.addCommand("pw", "f", { arg msg;
			pw = msg[1];
		});
		
		this.addCommand("release", "f", { arg msg;
			release = msg[1];
		});
		
		this.addCommand("cutoff", "f", { arg msg;
			cutoff = msg[1];
		});
		
		this.addCommand("gain", "f", { arg msg;
			gain = msg[1];
		});
		
		this.addCommand("pan", "f", { arg msg;
			pan = msg[1];
		});
		
		this.addCommand("crossfade", "f", { arg msg;
			crossfade = msg[1];
		});
	}

	free { 
		pg.free;
	}
}

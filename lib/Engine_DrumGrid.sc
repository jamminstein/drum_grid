Engine_DrumGrid : CroneEngine {

  alloc {

    SynthDef(\dg_kick, { |out=0, freq=60, punch=200, dec=0.45, amp=0.9|
      var env   = EnvGen.ar(Env.perc(0.002, dec), doneAction: Done.freeSelf);
      var freq2 = EnvGen.ar(Env.perc(0.001, dec*0.3), timeScale: 1) * punch + freq;
      var sig   = SinOscFB.ar(freq2, 0.3) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_snare, { |out=0, freq=200, tone=0.4, dec=0.18, amp=0.8|
      var env   = EnvGen.ar(Env.perc(0.003, dec), doneAction: Done.freeSelf);
      var noise = WhiteNoise.ar;
      var body  = SinOsc.ar(freq) * 0.4;
      var sig   = ((noise * tone) + (body * (1 - tone))) * env;
      sig = HPF.ar(sig, 180);
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_hat, { |out=0, freq=8000, dec=0.06, open=0, amp=0.6|
      var env = EnvGen.ar(Env.perc(0.001, dec + (open * 0.35)), doneAction: Done.freeSelf);
      var sig = HPF.ar(WhiteNoise.ar, freq) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_crash, { |out=0, freq=7000, dec=1.2, shimmer=0.6, amp=0.7|
      var env = EnvGen.ar(Env.perc(0.005, dec), doneAction: Done.freeSelf);
      var sig = HPF.ar(WhiteNoise.ar, freq);
      sig = sig + (SinOsc.ar(freq * shimmer) * 0.2);
      Out.ar(out, (sig * env * amp) ! 2);
    }).add;

    SynthDef(\dg_tom, { |out=0, freq=120, dec=0.35, amp=0.85|
      var env   = EnvGen.ar(Env.perc(0.004, dec), doneAction: Done.freeSelf);
      var freq2 = EnvGen.ar(Env.perc(0.001, dec * 0.25), timeScale: 1) * freq * 0.7 + freq;
      var sig   = SinOscFB.ar(freq2, 0.15) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_cowbell, { |out=0, freq=540, dec=0.55, amp=0.7|
      var env = EnvGen.ar(Env.perc(0.002, dec), doneAction: Done.freeSelf);
      var sig = (SinOsc.ar(freq) + SinOsc.ar(freq * 1.51)) * env * 0.5;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_rim, { |out=0, freq=400, dec=0.05, amp=0.75|
      var env = EnvGen.ar(Env.perc(0.001, dec), doneAction: Done.freeSelf);
      var sig = (SinOsc.ar(freq) * 0.5 + WhiteNoise.ar * 0.5) * env;
      sig = HPF.ar(sig, 300);
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_clap, { |out=0, dec=0.1, amp=0.8|
      var env = EnvGen.ar(Env.perc(0.002, dec), doneAction: Done.freeSelf);
      var sig = HPF.ar(WhiteNoise.ar, 1000) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_clave, { |out=0, freq=2500, dec=0.04, amp=0.7|
      var env = EnvGen.ar(Env.perc(0.001, dec), doneAction: Done.freeSelf);
      var sig = SinOsc.ar(freq) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    SynthDef(\dg_shaker, { |out=0, freq=6000, dec=0.08, amp=0.55|
      var env = EnvGen.ar(Env.perc(0.005, dec), doneAction: Done.freeSelf);
      var sig = BPF.ar(WhiteNoise.ar, freq, 0.5) * env;
      Out.ar(out, (sig * amp) ! 2);
    }).add;

    this.addCommand(\kick,    "ffff", { |msg| Synth(\dg_kick,    [\out, context.out_b, \freq, msg[1], \punch, msg[2], \dec, msg[3], \amp, msg[4]], target: context.xg) });
    this.addCommand(\snare,   "ffff", { |msg| Synth(\dg_snare,   [\out, context.out_b, \freq, msg[1], \tone,  msg[2], \dec, msg[3], \amp, msg[4]], target: context.xg) });
    this.addCommand(\hat,     "ffff", { |msg| Synth(\dg_hat,     [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \open, msg[3], \amp, msg[4]], target: context.xg) });
    this.addCommand(\crash,   "ffff", { |msg| Synth(\dg_crash,   [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \shimmer, msg[3], \amp, msg[4]], target: context.xg) });
    this.addCommand(\tom,     "fff",  { |msg| Synth(\dg_tom,     [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \amp, msg[3]], target: context.xg) });
    this.addCommand(\cowbell, "fff",  { |msg| Synth(\dg_cowbell, [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \amp, msg[3]], target: context.xg) });
    this.addCommand(\rim,     "fff",  { |msg| Synth(\dg_rim,     [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \amp, msg[3]], target: context.xg) });
    this.addCommand(\clap,    "ff",   { |msg| Synth(\dg_clap,    [\out, context.out_b, \dec,  msg[1], \amp,   msg[2]], target: context.xg) });
    this.addCommand(\clave,   "fff",  { |msg| Synth(\dg_clave,   [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \amp, msg[3]], target: context.xg) });
    this.addCommand(\shaker,  "fff",  { |msg| Synth(\dg_shaker,  [\out, context.out_b, \freq, msg[1], \dec,   msg[2], \amp, msg[3]], target: context.xg) });
  }
}

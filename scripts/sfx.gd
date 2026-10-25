class_name Sfx
extends Node

## Procedurally generated sound effects (no external audio files needed).

const RATE := 22050
const POOL := 16

var streams := {}
var players: Array[AudioStreamPlayer] = []
var next := 0
var last_played := {}
var muted := false


func _ready() -> void:
	streams["peg"] = _tone(0.05, 1400.0, 900.0, 0.25, 0.0)
	streams["click"] = _tone(0.03, 1000.0, 1000.0, 0.2, 0.0)
	streams["hit"] = _tone(0.07, 260.0, 120.0, 0.35, 0.55)
	streams["clang"] = _tone(0.12, 2400.0, 1900.0, 0.18, 0.25)
	streams["death"] = _tone(0.22, 300.0, 70.0, 0.4, 0.35)
	streams["bow"] = _tone(0.08, 500.0, 900.0, 0.18, 0.5)
	streams["magic"] = _tone(0.18, 900.0, 1600.0, 0.18, 0.05)
	streams["boom"] = _tone(0.6, 120.0, 30.0, 0.8, 0.9)
	streams["horn"] = _arp([220.0, 277.0, 330.0], 0.16, 0.35)
	streams["levelup"] = _arp([660.0, 880.0, 1320.0], 0.06, 0.3)
	streams["win"] = _arp([523.0, 659.0, 784.0, 1046.0], 0.09, 0.35)
	streams["drum"] = _tone(0.25, 90.0, 50.0, 0.6, 0.4)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


## Plays a sound; `min_gap` throttles very frequent sounds such as captures.
func play(sname: String, pitch := 1.0, min_gap := 0.0, volume_db := 0.0) -> void:
	if muted or not streams.has(sname):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(last_played.get(sname, -10.0)) < min_gap:
		return
	last_played[sname] = now
	var p := players[next]
	next = (next + 1) % POOL
	p.stream = streams[sname]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _tone(dur: float, f0: float, f1: float, amp: float, noise: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += TAU * f / RATE
		var env := (1.0 - t) * (1.0 - t) * minf(1.0, i / 40.0)
		var s := (sin(phase) * (1.0 - noise) + randf_range(-1, 1) * noise) * amp * env
		data.encode_s16(i * 2, int(clampf(s, -1, 1) * 32767))
	return _wav(data)


func _arp(freqs: Array, note_dur: float, amp: float) -> AudioStreamWAV:
	var n_note := int(note_dur * RATE)
	var data := PackedByteArray()
	data.resize(n_note * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		for i in n_note:
			var t := float(i) / n_note
			var env := (1.0 - t) * minf(1.0, i / 30.0)
			var s := (sin(TAU * f * i / RATE) + 0.3 * sin(TAU * f * 2.0 * i / RATE)) * amp * env * 0.8
			data.encode_s16(idx * 2, int(clampf(s, -1, 1) * 32767))
			idx += 1
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

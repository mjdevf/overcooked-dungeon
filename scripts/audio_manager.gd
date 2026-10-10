class_name AudioManager
extends Node
## SFX: file luar Kenney dulu, fallback nada prosedural kalau file tidak ada.

var players: Array[AudioStreamPlayer] = []
var idx := 0
var ext: Dictionary = {}

const SFX_DIR := "res://assets_external/interface-sounds/Audio/"
const MAP := {
	"pickup": "select_002.ogg",
	"place": "drop_001.ogg",
	"chop": "click_004.ogg",
	"cook_done": "confirmation_003.ogg",
	"success": "confirmation_001.ogg",
	"fail": "error_001.ogg",
	"order_up": "open_002.ogg",
	"recruit": "confirmation_004.ogg",
}

func _ready() -> void:
	for i in range(6):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players.append(p)
	for k in MAP.keys():
		var path: String = SFX_DIR + str(MAP[k])
		if ResourceLoader.exists(path):
			var s := load(path)
			if s is AudioStream:
				ext[k] = s

func _tone(freq: float, dur: float, vol: float = 0.35, slide_to: float = 0.0) -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		var t := float(i) / float(rate)
		var f := freq
		if slide_to > 0.0:
			f = lerpf(freq, slide_to, float(i) / float(n))
		var env := 1.0 - float(i) / float(n)
		var s := sin(TAU * f * t) * env * vol
		var v := int(clampf(s, -1.0, 1.0) * 30000.0)
		data.encode_s16(i * 2, v)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

func _play(stream: AudioStream) -> void:
	players[idx].stream = stream
	players[idx].play()
	idx = (idx + 1) % players.size()

func _sfx(name: String, fb_freq: float, fb_dur: float, fb_vol: float, fb_slide: float) -> void:
	if ext.has(name):
		_play(ext[name])
	else:
		_play(_tone(fb_freq, fb_dur, fb_vol, fb_slide))

func pickup() -> void:
	_sfx("pickup", 520.0, 0.09, 0.3, 760.0)

func place() -> void:
	_sfx("place", 440.0, 0.09, 0.3, 330.0)

func chop() -> void:
	_sfx("chop", 180.0, 0.06, 0.4, 120.0)

func cook_done() -> void:
	_sfx("cook_done", 660.0, 0.15, 0.35, 990.0)

func success() -> void:
	_sfx("success", 620.0, 0.28, 0.4, 1240.0)

func fail() -> void:
	_sfx("fail", 220.0, 0.35, 0.4, 110.0)

func alarm() -> void:
	_sfx("alarm", 700.0, 0.5, 0.4, 350.0)

func order_up() -> void:
	_sfx("order_up", 740.0, 0.12, 0.35, 880.0)

func recruit() -> void:
	_sfx("recruit", 500.0, 0.2, 0.4, 900.0)

# Coba putar file eksternal kalau ada (misal assets_external/success.wav)
func play_external(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var s := load(path)
	if s is AudioStream:
		_play(s)
		return true
	return false

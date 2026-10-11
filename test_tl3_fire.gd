extends SceneTree
## TL3: bot padamkan api kompor 2 + kembalikan APAR + buang gosong.
## Catat detik api-menyala -> padam (bandingkan layout lama vs baru).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var stove2 = null
var ignite_frame := -1
var out_frame := -1
var neglect_set := false

func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS: ", name)
	else:
		print("FAIL: ", name)
		fails.append(name)

func _initialize() -> void:
	var ps: PackedScene = load("res://scenes/main.tscn")
	var main = ps.instantiate()
	root.add_child(main)
	game = main

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 9000:
		check(false, "timeout global 9000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		game.orders.score = 500
		# JANGAN rekrut dulu (isolasi: pastikan api menyala tanpa gangguan bot)
		# kompor 2 = stove aktif kedua (5,0)
		var n := 0
		for st in game.stations:
			if st.station_type == "stove" and st.enabled:
				n += 1
				if n == 2:
					stove2 = st
		check(stove2 != null, "setup: kompor 2 ada")
		# bakar: taruh cincang -> masak instan -> gosong -> neglect hampir penuh
		var r: Dictionary = game.find_crate("tomat").interact(null, false)
		var f: FoodItem = r.get("take")
		f.chopped = true
		stove2.interact(f, false)
		stove2.progress = 99.0
		phase = 1
	if phase == 1 and frame < 3000:
		if stove2.cooking == false and stove2.stored and not stove2.stored.cooked:
			pass
		if stove2.stored and stove2.stored.cooked and not stove2.stored.burnt:
			stove2.burn_timer = 99.0
		if stove2.stored and stove2.stored.burnt and not stove2.fire and not neglect_set:
			neglect_set = true
			stove2.neglect_t = 5.5
		if stove2.fire and ignite_frame < 0:
			ignite_frame = frame
			print("  api menyala at frame ", frame)
			game.recruit_bot()
			while game.bots.size() > 1:
				var bb = game.bots.pop_back()
				bb.queue_free()
			phase = 2
	if phase == 2:
		if not stove2.fire and out_frame < 0:
			out_frame = frame
			var dt := float(out_frame - ignite_frame) / 60.0
			print("  api padam at frame ", frame, " (", dt, " dtk sejak menyala)")
			check(true, "bot padamkan api kompor 2")
			phase = 3
	if phase == 3 and frame < 6000:
		var b = game.bots[0]
		# APAR dikembalikan: tangan kosong + tak ada api
		if b.carry == null and not stove2.fire:
			print("  APAR kembali at frame ", frame)
			check(true, "APAR dikembalikan, tangan bot kosong")
			# gosong sisa di kompor -> bot buang ke sampah
			phase = 4
	if phase == 4 and frame < 9000:
		if stove2.stored == null:
			print("  gosong dibuang at frame ", frame)
			check(true, "gosong dibuang bot ke sampah")
			# pemain buang gosong: taruh gosong di tangan, E di sampah
			var r2: Dictionary = game.find_crate("tomat").interact(null, false)
			var f2: FoodItem = r2.get("take")
			f2.chopped = true
			f2.burnt = true
			game.player.set_carry(f2)
			var tr: Station = game.find_trash()
			var pp: Vector3 = tr.global_position + Vector3(0, 0.6, 1.2)
			game.player.global_position = pp
			var d: Vector3 = tr.global_position - pp
			d.y = 0.0
			game.player.face_dir = d.normalized()
			game.do_interact()
			check(game.player.carry == null, "pemain buang gosong ke sampah")
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	return false

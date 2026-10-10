extends SceneTree
## T1: hold_work jangan mencincang bahan siap saji (roti/keju).

var game = null
var frame := 0
var fails: Array = []
var board = null
var phase := 0
var follow_frames := 0

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

func _free_chop() -> Station:
	for st in game.stations:
		if st.station_type == "chop" and st.stored == null:
			return st
	return null

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		board = _free_chop()
		check(board != null, "setup: talenan kosong ada")
		# roti mentah di talenan + hold_work lama -> tetap mentah
		var r1: Dictionary = game.find_crate("roti").interact(null, false)
		board.force_store(r1.get("take"))
		board.hold_work(10.0)
		check(board.stored != null and not board.stored.chopped, "roti tak dicincang hold_work")
		# tomat mentah -> matang normal (kontrol)
		board.take_stored().queue_free()
		var r2: Dictionary = game.find_crate("tomat").interact(null, false)
		board.force_store(r2.get("take"))
		board.hold_work(3.0)
		check(board.stored != null and board.stored.chopped, "tomat tetap bisa dicincang")
		board.take_stored().queue_free()
		# bot follow dekat talenan berisi keju mentah 5 dtk
		game.orders.score = 500
		game.recruit_bot()
		while game.bots.size() > 1:
			var bb = game.bots.pop_back()
			bb.queue_free()
		var r3: Dictionary = game.find_crate("keju").interact(null, false)
		board.force_store(r3.get("take"))
		phase = 1
	if phase == 1 and frame < 400:
		follow_frames += 1
		var b = game.bots[0]
		if is_instance_valid(b):
			# paksa bot dekat talenan tiap frame (simulasi follow)
			b.global_position = board.global_position + Vector3(0, 0.6, 1.0)
			b._follow_player(1.0 / 60.0)
		if follow_frames >= 300:
			check(board.stored != null and not board.stored.chopped, "keju tak dicincang bot follow")
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	return false

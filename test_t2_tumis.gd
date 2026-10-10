extends SceneTree
## T2: tumis maju di bot (tomat cincang diambil ke kompor, tak ditinggal).

var game = null
var frame := 0
var fails: Array = []
var t_uid := 0
var phase := 0
var score0 := 0
var stuck_since := -1

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
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		# paksa resep tumis saja (duplikat dulu: LevelData const read-only)
		var lv: Dictionary = (game.level as Dictionary).duplicate()
		lv["recipes"] = ["tumis"]
		game.level = lv
		game.orders.score = 500
		game.recruit_bot()
		while game.bots.size() > 1:
			var bb = game.bots.pop_back()
			bb.queue_free()
		var o1: Dictionary = game.orders.spawn_recipe("tumis", "T1")
		t_uid = int(o1.get("uid", 0))
		score0 = game.orders.score
		phase = 1
	if phase == 1 and frame < 7500:
		var b = game.bots[0]
		# deteksi macet: 2 talenan penuh cincang-mentah + job Tunggu
		var full_chopped := 0
		for st in game.stations:
			if st.station_type == "chop" and st.stored and not st.stored.is_plate:
				if st.stored.chopped and not st.stored.cooked:
					full_chopped += 1
		if full_chopped >= 2 and is_instance_valid(b) and b._job == "Tunggu":
			if stuck_since < 0:
				stuck_since = frame
			if frame - stuck_since > 600:
				check(false, "bot macet Tunggu + 2 talenan penuh")
				phase = 9
		else:
			stuck_since = -1
		if game.orders.get_order(t_uid).is_empty():
			print("  tumis delivered at ", frame, " score=", game.orders.score)
			check(game.orders.score > score0, "skor naik (tumis terkirim)")
			phase = 2
			frame = 7490
	if frame == 7495:
		check(phase == 2, "minimal 1 tumis terkirim ±120 dtk")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

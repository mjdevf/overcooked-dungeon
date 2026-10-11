extends SceneTree
## TR1: layar hasil + ledger konsisten (serve, expire, api, rekrut, gagal).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var mark := 0
var stove = null
var neglect_once := false
var saved_best: Array = []

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
	for i in range(3):
		saved_best.append(game.load_best(i))

func _restore() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://overcooked_dungeon.cfg")
	for i in range(3):
		cfg.set_value("best", "best_score_%d" % i, int(saved_best[i][0]))
		cfg.set_value("best", "best_stars_%d" % i, int(saved_best[i][1]))
	cfg.save("user://overcooked_dungeon.cfg")

func _finish() -> bool:
	_restore()
	print("TEST DONE fails=", fails.size())
	if fails.is_empty():
		print("ALL PASS")
	quit(0 if fails.is_empty() else 1)
	return true

func _salad_plate() -> FoodItem:
	var plate = null
	for st in game.stations:
		if st.station_type == "plating" and st.stored and st.stored.is_plate and st.stored.plate_contents.is_empty():
			plate = st
			break
	for ing in ["tomat", "selada"]:
		var r: Dictionary = game.find_crate(ing).interact(null, false)
		var f: FoodItem = r.get("take")
		f.chopped = true
		var res: Dictionary = plate.interact(f, false)
		if bool(res.get("place_consumed", false)):
			f.queue_free()
	return plate.take_stored()

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 6000:
		check(false, "timeout global 6000f")
		return _finish()
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		# 1. antar salad cepat: +100 +30 +15 = 145
		var o1: Dictionary = game.orders.spawn_recipe("salad", "T1")
		var p := _salad_plate()
		game._serve(p, game.pass_station().global_position, Vector3(0, 1, 0))
		check(game.orders.score == 145, "setup: skor 145")
		# 2. order hangus: -20 -> 125
		var o2: Dictionary = game.orders.spawn_recipe("salad", "T1")
		o2["time_left"] = 0.05
		mark = frame
		phase = 1
	if phase == 1 and frame - mark > 30:
		check(game.orders.score == 125, "expire -20")
		# 3. api 1 dtk: -2 -> 123
		for st in game.stations:
			if st.station_type == "stove" and st.enabled:
				stove = st
				break
		var r: Dictionary = game.find_crate("tomat").interact(null, false)
		var f: FoodItem = r.get("take")
		f.chopped = true
		stove.interact(f, false)
		stove.progress = 99.0
		phase = 2
	if phase == 2 and frame < 3000:
		if stove.stored and stove.stored.cooked and not stove.stored.burnt:
			stove.burn_timer = 99.0
		if stove.stored and stove.stored.burnt and not stove.fire and not neglect_once:
			neglect_once = true
			stove.neglect_t = 5.9
		if stove.fire and frame - mark > 120:
			stove.extinguish()
			if stove.stored:
				var g = stove.take_stored()
				if g:
					g.queue_free()
			check(game.orders.score == 123, "api -2")
			# 4. rekrut: -50 -> 73
			game.recruit_bot()
			check(game.orders.score == 73, "rekrut -50")
			# 5. salah sajikan: -10 -> 63
			var bad := FoodItem.make_plate()
			game._serve(bad, game.pass_station().global_position, Vector3(0, 1, 0))
			check(game.orders.score == 63, "gagal antar -10")
			# buka L2 biar tombol next muncul (restore nanti)
			var cfg := ConfigFile.new()
			cfg.load("user://overcooked_dungeon.cfg")
			cfg.set_value("best", "best_score_0", 9999)
			cfg.set_value("best", "best_stars_0", 3)
			cfg.save("user://overcooked_dungeon.cfg")
			game.orders.time_left = 0.05
			mark = frame
			phase = 3
	if phase == 3 and frame - mark > 60:
		var h = game.hud
		check(h.over_panel.visible, "panel hasil muncul")
		var txt := _texts(h.over_rows)
		check("Shift selesai!" in txt, "judul shift")
		check("Pesanan selesai" in txt and "1 dari 2" in txt and "+100" in txt, "baris pesanan")
		check("Bonus cepat" in txt and "+30" in txt, "baris bonus")
		check("Tip" in txt and "+15" in txt, "baris tip")
		check("ngamuk" in txt and "-20" in txt, "baris ngamuk")
		check("Kebakaran" in txt and "-2" in txt, "baris kebakaran")
		check("rekrut" in txt and "-50" in txt, "baris rekrut")
		check("Salah sajikan" in txt and "-10" in txt, "baris gagal")
		check("63" in txt and "TOTAL SKOR" in txt, "total 63")
		check("Main lagi" in txt and "Level 2" in txt and "Menu" in txt, "3 tombol")
		# konsistensi: base+bonus+tip-... == skor
		var L: Dictionary = game.ledger
		var total: int = int(L.get("base", 0)) + int(L.get("bonus", 0)) + int(L.get("tip", 0)) - int(L.get("angry", 0)) - int(L.get("fire", 0)) - int(L.get("recruit", 0)) - int(L.get("fail", 0))
		check(total == game.orders.score, "ledger konsisten dgn skor")
		_click_text(h.over_rows, "Main lagi")
		check(game.countdown > 0.0 or game.playing, "main lagi restart")
		return _finish()
	return false

func _texts(n: Node) -> String:
	var out := ""
	if n == null:
		return out
	if n is Label:
		out += " " + (n as Label).text
	if n is Button:
		out += " " + (n as Button).text
	for c in n.get_children():
		out += _texts(c)
	return out

func _click_text(root: Node, t: String) -> void:
	if root is Button and str((root as Button).text) == t:
		(root as Button).emit_signal("pressed")
		return
	for c in root.get_children():
		_click_text(c, t)

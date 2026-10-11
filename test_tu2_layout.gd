extends SceneTree
## TU2: tata letak HUD kompak di 4 ukuran viewport.
## Merah di HUD lama (rel 390, 4 kartu, pill klaim, aksi "[E] ...").

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var sizes := [Vector2i(1280, 720), Vector2i(1275, 743), Vector2i(1600, 900), Vector2i(1024, 600)]
var si := 0
var wait := 0
var tries := 0

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

func _node(name: String):
	if name in game.hud:
		return game.hud.get(name)
	return null

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

func _force_fire() -> void:
	var stove = null
	for st in game.stations:
		if st.station_type == "stove" and st.enabled:
			stove = st
			break
	if stove == null or stove.fire:
		return
	var r: Dictionary = game.find_crate("tomat").interact(null, false)
	var f: FoodItem = r.get("take")
	f.chopped = true
	stove.interact(f, false)
	stove.progress = 99.0
	stove.burn_timer = 99.0
	stove.neglect_t = 5.9

func _any_fire() -> bool:
	for st in game.stations:
		if st.station_type == "stove" and st.fire:
			return true
	return false

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
		game.recruit_bot()
		game.recruit_bot()
		for i in range(4):
			var o: Dictionary = game.orders.spawn_recipe("salad", "T%d" % (1 + i % 2))
			if i < 2:
				o["time_left"] = 20.0
		phase = 1
		wait = frame
	if phase == 1 and frame - wait > 200:
		# klaim harus sudah ada, api dipaksa, lalu ukur cepat-cepat
		check(not game.claims.is_empty(), "setup: ada klaim bot")
		_force_fire()
		phase = 2
		wait = frame
		si = 0
		tries = 0
		root.size = sizes[si]
	if phase == 2:
		if frame - wait < 8:
			return false
		if not _any_fire():
			# bot keburu padamkan: paksa lagi, maks 3x per ukuran
			tries += 1
			if tries > 3:
				check(false, "setup: api menyala di " + str(sizes[si]))
				si += 1
				tries = 0
				if si >= sizes.size():
					return _finish_checks()
				root.size = sizes[si]
				wait = frame
				return false
			_force_fire()
			wait = frame
			return false
		_measure(sizes[si])
		si += 1
		tries = 0
		if si >= sizes.size():
			return _finish_checks()
		root.size = sizes[si]
		wait = frame
	return false

func _finish_checks() -> bool:
	# aksi disembunyikan saat prompt kosong
	game.hud.set_prompt("")
	var abtn = _node("action_btn")
	check(abtn != null and not (abtn as Button).visible, "tombol aksi hidden saat prompt kosong")
	# tak ada pill default
	check("Belum diambil bot" not in _texts(game.hud), "tanpa pill default")
	print("TEST DONE fails=", fails.size())
	if fails.is_empty():
		print("ALL PASS")
	quit(0 if fails.is_empty() else 1)
	return true

func _measure(vp: Vector2i) -> void:
	var tag := "%dx%d" % [vp.x, vp.y]
	# stretch expand: koordinat layout ikut viewport logis, bukan window
	var area: Rect2 = root.get_visible_rect()
	print("  AREA ", tag, " -> ", area)
	var rail = _node("orders_rail")
	check(rail != null, tag + " rel pesanan ada")
	if rail == null:
		return
	var rr: Rect2 = (rail as Control).get_global_rect()
	check(rr.size.x <= 270.0, tag + " lebar rel <= 270 (dapat %.0f)" % rr.size.x)
	check(rr.size.y <= 320.0, tag + " tinggi rel <= 320 (dapat %.0f)" % rr.size.y)
	var cards := []
	var box = _node("orders_box")
	if box != null:
		for c in (box as Control).get_children():
			if c is PanelContainer and not (c as Control).is_queued_for_deletion():
				cards.append(c)
	var plus := false
	var ncard := 0
	var secs := []
	for c in cards:
		var t := _texts(c)
		if t.strip_edges().begins_with("+"):
			plus = true
		else:
			ncard += 1
			var nums := []
			for w in t.split(" "):
				if w.is_valid_int():
					nums.append(w.to_int())
			if not nums.is_empty():
				secs.append(nums[nums.size() - 1])
	check(ncard <= 3, tag + " kartu terlihat <= 3 (dapat %d)" % ncard)
	check(plus, tag + " ada pill +N")
	var ordered := true
	for i in range(1, secs.size()):
		if secs[i] < secs[i - 1]:
			ordered = false
	check(ordered, tag + " kartu urut sabar menaik")
	for c in cards:
		var cr: Rect2 = (c as Control).get_global_rect()
		check(cr.size.y <= 100.0, tag + " tinggi kartu kompak")
	var parts := {"rel": rr}
	var extras := ["score_panel", "fire_banner", "bot_side", "bottom_bar", "pause_btn", "level_label"]
	for e in extras:
		var nd = _node(e)
		check(nd != null, tag + " node " + e + " ada")
		if nd != null and (nd as Control).visible:
			parts[e] = (nd as Control).get_global_rect()
	var keys := parts.keys()
	print("  VP target=", vp, " root=", root.size)
	for k in keys:
		if not area.encloses(parts[k]):
			print("  OUT ", k, "=", parts[k])
	for i in range(keys.size()):
		var r: Rect2 = parts[keys[i]]
		check(area.encloses(r), tag + " " + str(keys[i]) + " di dalam viewport")
		for j in range(i + 1, keys.size()):
			var r2: Rect2 = parts[keys[j]]
			check(not r.intersects(r2), tag + " tak tumpang: " + str(keys[i]) + " vs " + str(keys[j]))

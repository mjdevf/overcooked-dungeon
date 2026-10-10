extends SceneTree
## T4: APAR ditolak di kompor tanpa api + neglect reset + regresi padam.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var stove = null

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
	if frame > 8000:
		check(false, "timeout global 8000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		for st in game.stations:
			if st.station_type == "stove" and st.enabled:
				stove = st
				break
		check(stove != null, "setup: kompor aktif ada")
		# bawa APAR, interact di kompor kosong tanpa api -> ditolak
		var a := FoodItem.make_apar()
		var res: Dictionary = stove.interact(a, false)
		check(not bool(res.get("place_consumed", false)), "APAR ditolak di kompor tanpa api")
		check(stove.stored == null and not stove.cooking, "kompor tetap kosong, tak memasak")
		a.queue_free()
		phase = 1
	if phase == 1 and frame < 2000:
		# gosong 4 dtk -> ambil -> taruh baru -> neglect 0
		if stove.stored == null and not stove.cooking:
			var r: Dictionary = game.find_crate("tomat").interact(null, false)
			var f: FoodItem = r.get("take")
			f.chopped = true
			stove.interact(f, false)
			phase = 2
	if phase == 2 and frame < 3000:
		if stove.cooking:
			# percepat: langsung gosongkan + tunggu 4 dtk neglect
			stove.progress = 99.0
			phase = 3
	if phase == 3:
		if stove.stored and stove.stored.burnt:
			# ambil gosong lewat interact (jalur pemain)
			var take_res: Dictionary = stove.interact(null, false)
			var g: FoodItem = take_res.get("take")
			check(g != null, "gosong bisa diambil")
			if g:
				g.queue_free()
			# taruh bahan baru -> neglect harus 0
			var r2: Dictionary = game.find_crate("selada").interact(null, false)
			var f2: FoodItem = r2.get("take")
			f2.chopped = true
			stove.interact(f2, false)
			check(stove.neglect_t == 0.0, "neglect_t reset setelah ambil + taruh baru")
			if stove.stored:
				var h = stove.take_stored()
				if h:
					h.queue_free()
			# regresi: kebakaran + APAR tetap memadamkan
			var r3: Dictionary = game.find_crate("tomat").interact(null, false)
			var f3: FoodItem = r3.get("take")
			f3.chopped = true
			stove.interact(f3, false)
			stove.progress = 99.0
			phase = 4
	if phase == 4 and frame < 5000:
		if stove.stored and stove.stored.burnt:
			stove.neglect_t = 99.0
			phase = 5
	if phase == 5 and frame < 6000:
		if stove.fire:
			var a2 := FoodItem.make_apar()
			var res2: Dictionary = stove.interact(a2, false)
			check(bool(res2.get("place_consumed", false)), "APAR memadamkan (regresi)")
			check(not stove.fire, "api padam")
			a2.queue_free()
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	return false

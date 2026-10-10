extends SceneTree
## T7b: piring terbang ditahan sampai NPC duduk (WAIT_FOOD), tak dimakan di jalan.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var npc = null
var served_frame := -1

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

func _build_salad() -> FoodItem:
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
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		# rakit salad duluan selagi NPC jalan (tanpa bot biar tak direbut)
		_pre = _build_salad()
		game.try_spawn_npc()
		phase = 1
	if phase == 1 and frame < 3000:
		if not game.orders.active_orders.is_empty() and npc == null:
			# order muncul = NPC mulai jalan ke kursi; sajikan SEGERA
			for n in game.npcs:
				if is_instance_valid(n) and not (n.order as Dictionary).is_empty():
					npc = n
					break
			if npc != null:
				game._serve(_pre, game.pass_station().global_position, Vector3(0, 1, 0))
				_pre = null
				served_frame = frame
				phase = 2
	if phase == 2:
		if served_frame >= 0 and frame - served_frame > 90 and frame - served_frame < 150:
			# 1.5-2.5 dtk setelah sajikan (piring mendarat): NPC harusnya BELUM makan
			if is_instance_valid(npc) and int(npc.state) == 5:
				check(false, "NPC tak makan di jalan (masih TO_SEAT saat piring mendarat)")
				phase = 9
		if is_instance_valid(npc) and int(npc.state) == 5:
			print("  NPC makan at +", frame - served_frame)
			check(frame - served_frame > 72, "makan hanya setelah duduk (tahan >1.2 dtk)")
			check(game.flying.is_empty(), "piring tak nyangkut di udara")
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	return false

var _pre = null

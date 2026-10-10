extends SceneTree
## T7c: bonus +30 & tip +15 relatif terhadap time_max order.

var game = null
var frame := 0
var fails: Array = []
var phase := 0

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

func _serve_salad(tmax: float, tleft: float) -> int:
	var o: Dictionary = game.orders.spawn_recipe("salad", "T1")
	o["time_max"] = tmax
	o["time_left"] = tleft
	var before: int = game.orders.score
	var p := _salad_plate()
	game._serve(p, game.pass_station().global_position, Vector3(0, 1, 0))
	return game.orders.score - before

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 3000:
		check(false, "timeout global 3000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		game.orders.score = 0
		# kasus 1: tmax=30, tleft=25 -> relatif: bonus+tip (125+30... =145); absolut lama: 100 saja
		var d1 := _serve_salad(30.0, 25.0)
		print("  exp1 delta=", d1)
		check(d1 == 100 + 30 + 15, "tmax=30 tleft=25 dapat bonus+tip (145)")
		# kasus 2: tmax=90, tleft=30 -> relatif: tanpa bonus+tip (100); sama lama & baru
		var d2 := _serve_salad(90.0, 30.0)
		print("  exp2 delta=", d2)
		check(d2 == 100, "tmax=90 tleft=30 tanpa bonus (100)")
		# kasus 3: tmax=90, tleft=80 -> relatif: bonus+tip (145); lama juga 145 (kontrol)
		var d3 := _serve_salad(90.0, 80.0)
		print("  exp3 delta=", d3)
		check(d3 == 100 + 30 + 15, "tmax=90 tleft=80 bonus+tip (145)")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

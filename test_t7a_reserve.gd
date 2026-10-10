extends SceneTree
## T7a: reservasi piring per-order (reserve sendiri diprioritaskan, milik lain dilewat).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var uid_a := 0
var uid_b := 0

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

func _salad_order(table: String) -> Dictionary:
	return {"uid": 0, "recipe": LevelData.get_recipe("salad"), "table_id": table}

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 4000:
		check(false, "timeout global 4000f")
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
		var o1: Dictionary = game.orders.spawn_recipe("salad", "T1")
		var o2: Dictionary = game.orders.spawn_recipe("salad", "T2")
		uid_a = int(o1.get("uid", 0))
		uid_b = int(o2.get("uid", 0))
		phase = 1
	if phase == 1 and frame < 1200:
		if game.bots.size() < 2:
			return false
		var p0 = game.bots[0].plan if is_instance_valid(game.bots[0]) else {}
		var p1 = game.bots[1].plan if is_instance_valid(game.bots[1]) else {}
		if p0.is_empty() or p1.is_empty():
			return false
		var ra = game.claims.get(uid_a, {}).get("plate", null)
		var rb = game.claims.get(uid_b, {}).get("plate", null)
		check(ra != null and rb != null, "kedua order punya reserve piring")
		check(ra != rb, "reserve beda piring")
		# prioritas reserve sendiri + skip milik lain (pakai order asli)
		var oa: Dictionary = game.orders.get_order(uid_a)
		var ob: Dictionary = game.orders.get_order(uid_b)
		check(game.plate_for_order(oa) == ra, "reserve sendiri diprioritaskan")
		check(game.plate_for_order(ob) != ra, "reserve order lain dilewat")
		# lepas bersama klaim
		game.release_uid(uid_a)
		check(not game.claims.has(uid_a), "reserve lepas bersama klaim")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

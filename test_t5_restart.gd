extends SceneTree
## T5: restart bersih (fire_sec reset, orders.stop, ring tak freed).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var game_over_count := 0

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

func _on_game_over(_score: int, _stars: int) -> void:
	game_over_count += 1

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
		game.orders.game_over.connect(_on_game_over)
	if frame == 30 and game.playing:
		# sisa waktu 1 dtk + api separuh jalan, lalu restart countdown PENUH 3 dtk.
		# Tanpa fix: time_left lama jalan terus -> game_over palsu di ~F90.
		game.orders.time_left = 1.0
		game.fire_sec = 0.6
		game.restart_level()
		check(game.fire_sec == 0.0, "fire_sec reset di run baru")
		phase = 1
	if phase == 1 and frame == 260:
		check(game_over_count == 0, "tak ada game_over palsu selama countdown")
		check(game.playing, "run baru jalan normal")
		# restart 2x berturut-turut -> ring tak freed
		game.restart_level()
		game.restart_level()
		game.countdown = 0.01
		phase = 2
	if phase == 2 and game.playing and frame > 220:
		check(game.target_ring == null or is_instance_valid(game.target_ring), "target_ring valid setelah restart 2x")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

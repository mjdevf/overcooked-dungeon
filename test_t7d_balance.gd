extends SceneTree
## T7d/e/f + tiered cost: reward, bintang, rush L3, harga rekrut bertingkat.

var game = null
var frame := 0
var fails: Array = []

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
	if frame > 2000:
		check(false, "timeout global 2000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		check(int(LevelData.get_recipe("salad").get("reward", 0)) == 100, "salad 100 tetap")
		check(int(LevelData.get_recipe("roti_lapis").get("reward", 0)) == 90, "roti_lapis 130->90")
		check(int(LevelData.get_recipe("burger").get("reward", 0)) == 120, "burger 170->120")
		check(int(LevelData.get_recipe("tumis").get("reward", 0)) == 180, "tumis 180 tetap")
		var l1: Dictionary = LevelData.LEVELS[0]
		var l2: Dictionary = LevelData.LEVELS[1]
		var l3: Dictionary = LevelData.LEVELS[2]
		check(int(l1.get("star_1", 0)) == 300 and int(l1.get("star_3", 0)) == 900, "bintang L1 300/600/900")
		check(int(l1.get("star_2", 0)) == 600, "bintang L1 tengah 600")
		check(int(l2.get("star_1", 0)) == 350 and int(l2.get("star_2", 0)) == 800 and int(l2.get("star_3", 0)) == 1400, "bintang L2 350/800/1400")
		check(int(l3.get("star_1", 0)) == 400 and int(l3.get("star_2", 0)) == 1000 and int(l3.get("star_3", 0)) == 1900, "bintang L3 400/1000/1900")
		var ev: Array = l3.get("events", [])
		check(float(ev[0].get("at", 0.0)) == 75.0, "rush L3 pertama at 75")
		# harga bertingkat: bot1 50, bot2 150
		game.orders.score = 500
		game.recruit_bot()
		check(game.orders.score == 450, "bot pertama 50")
		game.recruit_bot()
		check(game.orders.score == 300, "bot kedua 150")
		check(game.bots.size() == 2, "2 bot direkrut")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

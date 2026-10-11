extends SceneTree
## TL2: nearest_station memilih station yg benar di layout baru.
## APAR sebelahan kompor 1 — risiko salah pilih. Gagal di layout lama
## untuk sel yg pindah; kalau ada salah pilih, LAPORKAN (jangan pindah station).

var game = null
var frame := 0
var fails: Array = []
var done := false

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

func _at(gx: int, gy: int, dx: float, dz: float) -> Station:
	var o := ProtoConfig.wpos(gx, gy)
	return game.nearest_station(o, Vector3(dx, 0, dz))

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing and not done:
		done = true
		var n := Vector3(0, 0, -1)
		var e := Vector3(1, 0, 0)
		var s1 := _at(3, 1, n.x, n.z)
		print("  (3,1)->N = ", s1.station_type if s1 else "null")
		check(s1 != null and s1.station_type == "apar", "(3,1) hadap atas = APAR")
		var s2 := _at(4, 1, n.x, n.z)
		print("  (4,1)->N = ", s2.station_type if s2 else "null")
		check(s2 != null and s2.station_type == "stove", "(4,1) hadap atas = kompor")
		var s3 := _at(2, 1, n.x, n.z)
		print("  (2,1)->N = ", s3.station_type if s3 else "null")
		check(s3 != null and s3.station_type == "trash", "(2,1) hadap atas = sampah")
		var s4 := _at(10, 6, e.x, e.z)
		print("  (10,6)->E = ", s4.station_type if s4 else "null")
		check(s4 != null and s4.station_type == "sink", "(10,6) hadap kanan = wastafel")
		var s5 := _at(10, 5, e.x, e.z)
		print("  (10,5)->E = ", s5.station_type if s5 else "null")
		check(s5 != null and s5.station_type == "plating", "(10,5) hadap kanan = plating")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

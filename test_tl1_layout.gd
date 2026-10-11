extends SceneTree
## TL1: struktur layout dapur + jarak Manhattan 3 station pindah.
## 3 assert jarak HARUS gagal di layout lama, lulus di layout baru.

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

func _station_cells() -> Dictionary:
	var d := {}
	for s in ProtoConfig.STATIONS:
		var p: Array = s["pos"]
		d[str(p[0]) + "," + str(p[1])] = true
	return d

func _bfs_reachable(from: Vector2i, to: Vector2i) -> bool:
	if from == to:
		return true
	var seen := {str(from.x) + "," + str(from.y): true}
	var queue: Array = [from]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = cur + step
			var k := str(nb.x) + "," + str(nb.y)
			if seen.has(k):
				continue
			if nb == to:
				return true
			if game.astar_blocked(nb.x, nb.y):
				continue
			seen[k] = true
			queue.append(nb)
	return false

func _manhattan(a: Array, b: Array) -> int:
	return absi(int(a[0]) - int(b[0])) + absi(int(a[1]) - int(b[1]))

func _pos_of(kind: String, item := "") -> Array:
	for s in ProtoConfig.STATIONS:
		if str(s["kind"]) != kind:
			continue
		if item != "" and str(s.get("item", "")) != item:
			continue
		return s["pos"]
	return []

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing and not done:
		done = true
		var cells := _station_cells()
		# 1. batas + tak ada tumpang tindih + bukan tembok + huruf bukan "."
		var ok_bounds := true
		for s in ProtoConfig.STATIONS:
			var p: Array = s["pos"]
			var x := int(p[0])
			var y := int(p[1])
			if x < 0 or y < 0 or x >= ProtoConfig.W or y >= ProtoConfig.H:
				ok_bounds = false
			if ProtoConfig.is_wall(x, y):
				ok_bounds = false
			if ProtoConfig.cell_at(x, y) == ".":
				ok_bounds = false
		check(ok_bounds, "semua station di sel valid (batas/tembok/huruf)")
		var dup := false
		var seen_cells := {}
		for s in ProtoConfig.STATIONS:
			var p: Array = s["pos"]
			var k := str(p[0]) + "," + str(p[1])
			if seen_cells.has(k):
				dup = true
			seen_cells[k] = true
		# abaikan var tak terpakai (cells dipakai di bawah)
		check(not dup and cells.size() == ProtoConfig.STATIONS.size(), "tak ada station menempati sel sama")
		# 2+3. tiap station punya tetangga bebas + minimal satu terjangkau BFS dari SPAWN
		# (tetangga sisi zona NPC tidak terhubung row-7, jadi cek semua tetangga)
		var spawn := Vector2i(ProtoConfig.SPAWN[0], ProtoConfig.SPAWN[1])
		var all_ok := true
		for s in ProtoConfig.STATIONS:
			var p: Array = s["pos"]
			var cands: Array = []
			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nb: Vector2i = Vector2i(int(p[0]), int(p[1])) + step
				if game.astar_blocked(nb.x, nb.y):
					continue
				var k2 := str(nb.x) + "," + str(nb.y)
				if cells.has(k2):
					continue
				cands.append(nb)
			if cands.is_empty():
				all_ok = false
				print("  tak ada tetangga bebas: ", s)
				continue
			var reach := false
			for c in cands:
				if _bfs_reachable(spawn, c):
					reach = true
					break
			if not reach:
				all_ok = false
				print("  tak terjangkau BFS: ", s)
		check(all_ok, "tiap station punya tetangga bebas & terjangkau dari SPAWN")
		# 4. jarak Manhattan (gagal di layout lama)
		var apar := _pos_of("apar")
		var best_stove := 999
		for st in game.stations:
			if st.station_type == "stove" and st.enabled:
				var gp := ProtoConfig.gpos(st.global_position)
				best_stove = mini(best_stove, absi(gp.x - int(apar[0])) + absi(gp.y - int(apar[1])))
		print("  jarak APAR->kompor aktif: ", best_stove)
		check(best_stove <= 2, "APAR <= 2 langkah dari kompor aktif")
		var trash := _pos_of("trash")
		var best_chop := 999
		for s in ProtoConfig.STATIONS:
			if str(s["kind"]) == "chop":
				best_chop = mini(best_chop, _manhattan(trash, s["pos"]))
		print("  jarak sampah->talenan: ", best_chop)
		check(best_chop <= 4, "sampah <= 4 langkah dari talenan")
		var sink := _pos_of("sink")
		var best_plates := 999
		for s in ProtoConfig.STATIONS:
			if str(s["kind"]) == "plates":
				best_plates = mini(best_plates, _manhattan(sink, s["pos"]))
		print("  jarak wastafel->rak piring: ", best_plates)
		check(best_plates <= 5, "wastafel <= 5 langkah dari rak piring")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

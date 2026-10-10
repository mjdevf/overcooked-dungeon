extends SceneTree
## T7-ukur: timing bot 1 order/resep (klaim->antar) + red-flag watch + bench A*.
## Murni pengukuran (selalu hijau kecuali order tak terkirim); hasil di-print.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var recipes := ["salad", "roti_lapis", "burger", "tumis"]
var ri := 0
var t_uid := 0
var claim_frame := -1
var spawn_frame := 0
var results := {}
var last_score := 0
var idle_streak := 0
var benched := false

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
	if frame > 15000:
		check(false, "timeout global 15000f")
		_report()
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing and not benched:
		benched = true
		_bench()
		game.orders.score = 500
		game.recruit_bot()
		while game.bots.size() > 1:
			var bb = game.bots.pop_back()
			bb.queue_free()
		last_score = game.orders.score
		_next_recipe()
	if phase == 1:
		_watch_redflags()
		var b = game.bots[0]
		# catat klaim
		if claim_frame < 0 and game.claims.has(t_uid):
			claim_frame = frame
		if game.orders.get_order(t_uid).is_empty():
			var secs: float = float(frame - spawn_frame) / 60.0
			var csecs: float = float(frame - claim_frame) / 60.0 if claim_frame >= 0 else -1.0
			results[recipes[ri]] = {"total": secs, "klaim_antar": csecs}
			print("  UKUR ", recipes[ri], " total=%.1fs klaim_antar=%.1fs" % [secs, csecs])
			check(secs < 120.0, "terkirim " + recipes[ri])
			ri += 1
			claim_frame = -1
			if ri >= recipes.size():
				_report()
				print("TEST DONE fails=", fails.size())
				if fails.is_empty():
					print("ALL PASS")
				quit(0 if fails.is_empty() else 1)
				return true
			_next_recipe()
	return false

func _next_recipe() -> void:
	var o: Dictionary = game.orders.spawn_recipe(recipes[ri], "T1")
	t_uid = int(o.get("uid", 0))
	spawn_frame = frame
	phase = 1

func _bench() -> void:
	# 7g: ukur cost pathfinding sebelum mutuskan cache grid
	var t0 := Time.get_ticks_msec()
	var acc := 0.0
	for i in range(200):
		var a := Vector3(-4.5 + float(i % 9), 0, -4.5 + float(i % 7))
		var b2 := Vector3(4.5 - float(i % 5), 0, 4.5 - float(i % 11))
		acc += (game.astar_path(a, b2) as Array).size()
	for i in range(5000):
		if game.astar_blocked(i % 12, (i / 12) % 12):
			acc += 1.0
	var ms := int(Time.get_ticks_msec()) - int(t0)
	print("  BENCH astar 200 path + 5000 blocked = ", ms, "ms (nodes=", acc, ")")
	check(ms < 50, "bench A* jauh di bawah 50ms (7g tak perlu)")

func _watch_redflags() -> void:
	if game.bots.is_empty():
		return
	var b = game.bots[0]
	if not is_instance_valid(b):
		return
	# job Ikut/Tunggu > 10 dtk padahal order aktif + bahan tersedia
	if (b._job == "Ikut" or b._job == "Tunggu") and not game.orders.active_orders.is_empty():
		idle_streak += 1
		if idle_streak == 601:
			print("  REDFLAG: job ", b._job, " >10 dtk, orders=", game.orders.active_orders.size())
	else:
		idle_streak = 0
	# entitas y ekstrem
	if frame % 60 == 0:
		if absf(b.global_position.y) > 8.0:
			print("  REDFLAG: bot y=", b.global_position.y)
		# skor turun tanpa sebab (bukan deliver-gagal/-expire: cek kasar selisih besar)
		if game.orders.score < last_score - 30:
			print("  REDFLAG: skor anjlok ", last_score, " -> ", game.orders.score)
		last_score = game.orders.score
		# talenan/kompor tak tersentuh: info isi stasiun tiap 30 dtk
		if frame % 1800 == 0:
			var info := []
			for st in game.stations:
				if st.stored and (st.station_type == "chop" or st.station_type == "stove"):
					info.append(st.station_type + ":" + st.stored.describe())
			if not info.is_empty():
				print("  INFO stasiun isi: ", info)

func _report() -> void:
	print("==== HASIL UKUR (1 bot, klaim->antar) ====")
	for r in recipes:
		if results.has(r):
			print("  ", r, ": total=", results[r]["total"], "s klaim_antar=", results[r]["klaim_antar"], "s")
		else:
			print("  ", r, ": TAK TERKIRIM")
	print("  acuan veteran: salad~14 roti~11 burger~15 tumis~24 (detik)")

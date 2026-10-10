extends SceneTree
## T6: NPC pintu lawan arah + rush tanpa macet + watchdog.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var last_pos := {}
var still_since := {}
var ever_stuck := false

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
	if frame > 16000:
		check(false, "timeout global 16000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		# (a) 2 NPC: satu masuk (spawn), satu keluar (spawn lalu paksa pulang)
		game.try_spawn_npc()
		game.try_spawn_npc()
		check(game.npcs.size() == 2, "setup: 2 NPC spawn")
		phase = 1
	if phase == 1 and frame < 3000:
		_track_still()
		# NPC kedua dipaksa pulang duluan (simulasi lawan arah di pintu)
		if frame == 60:
			var outs = game.npcs.duplicate()
			if outs.size() > 1 and is_instance_valid(outs[1]):
				outs[1].leave_calm()
		# hanguskan order yg muncul biar yg masuk juga pulang
		for o in game.orders.active_orders:
			o["time_left"] = minf(float(o.get("time_left", 99.0)), 0.05)
		if game.npcs.is_empty():
			print("  2 NPC selesai lawan arah at ", frame)
			check(not ever_stuck, "(a) lawan arah di pintu tanpa diam > 5 dtk")
			# (b) rush L3 tanpa pemain
			game.start_level(2)
			game.countdown = 0.01
			game.spawn_cd = 1e9
			ever_stuck = false
			last_pos.clear()
			still_since.clear()
			phase = 2
	if phase == 2 and frame < 15000:
		_track_still()
		# paksa spawn tiap 300f sampai F10000 (simulasi rush manual, kursi 4)
		if frame % 300 == 0 and game.playing and frame < 10000:
			game.try_spawn_npc()
		# hanguskan order yg muncul biar kursi berputar
		for o in game.orders.active_orders:
			o["time_left"] = minf(float(o.get("time_left", 99.0)), 5.0)
		if frame % 600 == 0:
			for n in game.npcs:
				if is_instance_valid(n):
					var mt = n.get("move_t")
					if mt != null and float(mt) > 20.0:
						check(false, "(b) ada NPC move_t > 20")
						phase = 9
		if frame > 13200:
			var seats_free := true
			for s in game.seats:
				if bool(s.get("taken", false)):
					seats_free = false
			check(game.orders.active_orders.is_empty(), "(b) order habis")
			check(game.npcs.is_empty(), "(b) semua NPC pulang")
			check(seats_free, "(b) semua kursi bebas")
			check(not ever_stuck, "(b) tak ada yg diam > 5 dtk di jalur")
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	return false

# pantau: NPC di state jalan yg pindah < 0.2m selama 5 dtk -> stuck
# State: 0 TO_QUEUE, 3 TO_SEAT, 6 PAY_LEAVE, 8 LEAVE_CALM
func _track_still() -> void:
	var walking := [0, 3, 6, 8]
	for n in game.npcs:
		if not is_instance_valid(n):
			continue
		var key := str(n.get_instance_id())
		var p: Vector3 = n.global_position
		if int(n.state) in walking:
			if last_pos.has(key):
				var d: float = Vector2(p.x - last_pos[key].x, p.z - last_pos[key].z).length()
				if d < 0.2:
					if not still_since.has(key):
						still_since[key] = frame
					if frame - int(still_since[key]) > 300 and not ever_stuck:
						ever_stuck = true
						print("  STUCK npc ", key, " at ", p)
				else:
					still_since.erase(key)
			last_pos[key] = p
		else:
			still_since.erase(key)
			last_pos[key] = p

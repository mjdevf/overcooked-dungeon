extends SceneTree
## T3: bawaan yatim dibuang + todeliver basi tak -10 + janitor bersih junk.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var t_uid := 0
var t_uid2 := 0
var mark := 0
var score_mark := 0

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

func _bot():
	return game.bots[0]

func _near(st) -> void:
	var b = _bot()
	b.global_position = st.global_position + Vector3(0, 0.6, 1.2)
	b.velocity = Vector3.ZERO
	b.apath.clear()

func _slip_food(ing: String, chopped: bool) -> FoodItem:
	var r: Dictionary = game.find_crate(ing).interact(null, false)
	var f: FoodItem = r.get("take")
	f.chopped = chopped
	if f.get_parent():
		f.get_parent().remove_child(f)
	return f

func _process(_delta: float) -> bool:
	frame += 1
	if frame == 5:
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
	if frame == 30 and game.playing:
		game.orders.score = 500
		game.recruit_bot()
		while game.bots.size() > 1:
			var bb = game.bots.pop_back()
			bb.queue_free()
		var o1: Dictionary = game.orders.spawn_recipe("salad", "T1")
		t_uid = int(o1.get("uid", 0))
		phase = 1
	# (a) tomat cincang di tangan, tanpa plan/order -> null ≤ 180f
	if phase == 1 and frame < 2000:
		var b = _bot()
		if not b.plan.is_empty() and b.carry == null:
			for o in game.orders.active_orders.duplicate():
				game.orders.active_orders.erase(o)
			game.release_uid(t_uid)
			var f := _slip_food("tomat", true)
			b.carry_anchor.add_child(f)
			b.carry = f
			b.task = ""
			_near(game.find_trash())
			mark = frame
			phase = 2
	if phase == 2:
		if _bot().carry == null:
			print("  (a) orphan dibuang at +", frame - mark)
			check(frame - mark <= 180, "(a) bawaan yatim dibuang ≤ 3 dtk")
			_setup_b()
	if phase == 2 and frame - mark > 600:
		check(false, "(a) bawaan yatim dibuang ≤ 3 dtk (timeout)")
		_setup_b()
	# (b) piring salad + todeliver + order hangus (roti aktif) -> tak -10, null ≤ 900f
	if phase == 3:
		if _bot().carry == null:
			print("  (b) stale plate dibuang at +", frame - mark)
			check(game.orders.score >= score_mark, "(b) skor tak turun (tak ada -10)")
			check(frame - mark <= 900, "(b) piring basi dibuang ≤ 15 dtk")
			_setup_c()
	if phase == 3 and frame - mark > 1200:
		check(false, "(b) piring basi dibuang (timeout)")
		check(game.orders.score >= score_mark, "(b) skor tak turun")
		_setup_c()
	# (c) kompor gosong tanpa api/order -> hilang ≤ 900f, tak ada api kedua
	if phase == 4:
		if _stove_burnt_gone():
			print("  (c) gosong dibersihkan at +", frame - mark)
			check(frame - mark <= 900, "(c) kompor gosong dibersihkan ≤ 15 dtk")
			check(not _any_fire(), "(c) tak ada kebakaran kedua")
			_setup_d()
	if phase == 4 and frame - mark > 1200:
		check(false, "(c) kompor gosong dibersihkan (timeout)")
		_setup_d()
	# (d) piring orphan [roti,tomat] -> bersih + restock ≤ 1200f
	if phase == 5:
		if _orphan_roti_gone():
			print("  (d) orphan plate dibersihkan at +", frame - mark)
			check(frame - mark <= 1200, "(d) piring orphan dibersihkan ≤ 20 dtk")
			check(_plating_restocked(), "(d) plating restock piring kosong")
			_setup_e()
	if phase == 5 and frame - mark > 1500:
		check(false, "(d) piring orphan dibersihkan (timeout)")
		_setup_e()
	# (e) parsial valid + order aktif -> predikat janitor false, isi utuh
	if phase == 6 and frame - mark > 300:
		check(_partial_intact(), "(e) parsial valid pemain tak disentuh janitor")
		print("TEST DONE fails=", fails.size())
		if fails.is_empty():
			print("ALL PASS")
		quit(0 if fails.is_empty() else 1)
		return true
	return false

func _setup_b() -> void:
	var o2: Dictionary = game.orders.spawn_recipe("salad", "T1")
	t_uid = int(o2.get("uid", 0))
	var o3: Dictionary = game.orders.spawn_recipe("roti_lapis", "T2")
	t_uid2 = int(o3.get("uid", 0))
	var p := FoodItem.make_plate()
	game.level_root.add_child(p)
	p.plate_contents = [{"item": "tomat", "chopped": true, "cooked": false}, {"item": "selada", "chopped": true, "cooked": false}]
	var b = _bot()
	b._attach(p)
	b.task = "todeliver"
	for o in game.orders.active_orders.duplicate():
		if int(o.get("uid", 0)) == t_uid:
			game.orders.active_orders.erase(o)
	game.release_uid(t_uid)
	score_mark = game.orders.score
	_near(game.find_trash())
	mark = frame
	phase = 3

func _setup_c() -> void:
	for o in game.orders.active_orders.duplicate():
		game.orders.active_orders.erase(o)
	game.release_uid(t_uid2)
	var st = null
	for s in game.stations:
		if s.station_type == "stove" and s.enabled:
			st = s
			break
	var f2 := _slip_food("tomat", true)
	f2.burnt = true
	st.force_store(f2)
	_near(st)
	mark = frame
	phase = 4

func _stove_burnt_gone() -> bool:
	for s in game.stations:
		if s.station_type == "stove" and s.stored and not s.stored.is_plate and s.stored.burnt:
			return false
	return true

func _any_fire() -> bool:
	for s in game.stations:
		if s.station_type == "stove" and s.fire:
			return true
	return false

func _setup_d() -> void:
	var pl = null
	for s in game.stations:
		if s.station_type == "plating" and s.stored and s.stored.is_plate and s.stored.plate_contents.is_empty():
			pl = s
			break
	var p2 := FoodItem.make_plate()
	game.level_root.add_child(p2)
	p2.plate_contents = [{"item": "roti", "chopped": false, "cooked": false}, {"item": "tomat", "chopped": true, "cooked": false}]
	pl.force_store(p2)
	_near(pl)
	mark = frame
	phase = 5

func _orphan_roti_gone() -> bool:
	for s in game.stations:
		if s.station_type == "plating" and s.stored and s.stored.is_plate:
			for c in s.stored.plate_contents:
				if str(c.get("item", "")) == "roti":
					return false
	return true

func _plating_restocked() -> bool:
	for s in game.stations:
		if s.station_type == "plating" and s.stored and s.stored.is_plate and s.stored.plate_contents.is_empty():
			return true
	return false

func _setup_e() -> void:
	var o4: Dictionary = game.orders.spawn_recipe("salad", "T1")
	t_uid = int(o4.get("uid", 0))
	var pl2 = null
	for s in game.stations:
		if s.station_type == "plating" and s.stored and s.stored.is_plate and s.stored.plate_contents.is_empty():
			pl2 = s
			break
	var f3 := _slip_food("tomat", true)
	var mres: Dictionary = pl2.interact(f3, false)
	if bool(mres.get("place_consumed", false)):
		f3.queue_free()
	# catat stasiun parsial untuk predikat janitor
	for s in game.stations:
		if s.station_type == "plating" and s.stored and s.stored.is_plate and not s.stored.plate_contents.is_empty():
			_e_station = s
			break
	mark = frame
	phase = 6

var _e_station = null

func _partial_intact() -> bool:
	if _e_station == null or not is_instance_valid(_e_station):
		return false
	if _e_station.stored == null or not is_instance_valid(_e_station.stored):
		return false
	# predikat janitor harus false (terlindungi)
	if game._is_junk(_e_station):
		return false
	if game.plate_orphan(_e_station.stored):
		return false
	var has_tomat := false
	for c in _e_station.stored.plate_contents:
		if str(c.get("item", "")) == "tomat":
			has_tomat = true
	return has_tomat

extends SceneTree
## TU1: HUD gameplay ala mockup (topbar, kartu order, panel bot, banner api, aksi).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var mark := 0
var t_uid := 0
var stove = null
var neglect_once := false
var fire_mark := -1

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

func _hud():
	return game.hud

# anak terakhir yg tak queued-for-deletion (rebuild queue_free yg lama)
func _fresh(box: Node):
	var kids := box.get_children()
	for i in range(kids.size() - 1, -1, -1):
		if not kids[i].is_queued_for_deletion():
			return kids[i]
	return null

func _rebuild_cards() -> void:
	game.hud._last_card_ms = 0
	game.orders.emit_signal("orders_changed")

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
		var h = _hud()
		check("LEVEL 1" in h.level_label.text, "topbar label level")
		check(h.score_label.text == "0", "skor awal 0")
		check(h.star_labels.size() == 3 and h.star_labels[0].text == "☆", "3 bintang kosong")
		check(h.thr_labels[2].text == "900", "ambang bintang L1")
		check(h.time_label.text == "3:00" or h.time_label.text.begins_with("2:5"), "timer jalan")
		var o1: Dictionary = game.orders.spawn_recipe("salad", "T1")
		t_uid = int(o1.get("uid", 0))
		mark = frame
		phase = 1
	if phase == 1 and frame - mark > 30:
		var h = _hud()
		_rebuild_cards()
		var card = _fresh(h.orders_box)
		check(card != null, "kartu order ada")
		if card == null:
			return false
		var txt := _texts(card)
		check("Salad Dungeon" in txt and "T1" in txt, "kartu nama + meja")
		check("Belum diambil bot" in txt, "badge belum diklaim")
		check("cincang" in txt, "chip bahan + tag")
		check("kursi" in h.seats_label.text, "header kursi")
		game.orders.score = 500
		game.recruit_bot()
		mark = frame
		phase = 2
	if phase == 2 and frame - mark > 40:
		var h = _hud()
		var b = game.bots[0]
		if not is_instance_valid(b) or b.plan.is_empty():
			if frame - mark > 900:
				check(false, "bot bikin plan (timeout)")
				mark = frame
				phase = 9
			return false
		_rebuild_cards()
		h._last_bot_ms = 0
		game.hud.set_bots(game.bots.size())
		var card2 = _fresh(h.orders_box)
		var txt2 := _texts(card2)
		check("Bot 1" in txt2, "badge klaim Bot 1")
		var row = _fresh(h.bot_rows)
		check(row != null, "1 baris bot")
		if row != null:
			var brow := _texts(row)
			check("Bot 1" in brow and "Masak" in brow, "baris bot + pil Masak")
		check("150" in h.recruit_btn.text, "tombol rekrut harga bot ke-2")
		var crate = game.find_crate("tomat")
		var pp: Vector3 = crate.global_position + Vector3(0, 0.6, 1.3)
		game.player.global_position = pp
		var d: Vector3 = crate.global_position - pp
		d.y = 0.0
		game.player.face_dir = d.normalized()
		mark = frame
		phase = 3
	if phase == 3 and frame - mark > 20:
		var h = _hud()
		if "Ambil" not in h.action_btn.text:
			if frame - mark > 300:
				check(false, "prompt Ambil muncul")
				mark = frame
				phase = 9
			return false
		check("[E]" in h.action_btn.text, "tombol aksi + kunci")
		h.action_btn.emit_signal("pressed")
		check(game.player.carry != null, "klik tombol aksi = interact")
		mark = frame
		phase = 31
	if phase == 31 and frame - mark > 10:
		var cd := "none"
		if game.player.carry:
			cd = game.player.carry.describe()
		check("tomat" in cd.to_lower() or "selada" in cd.to_lower(), "klik ambil bahan")
		check("tomat" in _hud().carry_label.text.to_lower() or "selada" in _hud().carry_label.text.to_lower(), "panel tangan isi")
		for st in game.stations:
			if st.station_type == "stove" and st.enabled:
				stove = st
				break
		game.player.clear_carry_free()
		var r: Dictionary = game.find_crate("tomat").interact(null, false)
		var f: FoodItem = r.get("take")
		f.chopped = true
		var ir: Dictionary = stove.interact(f, false)
		check(str(ir.get("msg", "")).find("Memasak") >= 0, "kompor mulai masak")
		mark = frame
		phase = 4
	if phase == 4 and frame < 5500:
		if stove.stored and stove.stored.cooked and not stove.stored.burnt:
			stove.burn_timer = 99.0
		if stove.stored and stove.stored.burnt and not stove.fire and not neglect_once:
			neglect_once = true
			stove.neglect_t = 5.9
		# tunggu banner update (game._process jalan setelah ignite) baru assert
		if stove.fire and fire_mark < 0:
			fire_mark = frame
		if stove.fire and fire_mark >= 0 and frame - fire_mark > 15:
			var h = _hud()
			check(h.fire_banner.visible, "banner api muncul")
			check("Kompor" in h.fire_title.text, "banner sebut kompor")
			stove.extinguish()
			if stove.stored:
				var g = stove.take_stored()
				if g:
					g.queue_free()
			h.pause_btn.emit_signal("pressed")
			check(game.paused, "pause via tombol")
			h.pause_btn.emit_signal("pressed")
			check(not game.paused, "lanjut via tombol")
			print("TEST DONE fails=", fails.size())
			if fails.is_empty():
				print("ALL PASS")
			quit(0 if fails.is_empty() else 1)
			return true
	if phase == 9:
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	return false

func _texts(n: Node) -> String:
	var out := ""
	if n == null:
		return out
	if n is Label:
		out += " " + (n as Label).text
	if n is Button:
		out += " " + (n as Button).text
	for c in n.get_children():
		out += _texts(c)
	return out

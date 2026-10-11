extends SceneTree
## TM1: menu utama (kartu level, lock, lanjut, bantuan, pengaturan).

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var saved_best: Array = []

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
	# snapshot best agar cfg dev tak tercemar
	for i in range(3):
		saved_best.append(game.load_best(i))

func _restore() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://overcooked_dungeon.cfg")
	for i in range(3):
		cfg.set_value("best", "best_score_%d" % i, int(saved_best[i][0]))
		cfg.set_value("best", "best_stars_%d" % i, int(saved_best[i][1]))
	cfg.save("user://overcooked_dungeon.cfg")

func _finish(ok: bool) -> bool:
	_restore()
	print("TEST DONE fails=", fails.size())
	if fails.is_empty():
		print("ALL PASS")
	quit(0 if fails.is_empty() and ok else 1)
	return true

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 3000:
		check(false, "timeout global 3000f")
		return _finish(false)
	if frame == 5:
		# logika murni (tanpa cfg)
		check(GameMain.unlocked_for(0, 0), "L1 selalu terbuka")
		check(not GameMain.unlocked_for(0, 2), "L3 terkunci tanpa bintang L2")
		check(GameMain.unlocked_for(1, 2), "L3 terbuka dgn 1 bintang L2")
		check(GameMain.continue_for([[0, 0], [0, 0], [0, 0]]) == 0, "lanjut L1 saat fresh")
		check(GameMain.continue_for([[812, 3], [560, 2], [0, 0]]) == 1, "lanjut L2 ala mockup")
		check(GameMain.continue_for([[1, 3], [1, 3], [1, 3]]) == 2, "lanjut level terakhir bila semua selesai")
		# seed: L1 selesai 3 bintang -> L2 terbuka, L3 terkunci
		var cfg := ConfigFile.new()
		cfg.load("user://overcooked_dungeon.cfg")
		cfg.set_value("best", "best_score_0", 812)
		cfg.set_value("best", "best_stars_0", 3)
		cfg.set_value("best", "best_score_1", 0)
		cfg.set_value("best", "best_stars_1", 0)
		cfg.set_value("best", "best_score_2", 0)
		cfg.set_value("best", "best_stars_2", 0)
		cfg.save("user://overcooked_dungeon.cfg")
		game.hud.refresh_menu_best()
		phase = 1
	if phase == 1 and frame > 40:
		var h = game.hud
		check(h.level_cards.get_child_count() == 3, "3 kartu level")
		check("Lanjut Level 2" in h.continue_btn.text, "tombol lanjut level 2")
		var c0 := _texts(h.level_cards.get_child(0))
		var c2 := _texts(h.level_cards.get_child(2))
		check("Main lagi" in c0 and "Terbaik 812" in c0, "kartu L1 main lagi + rekor")
		check("Terkunci" in c2 and "Level 2" in c2, "kartu L3 terkunci + syarat")
		check("Ruang Rame" in _texts(h.level_cards.get_child(1)), "kartu L2 ada")
		# klik L3 terkunci -> tetap di menu
		_click_status(h.level_cards.get_child(2))
		check(game.in_menu and not game.playing, "klik level terkunci ditolak")
		# klik Lanjut -> main level 2 (countdown)
		h.continue_btn.emit_signal("pressed")
		phase = 2
	if phase == 2 and frame < 1000:
		if game.playing or game.countdown > 0.0:
			check(game.level_idx == 1, "lanjut mulai level 2")
			game.to_menu()
			phase = 3
	if phase == 3 and frame < 2000:
		if game.in_menu and not game.playing:
			var h = game.hud
			h.toggle_help()
			check(h.help_overlay.visible, "bantuan dibuka")
			h.toggle_help()
			check(not h.help_overlay.visible, "bantuan ditutup")
			var m0: bool = AudioServer.is_bus_mute(0)
			h._apply_mute(not m0)
			check(AudioServer.is_bus_mute(0) == (not m0), "mute toggle tersimpan")
			h._apply_mute(m0)
			return _finish(true)
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

func _click_status(card: Node) -> void:
	for c in card.get_children():
		if c is VBoxContainer:
			for b in c.get_children():
				if b is Button and not (b as Button).disabled:
					(b as Button).emit_signal("pressed")
					return
		if c is Button and not (c as Button).disabled:
			(c as Button).emit_signal("pressed")
			return

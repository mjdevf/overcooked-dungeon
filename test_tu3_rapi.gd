extends SceneTree
## TU3: rapikan UI — menu (backdrop, rata kiri, kontras, kartu) + margin HUD.
## Merah di UI sebelum commit rapikan: label dunia tembus, judul tengah, teks lavender, badge bocor.

var game = null
var frame := 0
var fails: Array = []
var phase := 0
var wait := 0

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

func _all(n: Node, out: Array) -> Array:
	out.append(n)
	for c in n.get_children():
		if not c.is_queued_for_deletion():
			_all(c, out)
	return out

func _lum(c: Color) -> float:
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)

func _contrast(a: Color, b: Color) -> float:
	var l1 := _lum(a)
	var l2 := _lum(b)
	var hi := maxf(l1, l2)
	var lo := minf(l1, l2)
	return (hi + 0.05) / (lo + 0.05)

func _label_color(l: Label) -> Color:
	if l.has_theme_color_override("font_color"):
		return l.get_theme_color("font_color")
	return l.get_theme_color("font_color", "Label")

func _label3d_visible() -> int:
	var n := 0
	for s in game.stations:
		if is_instance_valid(s) and s.label3d and s.label3d.visible:
			n += 1
	for b in game.bots:
		if is_instance_valid(b) and b.job_label and b.job_label.visible:
			n += 1
	for c in game.npcs:
		if is_instance_valid(c) and c.bubble and c.bubble.visible:
			n += 1
	return n

func _process(_delta: float) -> bool:
	frame += 1
	if frame > 3000:
		check(false, "timeout global 3000f")
		print("TEST DONE fails=", fails.size())
		quit(1)
		return true
	if frame == 20:
		_check_menu()
		game.start_level(0)
		game.countdown = 0.01
		game.spawn_cd = 1e9
		phase = 1
		wait = frame
	if phase == 1 and frame - wait > 40 and game.playing:
		root.size = Vector2i(1280, 720)
		phase = 2
		wait = frame
	if phase == 2 and frame - wait > 10:
		_check_hud(Vector2(1280, 720))
		root.size = Vector2i(1275, 743)
		phase = 3
		wait = frame
	if phase == 3 and frame - wait > 10:
		_check_hud(Vector2(1275, 743))
		print("TEST DONE fails=", fails.size())
		quit(1 if fails.size() > 0 else 0)
		return true
	return false

func _check_menu() -> void:
	var h = game.hud
	check(h.menu_backdrop != null and h.menu_backdrop.visible == h.menu_panel.visible and h.menu_panel.visible, "backdrop menu tampil bersama panel")
	check(_label3d_visible() == 0, "tidak ada label dunia terlihat di menu")
	check(h.menu_title1.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and h.menu_title2.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "judul menu rata kiri")
	var nodes: Array = _all(h.menu_panel, [])
	# pill tag selebar teks (bukan melebar penuh kolom kiri)
	var tagrow = h.menu_panel.find_child("TagRow", true, false)
	var pill_w := 0.0
	if tagrow and tagrow.get_child_count() > 0:
		pill_w = (tagrow.get_child(0) as Control).size.x
	check(pill_w > 0.0 and pill_w < 0.8 * 400.0, "pill tag selebar teks (%.0f)" % pill_w)
	# kontras teks sekunder vs panel pasir
	var bg: Color = HUD.CREAM_DIM
	var need := ["Layani pelanggan", "WASD gerak", "Tersimpan otomatis", "PILIH LEVEL"]
	for n in nodes:
		if n is Label:
			var t: String = (n as Label).text
			for k in need:
				if t.begins_with(k):
					var cc := _contrast(_label_color(n as Label), bg)
					check(cc >= 4.5, "kontras '%s' >= 4.5 (%.1f)" % [k, cc])
	check(_contrast(_label_color(h.menu_title2), bg) >= 4.5, "kontras judul Dungeon")
	# kartu level: badge 48x48, tanpa awalan "L1 - ", satu tombol utama
	var re := RegEx.new()
	re.compile("^L\\d - ")
	var badges := 0
	var primaries := 0
	var prefixed := 0
	for n in nodes:
		if n is PanelContainer and n.name == "Badge":
			badges += 1
			var sz: Vector2 = (n as Control).custom_minimum_size
			check(sz == Vector2(48, 48) and (n as Control).size.y <= 60.0, "badge level kotak 48x48")
		if n is Button and (n as Button).theme_type_variation == "PrimaryButton" and h.level_cards.is_ancestor_of(n):
			primaries += 1
		if n is Label and re.search((n as Label).text) != null:
			prefixed += 1
	check(badges == 3, "3 badge level")
	check(primaries == 1, "tepat satu tombol utama di kartu level (%d)" % primaries)
	check(prefixed == 0, "tidak ada awalan 'L1 - ' di menu")

func _check_hud(vp: Vector2) -> void:
	var h = game.hud
	var tag := str(vp)
	var m := float(HUD.MARGIN)
	check(absf(h.pause_btn.get_global_rect().position.x - m) <= 1.0, "pause x = MARGIN " + tag)
	check(absf(h.pause_btn.get_global_rect().position.y - m) <= 1.0, "pause y = MARGIN " + tag)
	var rr: Rect2 = h.recruit_btn.get_global_rect()
	check(absf(vp.x - rr.end.x - m) <= 1.0, "tombol rekrut: margin kanan = MARGIN " + tag)
	check(absf(rr.position.y - m) <= 1.0, "tombol rekrut sejajar atas pause " + tag)
	check(absf(h.orders_rail.get_global_rect().position.x - m) <= 1.0, "rel pesanan margin kiri = MARGIN " + tag)
	var re := RegEx.new()
	re.compile("L\\d - ")
	check(re.search(h.level_label.text) == null, "judul level tanpa awalan 'L2 - ' " + tag)
	for i in range(3):
		var sx: float = (h.star_labels[i] as Label).position.x + 8.0
		check(sx >= 0.0 and sx <= HUD.STAR_W, "bintang %d di dalam bar %s" % [i, tag])
	var hp = h.orders_rail.get_node("HeadPill")
	check((hp as Control).size.x < 0.6 * 252.0, "pill PESANAN selebar teks " + tag)

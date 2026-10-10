class_name HUD
extends CanvasLayer
## UI modern: menu + best score, chips skor/waktu/bot, kartu order, pause, countdown besar.

const ACCENT := Color(1.0, 0.75, 0.30)
const PANEL := Color(0.10, 0.09, 0.155, 0.94)

var game = null
var menu_panel: PanelContainer
var menu_best_labels: Array = []
var hud_root: Control
var orders_box: VBoxContainer
var info_label: Label
var msg_label: Label
var msg_tween_t := 0.0
var prompt_panel: PanelContainer
var prompt_key: Label
var prompt_text: Label
var prompt_key_txt := "[E]"
var count_label: Label
var chip_score: Label
var chip_time: Label
var chip_bot: Label
var over_panel: PanelContainer
var over_title: Label
var over_detail: Label
var over_rekor: Label
var pause_panel: PanelContainer
var _last_card_ms := 0

func setup(g) -> void:
	game = g
	_build_menu()
	_build_hud()
	_build_over()
	_build_pause()
	show_menu()

func _style(bg: Color, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	s.border_width_bottom = 3
	s.border_color = Color(1.0, 0.75, 0.30, 0.35)
	return s

func _chip_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.10, 0.09, 0.155, 0.88)
	s.corner_radius_top_left = 10
	s.corner_radius_top_right = 10
	s.corner_radius_bottom_left = 10
	s.corner_radius_bottom_right = 10
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	s.border_width_bottom = 2
	s.border_color = Color(1.0, 0.75, 0.30, 0.5)
	return s

func _title_label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _btn(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 20)
	return b

# ---------- menu ----------

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _style(PANEL, 18))
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-230, -260)
	menu_panel.custom_minimum_size = Vector2(460, 520)
	add_child(menu_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	menu_panel.add_child(v)
	var title := _title_label("OVERCOOKED DUNGEON", 36)
	v.add_child(title)
	var sub := _title_label("Gudang - Dapur - Pesanan: layani NPC sebelum kabur!", 15)
	sub.add_theme_color_override("font_color", ACCENT)
	v.add_child(sub)
	v.add_child(_title_label("Pilih Level:", 20))
	for i in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(row)
		var b := _btn(LevelData.LEVELS[i]["name"])
		b.custom_minimum_size = Vector2(280, 44)
		var idx := i
		b.pressed.connect(func() -> void: game.start_level(idx))
		row.add_child(b)
		var best := _title_label("", 14)
		best.custom_minimum_size = Vector2(120, 44)
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		best.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		best.add_theme_color_override("font_color", ACCENT)
		row.add_child(best)
		menu_best_labels.append(best)
	var help := _title_label("Keyboard: WASD gerak, Shift dash, E/Spasi ambil/taruh (tahan: cincang/cuci), Q rekrut bot auto, Esc pause | Gamepad: stick/D-pad gerak, A ambil/taruh (tahan: cincang), B dash, Y bot, Start pause", 13)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(420, 56)
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	v.add_child(help)
	refresh_menu_best()

func refresh_menu_best() -> void:
	for i in range(menu_best_labels.size()):
		var b: Array = game.load_best(i)
		var txt := "-"
		if int(b[0]) > 0:
			txt = "%d (" % int(b[0])
			for s in range(int(b[1])):
				txt += "*"
			txt += ")"
		(menu_best_labels[i] as Label).text = txt

# ---------- HUD main ----------

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	add_child(hud_root)
	# chips atas-tengah: skor | waktu | bot
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.position = Vector2(-330, 8)
	top.custom_minimum_size = Vector2(660, 40)
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(top)
	chip_score = _make_chip(top, "Skor: 0")
	chip_time = _make_chip(top, "03:00")
	chip_bot = _make_chip(top, "Bot: 0")
	# panel order kiri
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _style(PANEL))
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(10, 60)
	left.custom_minimum_size = Vector2(360, 120)
	hud_root.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	left.add_child(lv)
	var oh := _title_label("ORDERS", 18)
	oh.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	oh.add_theme_color_override("font_color", ACCENT)
	lv.add_child(oh)
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	lv.add_child(orders_box)
	info_label = _title_label("", 15)
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lv.add_child(info_label)
	msg_label = _title_label("", 22)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-300, 56)
	msg_label.custom_minimum_size = Vector2(600, 40)
	hud_root.add_child(msg_label)
	count_label = _title_label("", 96)
	count_label.set_anchors_preset(Control.PRESET_CENTER)
	count_label.position = Vector2(-200, -120)
	count_label.custom_minimum_size = Vector2(400, 200)
	count_label.add_theme_color_override("font_color", ACCENT)
	hud_root.add_child(count_label)
	# prompt kontekstual bawah-tengah: [E] + aksi
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", _chip_style())
	prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_panel.position = Vector2(-260, -76)
	prompt_panel.custom_minimum_size = Vector2(520, 52)
	prompt_panel.visible = false
	hud_root.add_child(prompt_panel)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	prow.add_theme_constant_override("separation", 10)
	prompt_panel.add_child(prow)
	prompt_key = _title_label("[E]", 24)
	prompt_key.add_theme_color_override("font_color", ACCENT)
	prow.add_child(prompt_key)
	prompt_text = _title_label("", 20)
	prompt_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	prow.add_child(prompt_text)

func _make_chip(parent: Control, t: String) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _chip_style())
	parent.add_child(p)
	var l := _title_label(t, 22)
	p.add_child(l)
	return l

# ---------- game over & pause ----------

func _build_over() -> void:
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", _style(PANEL, 18))
	over_panel.set_anchors_preset(Control.PRESET_CENTER)
	over_panel.position = Vector2(-210, -190)
	over_panel.custom_minimum_size = Vector2(420, 380)
	over_panel.visible = false
	add_child(over_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	over_panel.add_child(v)
	over_title = _title_label("WAKTU HABIS!", 34)
	v.add_child(over_title)
	over_rekor = _title_label("", 22)
	over_rekor.add_theme_color_override("font_color", ACCENT)
	v.add_child(over_rekor)
	over_detail = _title_label("", 20)
	v.add_child(over_detail)
	var again := _btn("Main Lagi")
	again.pressed.connect(func() -> void: game.restart_level())
	v.add_child(again)
	var tomenu := _btn("Menu Utama")
	tomenu.pressed.connect(func() -> void: game.to_menu())
	v.add_child(tomenu)

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _style(PANEL, 18))
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-170, -130)
	pause_panel.custom_minimum_size = Vector2(340, 260)
	pause_panel.visible = false
	add_child(pause_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pause_panel.add_child(v)
	var t := _title_label("PAUSE", 34)
	t.add_theme_color_override("font_color", ACCENT)
	v.add_child(t)
	var resume := _btn("Lanjut (Esc)")
	resume.pressed.connect(func() -> void: game.toggle_pause())
	v.add_child(resume)
	var tomenu := _btn("Menu Utama")
	tomenu.pressed.connect(func() -> void: game.to_menu())
	v.add_child(tomenu)

# ---------- tampil/sembunyi ----------

func show_menu() -> void:
	refresh_menu_best()
	menu_panel.visible = true
	hud_root.visible = false
	over_panel.visible = false
	pause_panel.visible = false
	count_label.text = ""
	set_prompt("")

func show_hud() -> void:
	menu_panel.visible = false
	hud_root.visible = true
	over_panel.visible = false
	pause_panel.visible = false
	count_label.text = ""
	set_prompt("")

func show_pause(on: bool) -> void:
	pause_panel.visible = on

func set_countdown(t: String) -> void:
	count_label.text = t

func show_over(score: int, stars: int, lv_name: String, rekor: bool) -> void:
	hud_root.visible = false
	pause_panel.visible = false
	over_panel.visible = true
	over_title.text = "WAKTU HABIS!"
	var st := ""
	for i in range(stars):
		st += "* "
	if st == "":
		st = "-"
	over_rekor.text = "REKOR BARU!" if rekor else ""
	over_detail.text = "%s\nSkor: %d\nBintang: %s" % [lv_name, score, st]

# ---------- update ----------

func set_score(s: int) -> void:
	chip_score.text = "Skor: %d" % s

func set_time(t: float) -> void:
	var m := int(t) / 60
	var sec := int(t) % 60
	chip_time.text = "%02d:%02d" % [m, sec]
	if t < 30.0:
		chip_time.add_theme_color_override("font_color", Color(1, 0.4, 0.35))
	else:
		chip_time.add_theme_color_override("font_color", Color(1, 1, 1))

func set_bots(n: int) -> void:
	chip_bot.text = "Bot: %d" % n

func set_info(t: String) -> void:
	info_label.text = t

func set_prompt(action: String) -> void:
	if action == "":
		prompt_panel.visible = false
		return
	prompt_panel.visible = true
	prompt_key.text = prompt_key_txt
	prompt_text.text = action

func set_prompt_key(key: String) -> void:
	prompt_key_txt = key
	prompt_key.text = key

func flash(msg: String) -> void:
	msg_label.text = msg
	msg_tween_t = 2.0

func _process(delta: float) -> void:
	if msg_tween_t > 0.0:
		msg_tween_t -= delta
		if msg_tween_t <= 0.0:
			msg_label.text = ""

func refresh_orders(orders: Array) -> void:
	# order_changed di-emit tiap frame; rebuild kartu max 5x/detik biar hemat
	var now := Time.get_ticks_msec()
	if now - _last_card_ms < 200 and not orders.is_empty():
		return
	_last_card_ms = now
	for c in orders_box.get_children():
		c.queue_free()
	if orders.is_empty():
		var l := _title_label("(belum ada order)", 15)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		orders_box.add_child(l)
		return
	for o in orders:
		orders_box.add_child(_order_card(o))

func _order_card(o: Dictionary) -> PanelContainer:
	var r: Dictionary = o["recipe"]
	var needs: Array = r.get("needs", [])
	var tleft := float(o.get("time_left", 0.0))
	var tmax := float(o.get("time_max", 90.0))
	var urgent: bool = tleft < 20.0
	var has_npc: bool = o.has("npc")
	var card := PanelContainer.new()
	var bg := Color(0.16, 0.15, 0.22, 0.95) if not urgent else Color(0.35, 0.14, 0.13, 0.95)
	card.add_theme_stylebox_override("panel", _style(bg))
	card.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head_txt := "Meja %s: %s (+%d)" % [str(o.get("table_id", "?")), str(r.get("label", "?")), int(r.get("reward", 100))]
	if game.order_assignee(int(o.get("uid", 0))) != "":
		head_txt = "Bot → " + head_txt
	elif has_npc:
		head_txt = "NPC " + head_txt
	var head := _title_label(head_txt, 17)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if urgent:
		head.add_theme_color_override("font_color", Color(1, 0.45, 0.4))
	elif has_npc:
		head.add_theme_color_override("font_color", ACCENT)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for n in needs:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.color = LevelData.INGREDIENTS.get(str(n.get("item", "")), {}).get("color", Color.WHITE)
		row.add_child(dot)
		var lbl := _title_label(_need_label(n), 14)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(lbl)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0 * tleft / maxf(tmax, 0.01)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(290, 10)
	v.add_child(bar)
	var t := _title_label("%ds" % int(tleft), 12)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	t.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	v.add_child(t)
	return card

func _ing_label(ing: String) -> String:
	var rule: Dictionary = LevelData.INGREDIENTS.get(ing, {})
	var s: String = str(rule.get("label", ing))
	var tags: Array = []
	if bool(rule.get("need_chop", false)):
		tags.append("cincang")
	if bool(rule.get("need_cook", false)):
		tags.append("masak")
	if not tags.is_empty():
		s += " (" + ", ".join(PackedStringArray(tags)) + ")"
	return s

func _need_label(need: Dictionary) -> String:
	var rule: Dictionary = LevelData.INGREDIENTS.get(str(need.get("item", "")), {})
	var s: String = str(rule.get("label", need.get("item", "?")))
	var tags: Array = []
	if bool(need.get("chop", false)):
		tags.append("cincang")
	if bool(need.get("cook", false)):
		tags.append("matang")
	if not tags.is_empty():
		s += " (" + ", ".join(PackedStringArray(tags)) + ")"
	return s

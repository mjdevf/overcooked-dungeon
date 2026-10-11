class_name HUD
extends CanvasLayer
## UI modern: menu + best score, chips skor/waktu/bot, kartu order, pause, countdown besar.

const ACCENT := Color(1.0, 0.75, 0.30)
const PANEL := Color(0.23, 0.14, 0.09, 0.92)
const CREAM := Color(1.0, 0.965, 0.89)
const CREAM_DIM := Color(0.96, 0.91, 0.80)
const INK := Color(0.30, 0.20, 0.13)
const INK_SOFT := Color(0.45, 0.35, 0.27)
const LEAF := Color(0.20, 0.55, 0.25)
const BLOOD := Color(0.72, 0.18, 0.13)
const GOLD := Color(0.85, 0.60, 0.10)
const FOCUS_BLUE := Color(0.18, 0.44, 0.88)
var font_title: Font = null
var font_body: Font = null
var ui_theme: Theme = null
var _recruit_key := "[Q]"

var game = null
var menu_panel: PanelContainer
var level_cards: VBoxContainer
var continue_btn: Button
var help_overlay: PanelContainer
var settings_overlay: PanelContainer
var mute_btn: Button
var muted := false
var hud_root: Control
var score_panel: PanelContainer
var orders_rail: VBoxContainer
var bot_side: VBoxContainer
var bottom_bar: HBoxContainer
var orders_box: VBoxContainer
var info_label: Label
var msg_label: Label
var msg_tween_t := 0.0
var pause_btn: Button
var level_label: Label
var time_label: Label
var score_label: Label
var star_labels: Array = []
var star_bar: ProgressBar
var thr_labels: Array = []
var _thr: Array = [300, 550, 800]
var seats_label: Label
var bot_rows: VBoxContainer
var recruit_btn: Button
var _last_bot_ms := 0
var _last_bot_sig := ""
var fire_banner: PanelContainer
var fire_title: Label
var fire_sub: Label
var carry_label: Label
var action_btn: Button
var prompt_key_txt := "[E]"
var _last_prompt := ""
var count_label: Label
var chip_score: Label
var chip_time: Label
var chip_bot: Label
var over_panel: PanelContainer
var over_title: Label
var over_detail: Label
var over_rekor: Label
var over_rows: VBoxContainer
var pause_panel: PanelContainer
var _last_card_ms := 0

func setup(g) -> void:
	game = g
	_load_fonts()
	_make_theme()
	_build_menu()
	_build_hud()
	_build_over()
	_build_pause()
	show_menu()

# Font judul (Fredoka) + teks (Nunito), OFL. Jatuh ke default bila gagal impor.
func _load_fonts() -> void:
	if ResourceLoader.exists("res://fonts/Fredoka-SemiBold.ttf"):
		font_title = load("res://fonts/Fredoka-SemiBold.ttf") as Font
	if ResourceLoader.exists("res://fonts/Nunito-Bold.ttf"):
		font_body = load("res://fonts/Nunito-Bold.ttf") as Font

# Gaya tanah liat: border 3 px penuh + bawah tebal 7 px (bayangan solid).
func _clay(bg: Color, border: Color = INK, radius: int = 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 7
	s.border_color = border
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 8
	s.content_margin_bottom = 4
	return s

# Tema sekali pakai semua layar: font + tombol biasa/utama.
func _make_theme() -> void:
	var th := Theme.new()
	if font_body:
		th.default_font = font_body
	th.default_font_size = 15
	th.set_color("font_color", "Button", INK)
	th.set_color("font_disabled_color", "Button", Color(0.60, 0.48, 0.36))
	th.set_color("font_color", "PrimaryButton", INK)
	th.set_color("font_disabled_color", "PrimaryButton", Color(0.60, 0.48, 0.36))
	th.set_stylebox("normal", "Button", _clay(CREAM))
	th.set_stylebox("hover", "Button", _clay(Color(1.0, 0.97, 0.90)))
	var pressed := _clay(CREAM_DIM)
	pressed.border_width_bottom = 3
	pressed.content_margin_top = 12
	th.set_stylebox("pressed", "Button", pressed)
	var dis := _clay(Color(0.94, 0.89, 0.76), Color(0.79, 0.66, 0.49))
	th.set_stylebox("disabled", "Button", dis)
	th.set_stylebox("focus", "Button", _focus_box())
	th.set_stylebox("normal", "PrimaryButton", _clay(Color(1.0, 0.79, 0.25)))
	th.set_stylebox("hover", "PrimaryButton", _clay(Color(1.0, 0.84, 0.35)))
	var ppressed := _clay(Color(1.0, 0.79, 0.25))
	ppressed.border_width_bottom = 3
	ppressed.content_margin_top = 12
	th.set_stylebox("pressed", "PrimaryButton", ppressed)
	th.set_stylebox("disabled", "PrimaryButton", dis)
	th.set_stylebox("focus", "PrimaryButton", _focus_box())
	ui_theme = th

func _focus_box() -> StyleBoxFlat:
	# Fokus keyboard/gamepad: border biru 3 px di luar tombol (jangan dihapus).
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.corner_radius_top_left = 16
	s.corner_radius_top_right = 16
	s.corner_radius_bottom_left = 16
	s.corner_radius_bottom_right = 16
	s.border_width_left = 3
	s.border_width_right = 3
	s.border_width_top = 3
	s.border_width_bottom = 3
	s.border_color = FOCUS_BLUE
	s.expand_margin_left = 3.0
	s.expand_margin_right = 3.0
	s.expand_margin_top = 3.0
	s.expand_margin_bottom = 3.0
	return s

func _apply_theme_to(c: Control) -> void:
	c.theme = ui_theme

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
	s.bg_color = Color(0.23, 0.14, 0.09, 0.88)
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
	if font_title:
		l.add_theme_font_override("font", font_title)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(1, 1, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _dlabel(t: String, size: int, c: Color = INK) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return l

func _style_light(bg: Color, border: Color) -> StyleBoxFlat:
	return _clay(bg, border, 14)

func _pill(t: String, bg: Color, fg: Color, size: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = 9
	s.corner_radius_top_right = 9
	s.corner_radius_bottom_left = 9
	s.corner_radius_bottom_right = 9
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", s)
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", fg)
	p.add_child(l)
	return p

func _btn(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 20)
	return b

# ---------- menu (ala mockup) ----------

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _style(PANEL, 18))
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-540, -330)
	menu_panel.custom_minimum_size = Vector2(1080, 660)
	_apply_theme_to(menu_panel)
	add_child(menu_panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 30)
	menu_panel.add_child(cols)
	# kiri: judul + tombol
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(430, 0)
	cols.add_child(left)
	left.add_child(_pill("Co-op masak · 1 pemain + 2 bot", INK, Color(1, 1, 1), 14))
	var title := _title_label("Overcooked", 64)
	title.add_theme_color_override("font_color", Color(0.80, 0.35, 0.20))
	left.add_child(title)
	var title2 := _title_label("Dungeon", 64)
	left.add_child(title2)
	var desc := _dlabel("Layani pelanggan sebelum sabar mereka habis. Rekrut bot buat bantu, tapi jaga kompor biar tidak kebakaran.", 16, Color(0.85, 0.85, 0.9))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(420, 90)
	left.add_child(desc)
	continue_btn = _btn("» Lanjut Level 1")
	continue_btn.custom_minimum_size = Vector2(420, 56)
	continue_btn.add_theme_font_size_override("font_size", 24)
	continue_btn.pressed.connect(func() -> void: game.continue_level())
	left.add_child(continue_btn)
	var help_b := _btn("Cara main")
	help_b.custom_minimum_size = Vector2(420, 48)
	help_b.pressed.connect(func() -> void: toggle_help())
	left.add_child(help_b)
	var set_b := _btn("Pengaturan")
	set_b.custom_minimum_size = Vector2(420, 48)
	set_b.pressed.connect(func() -> void: toggle_settings())
	left.add_child(set_b)
	var quit_b := _btn("Keluar")
	quit_b.custom_minimum_size = Vector2(420, 48)
	quit_b.pressed.connect(func() -> void: get_tree().quit())
	left.add_child(quit_b)
	var hints := _dlabel("WASD gerak · Shift lari · E ambil/taruh/tahan cincang · Q rekrut bot · Esc jeda · F1 bantuan", 13, Color(0.7, 0.7, 0.8))
	hints.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hints.custom_minimum_size = Vector2(420, 44)
	left.add_child(hints)
	# kanan: pilih level
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.custom_minimum_size = Vector2(560, 0)
	cols.add_child(right)
	var rhead := HBoxContainer.new()
	right.add_child(rhead)
	var pl := _title_label("PILIH LEVEL", 18)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhead.add_child(pl)
	var sv := _title_label("Tersimpan otomatis", 13)
	sv.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8))
	rhead.add_child(sv)
	level_cards = VBoxContainer.new()
	level_cards.add_theme_constant_override("separation", 12)
	right.add_child(level_cards)
	_build_help_overlay()
	_build_settings_overlay()
	_apply_mute(_load_muted())
	refresh_menu_best()

func _level_short(idx: int) -> String:
	return "Lanjut Level %d" % (idx + 1)

func refresh_menu_best() -> void:
	# bangun ulang kartu level (bintang/rekor/status terbaru)
	for c in level_cards.get_children():
		c.queue_free()
	var bests: Array = []
	for i in range(LevelData.LEVELS.size()):
		bests.append(game.load_best(i))
	var cont: int = GameMain.continue_for(bests)
	continue_btn.text = "» " + _level_short(cont)
	for i in range(LevelData.LEVELS.size()):
		level_cards.add_child(_level_card(i, bests, cont))

func _level_card(idx: int, bests: Array, cont: int) -> PanelContainer:
	var lv: Dictionary = LevelData.LEVELS[idx]
	var stars := int(bests[idx][1])
	var best := int(bests[idx][0])
	var prev := 0 if idx == 0 else int(bests[idx - 1][1])
	var unlocked: bool = GameMain.unlocked_for(prev, idx)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	card.add_child(h)
	var badge := _pill(str(idx + 1), INK if unlocked else Color(0.6, 0.6, 0.62), Color(1, 1, 1), 24)
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(_dlabel(str(lv.get("name", "?")), 22))
	v.add_child(_dlabel(game.level_desc(idx), 14, INK_SOFT))
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 4)
	v.add_child(srow)
	for s in range(3):
		srow.add_child(_dlabel("★" if s < stars else "☆", 18, GOLD if s < stars else INK_SOFT))
	var tbest := _dlabel("Terbaik %d" % best, 14, INK_SOFT)
	srow.add_child(tbest)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	h.add_child(side)
	if not unlocked:
		var lock := Button.new()
		lock.text = "Terkunci"
		lock.disabled = true
		lock.custom_minimum_size = Vector2(130, 36)
		side.add_child(lock)
		var hint := _dlabel("Butuh 1 bintang di Level %d" % idx, 12, INK_SOFT)
		side.add_child(hint)
		return card
	var go := Button.new()
	if stars >= 3:
		go.text = "Selesai"
	elif idx == cont:
		go.text = "Main ini"
	else:
		go.text = "Mainkan"
	go.custom_minimum_size = Vector2(130, 44)
	go.add_theme_font_size_override("font_size", 16)
	var li := idx
	go.pressed.connect(func() -> void: game.start_level(li))
	side.add_child(go)
	return card

func _build_help_overlay() -> void:
	help_overlay = PanelContainer.new()
	help_overlay.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	help_overlay.set_anchors_preset(Control.PRESET_CENTER)
	help_overlay.position = Vector2(-260, -220)
	help_overlay.custom_minimum_size = Vector2(520, 440)
	help_overlay.visible = false
	_apply_theme_to(help_overlay)
	add_child(help_overlay)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	help_overlay.add_child(v)
	v.add_child(_dlabel("Cara main", 26))
	var t := _dlabel("WASD / stick: gerak · Shift / B: lari\nE / Spasi / A: ambil, taruh, sajikan (TAHAN: cincang, cuci, padamkan)\nQ / Y: rekrut bot (50/150 poin, maks 2) · Esc / Start: jeda · F1: bantuan\n\nAlur: peti > talenan > kompor > plating > ANTAR. Gosong dibiarkan jadi api — ambil APAR merah di samping kompor! Order merah = sabar menipis, cepat hangus (-20).", 15)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(480, 260)
	v.add_child(t)
	var close := _btn("Tutup")
	close.custom_minimum_size = Vector2(200, 44)
	close.pressed.connect(func() -> void: toggle_help())
	v.add_child(close)

func toggle_help() -> void:
	help_overlay.visible = not help_overlay.visible
	settings_overlay.visible = false

func _build_settings_overlay() -> void:
	settings_overlay = PanelContainer.new()
	settings_overlay.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	settings_overlay.set_anchors_preset(Control.PRESET_CENTER)
	settings_overlay.position = Vector2(-230, -170)
	settings_overlay.custom_minimum_size = Vector2(460, 340)
	settings_overlay.visible = false
	_apply_theme_to(settings_overlay)
	add_child(settings_overlay)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	settings_overlay.add_child(v)
	v.add_child(_dlabel("Pengaturan", 26))
	mute_btn = _btn("Suara: Nyala")
	mute_btn.custom_minimum_size = Vector2(300, 48)
	mute_btn.pressed.connect(func() -> void: _apply_mute(not muted))
	v.add_child(mute_btn)
	var t := _dlabel("Kontrol keyboard: WASD + Shift + E + Q + Esc + F1.\nGamepad: stick/D-pad + A + B + Y + Start.\nTerakhir dipakai: tombol prompt menyesuaikan otomatis.", 14)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(420, 120)
	v.add_child(t)
	var close := _btn("Tutup")
	close.custom_minimum_size = Vector2(200, 44)
	close.pressed.connect(func() -> void: toggle_settings())
	v.add_child(close)

func toggle_settings() -> void:
	settings_overlay.visible = not settings_overlay.visible
	help_overlay.visible = false

func _load_muted() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(GameMain.SAVE_PATH)
	return bool(cfg.get_value("settings", "muted", false))

func _apply_mute(m: bool) -> void:
	muted = m
	AudioServer.set_bus_mute(0, m)
	var cfg := ConfigFile.new()
	cfg.load(GameMain.SAVE_PATH)
	cfg.set_value("settings", "muted", m)
	cfg.save(GameMain.SAVE_PATH)
	mute_btn.text = "Suara: Mati" if m else "Suara: Nyala"

# ---------- HUD main (ala mockup) ----------

func _build_hud() -> void:
	hud_root = Control.new()
	hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.visible = false
	_apply_theme_to(hud_root)
	add_child(hud_root)
	# kiri atas: tombol pause + nama level
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.custom_minimum_size = Vector2(44, 44)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_btn.position = Vector2(10, 8)
	pause_btn.pressed.connect(func() -> void: game.toggle_pause())
	hud_root.add_child(pause_btn)
	level_label = _title_label("", 15)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	level_label.position = Vector2(62, 8)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_root.add_child(level_label)
	# tengah atas: panel skor 420x76 (timer + skor + blok bintang)
	score_panel = PanelContainer.new()
	score_panel.name = "ScorePanel"
	score_panel.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	score_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_panel.position = Vector2(-210, 8)
	score_panel.custom_minimum_size = Vector2(420, 76)
	hud_root.add_child(score_panel)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 14)
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	score_panel.add_child(srow)
	time_label = _dlabel("3:00", 26)
	srow.add_child(time_label)
	var scol := VBoxContainer.new()
	scol.add_theme_constant_override("separation", 0)
	srow.add_child(scol)
	var srow2 := HBoxContainer.new()
	srow2.add_theme_constant_override("separation", 8)
	scol.add_child(srow2)
	var sk := _dlabel("SKOR", 11, INK_SOFT)
	srow2.add_child(sk)
	score_label = _dlabel("0", 26)
	srow2.add_child(score_label)
	# blok bintang 180 px: bintang di x ambang + bar 6 px + angka 10 px
	var starblock := Control.new()
	starblock.custom_minimum_size = Vector2(180, 30)
	scol.add_child(starblock)
	star_bar = ProgressBar.new()
	star_bar.min_value = 0.0
	star_bar.max_value = 100.0
	star_bar.value = 0.0
	star_bar.show_percentage = false
	star_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	star_bar.offset_top = 12.0
	star_bar.offset_bottom = 18.0
	starblock.add_child(star_bar)
	star_labels.clear()
	thr_labels.clear()
	for i in range(3):
		var sl := _dlabel("☆", 14, INK_SOFT)
		sl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sl.position = Vector2(60.0 * float(i + 1) - 8.0, -4.0)
		starblock.add_child(sl)
		star_labels.append(sl)
		var tl := _dlabel("300", 10, INK_SOFT)
		tl.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tl.position = Vector2(60.0 * float(i + 1) - 20.0, 18.0)
		tl.custom_minimum_size = Vector2(40, 14)
		tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		starblock.add_child(tl)
		thr_labels.append(tl)
	# kiri: rel pesanan transparan 252 px (tanpa panel pembungkus)
	orders_rail = VBoxContainer.new()
	orders_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	orders_rail.position = Vector2(12, 64)
	orders_rail.custom_minimum_size = Vector2(252, 0)
	orders_rail.add_theme_constant_override("separation", 6)
	hud_root.add_child(orders_rail)
	var headpill := PanelContainer.new()
	headpill.name = "HeadPill"
	var hs := StyleBoxFlat.new()
	hs.bg_color = CREAM
	hs.corner_radius_top_left = 9
	hs.corner_radius_top_right = 9
	hs.corner_radius_bottom_left = 9
	hs.corner_radius_bottom_right = 9
	hs.content_margin_left = 10
	hs.content_margin_right = 10
	hs.content_margin_top = 3
	hs.content_margin_bottom = 3
	headpill.add_theme_stylebox_override("panel", hs)
	seats_label = _dlabel("PESANAN", 13)
	headpill.add_child(seats_label)
	orders_rail.add_child(headpill)
	orders_box = VBoxContainer.new()
	orders_box.add_theme_constant_override("separation", 6)
	orders_rail.add_child(orders_box)
	info_label = _dlabel("", 13, INK_SOFT)
	info_label.visible = false
	hud_root.add_child(info_label)
	# kanan: tombol rekrut + baris bot kompak (tanpa panel/kepala)
	bot_side = VBoxContainer.new()
	bot_side.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	bot_side.position = Vector2(-232, 12)
	bot_side.custom_minimum_size = Vector2(220, 0)
	bot_side.add_theme_constant_override("separation", 6)
	hud_root.add_child(bot_side)
	recruit_btn = Button.new()
	recruit_btn.theme_type_variation = "PrimaryButton"
	recruit_btn.custom_minimum_size = Vector2(220, 44)
	recruit_btn.add_theme_font_size_override("font_size", 14)
	recruit_btn.pressed.connect(func() -> void: game.recruit_bot())
	bot_side.add_child(recruit_btn)
	bot_rows = VBoxContainer.new()
	bot_rows.add_theme_constant_override("separation", 6)
	bot_side.add_child(bot_rows)
	# banner kebakaran 420 px (tengah, di bawah panel skor), persisten
	fire_banner = PanelContainer.new()
	fire_banner.add_theme_stylebox_override("panel", _style_light(Color(1.0, 0.90, 0.87), BLOOD))
	fire_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fire_banner.position = Vector2(-210, 92)
	fire_banner.custom_minimum_size = Vector2(420, 64)
	fire_banner.visible = false
	hud_root.add_child(fire_banner)
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 12)
	frow.alignment = BoxContainer.ALIGNMENT_CENTER
	fire_banner.add_child(frow)
	var fico := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color = BLOOD
	fs.corner_radius_top_left = 10
	fs.corner_radius_top_right = 10
	fs.corner_radius_bottom_left = 10
	fs.corner_radius_bottom_right = 10
	fs.content_margin_left = 10
	fs.content_margin_right = 10
	fs.content_margin_top = 4
	fs.content_margin_bottom = 4
	fico.add_theme_stylebox_override("panel", fs)
	var fl := Label.new()
	fl.text = "!"
	fl.add_theme_font_size_override("font_size", 22)
	fl.add_theme_color_override("font_color", Color(1, 1, 1))
	fl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fico.add_child(fl)
	frow.add_child(fico)
	var fv := VBoxContainer.new()
	fv.add_theme_constant_override("separation", 0)
	frow.add_child(fv)
	fire_title = _dlabel("KEBAKARAN", 22, BLOOD)
	fv.add_child(fire_title)
	fire_sub = _dlabel("", 14, INK_SOFT)
	fv.add_child(fire_sub)
	# bawah tengah: bar 460x64 (tangan 200 + aksi 244), tombol sembunyi bila kosong
	bottom_bar = HBoxContainer.new()
	bottom_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom_bar.position = Vector2(-230, -80)
	bottom_bar.custom_minimum_size = Vector2(460, 64)
	bottom_bar.add_theme_constant_override("separation", 12)
	bottom_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	hud_root.add_child(bottom_bar)
	var hand := PanelContainer.new()
	hand.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	hand.custom_minimum_size = Vector2(200, 64)
	bottom_bar.add_child(hand)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hand.add_child(hv)
	hv.add_child(_dlabel("TANGAN", 11, INK_SOFT))
	carry_label = _dlabel("Kosong", 16)
	hv.add_child(carry_label)
	action_btn = Button.new()
	action_btn.theme_type_variation = "PrimaryButton"
	action_btn.custom_minimum_size = Vector2(244, 64)
	action_btn.add_theme_font_size_override("font_size", 20)
	action_btn.pressed.connect(func() -> void:
		if game.playing and not game.paused:
			game.do_interact())
	bottom_bar.add_child(action_btn)
	msg_label = _title_label("", 22)
	msg_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	msg_label.position = Vector2(-300, 192)
	msg_label.custom_minimum_size = Vector2(600, 40)
	hud_root.add_child(msg_label)
	count_label = _title_label("", 96)
	count_label.set_anchors_preset(Control.PRESET_CENTER)
	count_label.position = Vector2(-200, -120)
	count_label.custom_minimum_size = Vector2(400, 200)
	count_label.add_theme_color_override("font_color", ACCENT)
	hud_root.add_child(count_label)

func _make_chip(parent: Control, t: String) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _chip_style())
	parent.add_child(p)
	var l := _title_label(t, 22)
	p.add_child(l)
	return l

# ---------- hasil level (ala mockup) ----------

func _build_over() -> void:
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", _style_light(CREAM, INK))
	over_panel.set_anchors_preset(Control.PRESET_CENTER)
	over_panel.position = Vector2(-330, -360)
	over_panel.custom_minimum_size = Vector2(660, 700)
	over_panel.visible = false
	_apply_theme_to(over_panel)
	add_child(over_panel)
	over_rows = VBoxContainer.new()
	over_rows.add_theme_constant_override("separation", 8)
	over_panel.add_child(over_rows)

func _over_row(left: String, dim: String, val: String, c: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := _dlabel(left, 18)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	if dim != "":
		h.add_child(_dlabel(dim, 14, INK_SOFT))
	var r := _dlabel(val, 20, c)
	h.add_child(r)
	return h

func show_over(score: int, stars: int, lv_name: String, rekor: bool, ledger: Dictionary, level_idx: int, old_best: int) -> void:
	hud_root.visible = false
	pause_panel.visible = false
	over_panel.visible = true
	for c in over_rows.get_children():
		c.queue_free()
	var lv: Dictionary = LevelData.LEVELS[level_idx]
	var sub := _dlabel("LEVEL %d · %s" % [level_idx + 1, str(lv_name).to_upper()], 15, INK_SOFT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_rows.add_child(sub)
	var title := _dlabel("Shift selesai!", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_rows.add_child(title)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override("separation", 10)
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	over_rows.add_child(srow)
	for i in range(3):
		srow.add_child(_dlabel("★" if i < stars else "☆", 44, GOLD if i < stars else INK_SOFT))
	var s3 := int(lv.get("star_3", 900))
	var note := _dlabel("Sempurna! Semua bintang diraih.", 16, INK_SOFT)
	if stars < 3:
		note = _dlabel("Tinggal %d poin lagi untuk bintang 3" % maxi(0, s3 - score), 16, INK_SOFT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_rows.add_child(note)
	over_rows.add_child(HSeparator.new())
	var L: Dictionary = ledger
	over_rows.add_child(_over_row("Pesanan selesai", "%d dari %d" % [int(L.get("done", 0)), int(L.get("spawned", 0))], "+%d" % int(L.get("base", 0)), INK))
	over_rows.add_child(_over_row("Bonus cepat", "%d pesanan di atas 66% sabar" % int(L.get("bonus_n", 0)), "+%d" % int(L.get("bonus", 0)), LEAF))
	over_rows.add_child(_over_row("Tip", "", "+%d" % int(L.get("tip", 0)), LEAF))
	over_rows.add_child(_over_row("Pelanggan ngamuk", "%d orang" % int(L.get("angry_n", 0)), "-%d" % int(L.get("angry", 0)), BLOOD))
	over_rows.add_child(_over_row("Kebakaran", "%d kali · %d dtk" % [int(L.get("fire_n", 0)), int(L.get("fire_secs", 0))], "-%d" % int(L.get("fire", 0)), BLOOD))
	over_rows.add_child(_over_row("Biaya rekrut bot", "%d bot" % int(L.get("recruit_n", 0)), "-%d" % int(L.get("recruit", 0)), BLOOD))
	if int(L.get("fail_n", 0)) > 0:
		over_rows.add_child(_over_row("Salah sajikan", "%d kali" % int(L.get("fail_n", 0)), "-%d" % int(L.get("fail", 0)), BLOOD))
	over_rows.add_child(HSeparator.new())
	var th := HBoxContainer.new()
	over_rows.add_child(th)
	var tleft := VBoxContainer.new()
	tleft.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(tleft)
	tleft.add_child(_dlabel("TOTAL SKOR", 16, INK_SOFT))
	if rekor:
		tleft.add_child(_dlabel("Rekor lama %d · rekor baru!" % old_best, 14, INK_SOFT))
	else:
		tleft.add_child(_dlabel("Rekor %d" % maxi(old_best, score), 14, INK_SOFT))
	var tot := _dlabel(str(score), 56, Color(0.75, 0.35, 0.20))
	th.add_child(tot)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 12)
	brow.alignment = BoxContainer.ALIGNMENT_CENTER
	over_rows.add_child(brow)
	var again := _btn("Main lagi")
	again.custom_minimum_size = Vector2(200, 56)
	again.add_theme_font_size_override("font_size", 22)
	again.add_theme_stylebox_override("normal", _style_light(GOLD, INK))
	again.add_theme_color_override("font_color", INK)
	again.pressed.connect(func() -> void: game.restart_level())
	brow.add_child(again)
	var nxt := level_idx + 1
	if nxt < LevelData.LEVELS.size() and game.is_level_unlocked(nxt):
		var nb := _btn("Level %d" % (nxt + 1))
		nb.custom_minimum_size = Vector2(160, 56)
		nb.add_theme_font_size_override("font_size", 22)
		nb.pressed.connect(func() -> void: game.start_level(nxt))
		brow.add_child(nb)
	var tomenu := _btn("Menu")
	tomenu.custom_minimum_size = Vector2(140, 56)
	tomenu.add_theme_font_size_override("font_size", 22)
	tomenu.pressed.connect(func() -> void: game.to_menu())
	brow.add_child(tomenu)

func _build_pause() -> void:
	pause_panel = PanelContainer.new()
	pause_panel.add_theme_stylebox_override("panel", _style(PANEL, 18))
	pause_panel.set_anchors_preset(Control.PRESET_CENTER)
	pause_panel.position = Vector2(-170, -130)
	pause_panel.custom_minimum_size = Vector2(340, 260)
	pause_panel.visible = false
	_apply_theme_to(pause_panel)
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
	help_overlay.visible = false
	settings_overlay.visible = false
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
	# label level + ambang bintang dari data level
	level_label.text = "LEVEL %d · %s" % [game.level_idx + 1, str(game.level.get("name", "?")).to_upper()]
	_thr = [int(game.level.get("star_1", 300)), int(game.level.get("star_2", 550)), int(game.level.get("star_3", 800))]
	for i in range(3):
		(thr_labels[i] as Label).text = str(_thr[i])
		# bintang + angka di x ambang proporsional (blok 180 px)
		var fx := 180.0 * float(_thr[i]) / maxf(float(_thr[2]), 1.0)
		(star_labels[i] as Label).position = Vector2(fx - 8.0, -4.0)
		(thr_labels[i] as Label).position = Vector2(fx - 20.0, 18.0)
	_last_bot_sig = ""
	_last_card_ms = 0
	set_score(game.orders.score)

func show_pause(on: bool) -> void:
	pause_panel.visible = on

func set_countdown(t: String) -> void:
	count_label.text = t

# ---------- update ----------

func set_score(s: int) -> void:
	score_label.text = str(s)
	var t3: float = maxf(float(_thr[2]), 1.0)
	star_bar.max_value = 100.0
	star_bar.value = 100.0 * float(s) / t3
	for i in range(3):
		(star_labels[i] as Label).text = "★" if s >= int(_thr[i]) else "☆"
		(star_labels[i] as Label).add_theme_color_override("font_color", GOLD if s >= int(_thr[i]) else INK_SOFT)
	refresh_fire()

func set_time(t: float) -> void:
	var m := int(t) / 60
	var sec := int(t) % 60
	time_label.text = "%d:%02d" % [m, sec]
	if t < 30.0:
		time_label.add_theme_color_override("font_color", BLOOD)
	else:
		time_label.add_theme_color_override("font_color", INK)

func set_bots(_n: int) -> void:
	# rebuild max 5x/detik atau saat tanda tangan berubah
	var now := Time.get_ticks_msec()
	var sig := _bot_sig()
	if sig == _last_bot_sig and now - _last_bot_ms < 200:
		return
	_last_bot_sig = sig
	_last_bot_ms = now
	for c in bot_rows.get_children():
		c.queue_free()
	var cost: int = game.recruit_cost()
	if game.bots.size() >= 2:
		recruit_btn.text = "Bot penuh (2/2)"
		recruit_btn.disabled = true
	else:
		recruit_btn.text = "%s rekrut · %d poin" % [_recruit_key, cost]
		recruit_btn.disabled = false
	for i in range(game.bots.size()):
		bot_rows.add_child(_bot_row(game.bots[i], i + 1))

func _bot_sig() -> String:
	var parts: Array = [str(game.bots.size())]
	for b in game.bots:
		if not is_instance_valid(b):
			parts.append("x")
			continue
		var carry_txt := ""
		if b.carry and is_instance_valid(b.carry):
			carry_txt = b.carry.describe()
		parts.append("%s|%s|%s|%s" % [b._job, b.task, str(b.plan.get("uid", 0)), carry_txt])
	return "|".join(PackedStringArray(parts))

func _bot_row(b, num: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 40)
	card.add_theme_stylebox_override("panel", _style_light(CREAM_DIM, INK_SOFT))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	h.add_child(_pill("B%d" % num, INK, Color(1, 1, 1), 14))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	top.add_child(_dlabel("Bot %d" % num, 15))
	var pill_txt: String = str(b._job)
	var pill_bg := Color(0.55, 0.55, 0.58)
	var pill_fg := Color(1, 1, 1)
	var carrying_apar: bool = b.carry and is_instance_valid(b.carry) and b.carry.ingredient == "apar"
	if carrying_apar or b._job in ["Ambil APAR", "Padamkan!", "APAR kembali"]:
		pill_txt = "APAR"
		pill_bg = BLOOD
	elif not (b.plan as Dictionary).is_empty():
		pill_txt = "Masak"
		pill_bg = LEAF
	elif b.task == "todeliver":
		pill_txt = "Antar"
		pill_bg = GOLD
	top.add_child(_pill(pill_txt, pill_bg, pill_fg, 13))
	v.add_child(_dlabel(_bot_sub(b), 13, INK_SOFT))
	return card

func _bot_sub(b) -> String:
	var p: Dictionary = b.plan
	if not p.is_empty():
		var o: Dictionary = game.orders.get_order(int(p.get("uid", 0)))
		if not o.is_empty():
			var lbl := str(o.get("recipe", {}).get("label", "?")).split(" ")[0]
			return "%s · %s" % [lbl, str(o.get("table_id", "?"))]
	return str(b._job)

func refresh_fire() -> void:
	if game == null:
		return
	var st = game.burning_stove()
	if st == null:
		fire_banner.visible = false
		return
	fire_banner.visible = true
	fire_title.text = "KEBAKARAN · Kompor %d" % game.stove_index(st)
	fire_sub.text = "-2 poin tiap detik · APAR ada di samping kompor"

func set_info(t: String) -> void:
	info_label.text = t

func set_prompt(action: String) -> void:
	_last_prompt = action
	if action == "":
		action_btn.visible = false
		return
	action_btn.visible = true
	action_btn.disabled = false
	action_btn.text = "%s %s" % [prompt_key_txt, action]

func set_carry(t: String) -> void:
	carry_label.text = t

func set_prompt_key(key: String) -> void:
	prompt_key_txt = key
	_recruit_key = "[Y]" if key == "[A]" else "[Q]"
	_last_bot_sig = ""
	set_prompt(_last_prompt)


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
	# header: pill "PESANAN · diambil/total"
	var si: Array = game.seats_info()
	seats_label.text = "PESANAN · %d/%d" % [si[0], si[1]]
	if orders.is_empty():
		var l := _dlabel("(belum ada order)", 13, INK_SOFT)
		orders_box.add_child(l)
		return
	# urut sabar paling sedikit; maksimal 3 kartu + pill +N
	var sorted: Array = orders.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.get("time_left", 0.0)) < float(b.get("time_left", 0.0)))
	var shown: int = mini(3, sorted.size())
	for i in range(shown):
		orders_box.add_child(_order_card(sorted[i]))
	if sorted.size() > shown:
		var more := _pill("+%d pesanan lagi" % (sorted.size() - shown), CREAM_DIM, INK_SOFT, 12)
		more.custom_minimum_size = Vector2(0, 26)
		orders_box.add_child(more)

func _order_card(o: Dictionary) -> PanelContainer:
	var r: Dictionary = o["recipe"]
	var needs: Array = r.get("needs", [])
	var uid := int(o.get("uid", 0))
	var tleft := float(o.get("time_left", 0.0))
	var tmax := float(o.get("time_max", 90.0))
	var urgent: bool = tleft < 20.0
	var card := PanelContainer.new()
	var bg := CREAM if not urgent else Color(1.0, 0.91, 0.87)
	card.add_theme_stylebox_override("panel", _style_light(bg, BLOOD if urgent else INK))
	card.custom_minimum_size = Vector2(252, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	# baris atas: nama + (klaim) pill Bot N + pill meja
	var hhead := HBoxContainer.new()
	hhead.add_theme_constant_override("separation", 6)
	v.add_child(hhead)
	var head := _dlabel(str(r.get("label", "?")), 16)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.clip_text = true
	hhead.add_child(head)
	var bidx: int = int(game.order_bot_idx(uid))
	if bidx > 0:
		hhead.add_child(_pill("Bot %d" % bidx, LEAF, Color(1, 1, 1), 12))
	hhead.add_child(_pill(str(o.get("table_id", "?")), INK, Color(1, 1, 1), 12))
	# baris bahan: chip kecil tanpa kurung; satu tag "cincang" bila semua-chop
	var prog: Array = game.order_progress(o)
	var all_chop := true
	for n in needs:
		if not bool(n.get("chop", false)):
			all_chop = false
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	for i in range(needs.size()):
		var n: Dictionary = needs[i]
		var is_done: bool = i < prog.size() and bool(prog[i])
		row.add_child(_chip(_need_name(n), str(n.get("item", "")), is_done))
	if all_chop and not needs.is_empty():
		var tag := _dlabel("cincang", 12, INK_SOFT)
		row.add_child(tag)
	# baris bawah: bar 6 px + garis 66%/50% + detik
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	v.add_child(brow)
	var barwrap := Control.new()
	barwrap.custom_minimum_size = Vector2(150, 10)
	barwrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barwrap.clip_contents = true
	brow.add_child(barwrap)
	var bar := ProgressBar.new()
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.value = 100.0 * tleft / maxf(tmax, 0.01)
	bar.show_percentage = false
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_top = 2.0
	bar.offset_bottom = 8.0
	barwrap.add_child(bar)
	for frac in [0.66, 0.5]:
		var tick := ColorRect.new()
		tick.color = Color(0.30, 0.20, 0.13, 0.55)
		tick.set_anchors_preset(Control.PRESET_TOP_LEFT)
		tick.anchor_right = frac
		tick.offset_left = -1.0
		tick.offset_right = 1.0
		tick.offset_top = 1.0
		tick.offset_bottom = 9.0
		barwrap.add_child(tick)
	var t := _dlabel("%d dtk" % int(ceil(tleft)), 12, BLOOD if urgent else INK_SOFT)
	brow.add_child(t)
	return card

# Chip bahan kecil: swatch 10 + teks 12. Selesai = hijau + ✓ (warna+ikon+teks).
func _chip(txt: String, ing: String, done: bool) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(10, 10)
	if done:
		dot.color = LEAF
	else:
		dot.color = LevelData.INGREDIENTS.get(ing, {}).get("color", Color.WHITE)
	h.add_child(dot)
	var lbl := _dlabel(txt + (" ✓" if done else ""), 12, LEAF if done else INK)
	h.add_child(lbl)
	if done:
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.87, 0.95, 0.82)
		bg.corner_radius_top_left = 7
		bg.corner_radius_top_right = 7
		bg.corner_radius_bottom_left = 7
		bg.corner_radius_bottom_right = 7
		bg.border_width_left = 1
		bg.border_width_right = 1
		bg.border_width_top = 1
		bg.border_width_bottom = 1
		bg.border_color = LEAF
		bg.content_margin_left = 6
		bg.content_margin_right = 6
		bg.content_margin_top = 2
		bg.content_margin_bottom = 2
		var wrap := PanelContainer.new()
		wrap.add_theme_stylebox_override("panel", bg)
		h.remove_child(dot)
		h.remove_child(lbl)
		wrap.add_child(h)
		var outer := HBoxContainer.new()
		outer.add_child(wrap)
		return outer
	return h

# Nama bahan tanpa tanda kurung (tag olah jadi satu di ujung baris).
func _need_name(n: Dictionary) -> String:
	var rule: Dictionary = LevelData.INGREDIENTS.get(str(n.get("item", "")), {})
	return str(rule.get("label", n.get("item", "?")))

func _need_short(n: Dictionary) -> String:
	var rule: Dictionary = LevelData.INGREDIENTS.get(str(n.get("item", "")), {})
	var s: String = str(rule.get("label", n.get("item", "?")))
	var tags: Array = []
	if bool(n.get("chop", false)):
		tags.append("cincang")
	if bool(n.get("cook", false)):
		tags.append("matang")
	if not tags.is_empty():
		s += " (" + ", ".join(PackedStringArray(tags)) + ")"
	return s

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

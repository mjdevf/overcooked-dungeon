class_name Station
extends StaticBody3D
## Satu script untuk semua meja: crate, cutting, stove, plate, delivery, sink, trash, table.

var station_type: String = "counter"
var world_pos: Vector2 = Vector2.ZERO
var stored: FoodItem = null       # item yg lagi di atas meja
var progress: float = 0.0         # untuk chop / stove / sink
var progress_needed: float = 2.0
var returns: Array = []           # (legacy v1, tidak dipakai di prototipe v2)
var cooking: bool = false
var burning: bool = false
var burn_timer: float = 0.0
var burn_limit: float = 8.0       # spec v2: gosong 8 detik setelah matang
var fire := false                 # KEBAKARAN: makanan gosong dibiarkan
var neglect_t := 0.0
var neglect_limit := 6.0          # gosong dibiarkan 6 dtk -> api
var fire_alarmed := false         # sudah bunyi alarm (diset game)
var enabled := true               # kompor nonaktif (MVP) kalau false
var label3d: Label3D
var bar: MeshInstance3D
var bar_bg: MeshInstance3D
var body_mesh: MeshInstance3D
var top_y := 1.0

signal changed

func setup(p_type: String, p_pos: Vector2, p_enabled: bool = true) -> void:
	station_type = p_type
	world_pos = p_pos
	enabled = p_enabled
	if station_type == "chop":
		progress_needed = 3.0
	elif station_type == "stove":
		progress_needed = 6.0
	elif station_type == "sink":
		progress_needed = 2.5

func _ready() -> void:
	position = Vector3(world_pos.x, 0.0, world_pos.y)
	_build()

func station_label() -> String:
	match station_type:
		"chop":
			return "Talenan"
		"stove":
			return "Kompor (mati)" if not enabled else "Kompor"
		"plates":
			return "Piring"
		"plating":
			return "Meja Plating"
		"spice":
			return "Rempah"
		"pass":
			return "Antar!"
		"cashier":
			return "Kasir"
		"sink":
			return "Wastafel"
		"trash":
			return "Tong Sampah"
		"apar":
			return "APAR"
		_:
			if station_type.begins_with("crate_"):
				var ing: String = station_type.replace("crate_", "")
				var lbl: String = str(LevelData.INGREDIENTS.get(ing, {}).get("label", ing))
				return "Ambil " + lbl
	return "Meja"

func base_color() -> Color:
	match station_type:
		"chop":
			return Color(0.72, 0.53, 0.32)
		"stove":
			return Color(0.25, 0.25, 0.30)
		"plates":
			return Color(0.85, 0.85, 0.90)
		"plating":
			return Color(0.62, 0.48, 0.30)
		"spice":
			return Color(0.55, 0.35, 0.25)
		"pass":
			return Color(0.30, 0.55, 0.85)
		"cashier":
			return Color(0.30, 0.55, 0.35)
		"sink":
			return Color(0.40, 0.65, 0.85)
		"trash":
			return Color(0.30, 0.30, 0.32)
		"apar":
			return Color(0.75, 0.15, 0.12)
		_:
			if station_type.begins_with("crate_"):
				var ing: String = station_type.replace("crate_", "")
				return LevelData.INGREDIENTS.get(ing, {}).get("color", Color(0.5, 0.5, 0.5))
	return Color(0.45, 0.40, 0.50)

const FURN := "res://assets_external/furniture-kit/Models/GLB format/"
const FOOD := "res://assets_external/food-kit/Models/GLB format/"

var fire_light: OmniLight3D
var flame_mesh: MeshInstance3D
var steam: CPUParticles3D
var burst: CPUParticles3D
var water_stream: MeshInstance3D
var display_node: Node3D
var return_root: Node3D
var knife_node: Node3D
var knife_base_y := 0.98
var working := false
var flicker_t := 0.0

func _build() -> void:
	# collision semua station sama
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.95, 1.0, 0.95)
	col.shape = shape
	col.position = Vector3(0, 0.5, 0)
	add_child(col)
	# badan per tipe (aset luar dulu, fallback prosedural detail)
	match station_type:
		"table":
			_build_counter()
		"chop":
			_build_cutting()
		"stove":
			_build_stove()
		"sink":
			_build_sink()
		"plates":
			_build_plate_rack()
		"plating":
			_build_plating()
		"spice":
			_build_spice()
		"pass":
			_build_pass()
		"cashier":
			_build_cashier()
		"trash":
			_build_trash()
		"apar":
			_build_apar()
		_:
			if station_type.begins_with("crate_"):
				_build_crate()
			else:
				_build_counter()
	# label melayang
	label3d = Label3D.new()
	label3d.text = station_label()
	label3d.font_size = 48
	label3d.pixel_size = 0.008
	label3d.position = Vector3(0, 1.9, 0)
	label3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label3d.no_depth_test = false
	label3d.modulate = Color(1, 1, 1)
	add_child(label3d)
	# progress bar (disembunyikan default)
	bar_bg = MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(0.9, 0.08, 0.05)
	bar_bg.mesh = bgm
	bar_bg.position = Vector3(0, 1.55, 0)
	var bgmat := StandardMaterial3D.new()
	bgmat.albedo_color = Color(0, 0, 0, 0.7)
	bgmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_bg.material_override = bgmat
	bar_bg.visible = false
	add_child(bar_bg)
	bar = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.86, 0.05, 0.06)
	bar.mesh = fm
	bar.position = Vector3(0, 1.55, 0)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.3, 0.9, 0.3)
	fmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material_override = fmat
	bar.visible = false
	add_child(bar)

# ---------- helper visual ----------

func _mat(c: Color, rough: float = 0.85, metal: float = 0.0, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

func _box(pos: Vector3, size: Vector3, c: Color, rough: float = 0.85) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, rough)
	add_child(mi)
	return mi

func _cyl(pos: Vector3, radius: float, height: float, c: Color, metal: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(c, 0.5, metal)
	add_child(mi)
	return mi

func _sphere(pos: Vector3, radius: float, c: Color, emit: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(c, 0.5, 0.0, emit)
	add_child(mi)
	return mi

func _glb_instance(path: String, pos: Vector3, scl: float, rot_y: float = 0.0) -> Node3D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var ps := load(path)
	if not (ps is PackedScene):
		return null
	var n: Node3D = (ps as PackedScene).instantiate()
	n.position = pos
	n.scale = Vector3(scl, scl, scl)
	n.rotation.y = rot_y
	add_child(n)
	return n

func _wood_body(top_color: Color) -> void:
	# counter kayu fallback: badan + papan atas + kaki
	body_mesh = _box(Vector3(0, 0.45, 0), Vector3(0.9, 0.9, 0.9), Color(0.42, 0.30, 0.20))
	_box(Vector3(0, 0.93, 0), Vector3(0.98, 0.08, 0.98), top_color, 0.6)

# ---------- builder per tipe ----------

func _build_counter() -> void:
	# kitchenBar.glb ukurannya cuma 0.43x0.42x0.21 (terlalu ramping) -> full prosedural.
	_wood_body(Color(0.62, 0.48, 0.32))
	top_y = 0.98

func _build_cutting() -> void:
	_wood_body(Color(0.72, 0.53, 0.32))
	top_y = 0.98
	# talenan (0.58m, pas) + pisau (0.72m -> skala 0.7 = 0.5m) di atas counter
	if _glb_instance(FOOD + "cutting-board.glb", Vector3(-0.1, 0.99, 0), 1.0) == null:
		_box(Vector3(-0.1, 0.98, 0), Vector3(0.5, 0.05, 0.35), Color(0.85, 0.68, 0.42), 0.6)
	knife_node = _glb_instance(FOOD + "cooking-knife.glb", Vector3(0.28, 0.98, 0.1), 0.7, 0.5)
	_make_burst(Color(0.5, 0.9, 0.4))

# Cat ulang model GLB furnitur jadi kayu hangat (Kenney default putih pucat).
# Traverse semua MeshInstance3D dan timpa material_override.
func _tint_wood(n: Node) -> void:
	var wood := _mat(Color(0.52, 0.37, 0.24), 0.8)
	_tint_recursive(n, wood)

func _tint_recursive(n: Node, m: Material) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).material_override = m
		_tint_recursive(c, m)

func _build_stove() -> void:
	top_y = 1.15
	# Full prosedural (model GLB burner-nya tidak di tengah -> panci selalu miring).
	# Badan + 4 tungku simetris + panci TEPAT di tengah: sejajar permanen.
	body_mesh = _box(Vector3(0, 0.42, 0), Vector3(0.9, 0.84, 0.9), Color(0.22, 0.22, 0.26))
	_box(Vector3(0, 0.87, 0), Vector3(0.94, 0.06, 0.94), Color(0.12, 0.12, 0.14), 0.4)
	# 4 tungku simetris di atas plat
	for xi in [-0.21, 0.21]:
		for zi in [-0.21, 0.21]:
			_cyl(Vector3(xi, 0.92, zi), 0.13, 0.04, Color(0.08, 0.08, 0.1))
	# panel depan: 2 kenop
	_cyl(Vector3(-0.15, 0.55, 0.46), 0.045, 0.05, Color(0.7, 0.72, 0.75), 0.6)
	_cyl(Vector3(0.15, 0.55, 0.46), 0.045, 0.05, Color(0.7, 0.72, 0.75), 0.6)
	if not enabled:
		_box(Vector3(0, 0.5, 0.47), Vector3(0.5, 0.3, 0.02), Color(0.1, 0.1, 0.12))
	# panci TEPAT tengah di atas tungku (nangkring di jeruji)
	_glb_instance(FOOD + "pot.glb", Vector3(0, 0.94, 0), 0.9)
	# api: disc emissive + lampu flicker (nyala saat memasak)
	flame_mesh = _cyl(Vector3(0, 0.9, 0), 0.2, 0.05, Color(1.0, 0.45, 0.1))
	flame_mesh.material_override = _mat(Color(1.0, 0.45, 0.1), 0.5, 0.0, 2.0)
	flame_mesh.visible = false
	fire_light = OmniLight3D.new()
	fire_light.position = Vector3(0, 1.6, 0)
	fire_light.light_color = Color(1.0, 0.55, 0.2)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 3.5
	add_child(fire_light)
	# uap saat memasak
	steam = CPUParticles3D.new()
	steam.position = Vector3(0, 1.25, 0)
	steam.amount = 14
	steam.lifetime = 1.2
	steam.emitting = false
	steam.direction = Vector3(0, 1, 0)
	steam.spread = 16.0
	steam.initial_velocity_min = 0.7
	steam.initial_velocity_max = 1.3
	steam.gravity = Vector3(0, 0.5, 0)
	steam.scale_amount_min = 0.5
	steam.scale_amount_max = 1.0
	var pm := SphereMesh.new()
	pm.radius = 0.06
	pm.height = 0.12
	var pmat := StandardMaterial3D.new()
	pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmat.albedo_color = Color(1, 1, 1, 0.45)
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	pm.surface_set_material(0, pmat)
	steam.mesh = pm
	add_child(steam)

func _build_sink() -> void:
	# Full prosedural menghadap UTARA (sisi pemain = -z): kabinet + bak + keran
	# belakang. (GLB dicampur part prosedural bikin posisi ngaco.)
	body_mesh = _box(Vector3(0, 0.4, 0), Vector3(0.9, 0.8, 0.9), Color(0.55, 0.60, 0.65))
	# bibir bak + cekungan + air
	_box(Vector3(0, 0.82, 0), Vector3(0.9, 0.06, 0.9), Color(0.78, 0.81, 0.85), 0.3)
	_box(Vector3(0, 0.80, 0), Vector3(0.6, 0.06, 0.6), Color(0.30, 0.34, 0.38), 0.4)
	var basin_water := _cyl(Vector3(0, 0.84, 0), 0.24, 0.03, Color(0.35, 0.6, 0.85))
	basin_water.material_override = _mat(Color(0.35, 0.6, 0.85), 0.15, 0.0, 0.5)
	# keran di belakang (+z, jauh dari pemain)
	_cyl(Vector3(0, 1.05, 0.34), 0.045, 0.5, Color(0.72, 0.75, 0.8), 0.8)
	_box(Vector3(0, 1.28, 0.18), Vector3(0.08, 0.08, 0.36), Color(0.72, 0.75, 0.8))
	# muka wastafel (sisi pemain/utara): 2 pintu kabinet + gagang
	_box(Vector3(-0.2, 0.42, -0.46), Vector3(0.34, 0.55, 0.03), Color(0.48, 0.53, 0.58), 0.5)
	_box(Vector3(0.2, 0.42, -0.46), Vector3(0.34, 0.55, 0.03), Color(0.48, 0.53, 0.58), 0.5)
	_sphere(Vector3(-0.06, 0.5, -0.48), 0.03, Color(0.3, 0.32, 0.35))
	_sphere(Vector3(0.06, 0.5, -0.48), 0.03, Color(0.3, 0.32, 0.35))
	# aliran air (muncul saat mencuci)
	water_stream = _cyl(Vector3(0, 1.0, 0), 0.025, 0.35, Color(0.5, 0.8, 1.0))
	water_stream.material_override = _mat(Color(0.5, 0.8, 1.0), 0.2, 0.0, 0.8)
	water_stream.visible = false
	_make_burst(Color(0.45, 0.7, 1.0))

func _build_plate_rack() -> void:
	# rak piring kayu: 2 tiang + 2 papan
	var wood := Color(0.5, 0.36, 0.24)
	_box(Vector3(-0.4, 0.5, 0), Vector3(0.08, 1.0, 0.8), wood)
	_box(Vector3(0.4, 0.5, 0), Vector3(0.08, 1.0, 0.8), wood)
	_box(Vector3(0, 0.5, 0), Vector3(0.85, 0.06, 0.85), wood)
	_box(Vector3(0, 0.98, 0), Vector3(0.85, 0.06, 0.85), Color(0.62, 0.47, 0.3))
	# tumpukan piring pajangan di belakang (plate.glb 0.89m -> skala 0.4 = 0.36m)
	for i in range(3):
		_glb_instance(FOOD + "plate.glb", Vector3(-0.2, 0.56 + 0.05 * float(i), -0.2), 0.4)

func _build_pass() -> void:
	# Jendela Antar di dinding pembatas: kusen + counter + strip menyala + bel.
	# Sisi kiri (dapur): taruh piring jadi. Sisi kanan: pelayan mengambil.
	body_mesh = _box(Vector3(0, 0.4, 0), Vector3(0.95, 0.8, 0.95), Color(0.35, 0.24, 0.16))
	_box(Vector3(0, 0.83, 0), Vector3(0.99, 0.08, 0.99), Color(0.62, 0.47, 0.30), 0.6)
	# strip oranye menyala = "taruh di sini"
	var strip := _box(Vector3(0, 0.88, 0), Vector3(0.7, 0.02, 0.7), Color(1.0, 0.55, 0.15))
	strip.material_override = _mat(Color(1.0, 0.55, 0.15), 0.5, 0.0, 1.2)
	# bel layanan emas
	_cyl(Vector3(-0.3, 0.92, 0.25), 0.07, 0.03, Color(0.5, 0.4, 0.2), 0.6)
	_sphere(Vector3(-0.3, 0.97, 0.25), 0.055, Color(0.95, 0.78, 0.3), 0.4)
	# kusen atas jendela
	_box(Vector3(0, 1.75, 0), Vector3(1.0, 0.12, 0.5), Color(0.42, 0.30, 0.58))
	top_y = 0.95
	refresh_returns()

func refresh_returns() -> void:
	# tumpukan piring kotor balikan (visual dari returns)
	if return_root and is_instance_valid(return_root):
		return_root.queue_free()
	return_root = Node3D.new()
	add_child(return_root)
	var i := 0
	for f in returns:
		if f and is_instance_valid(f):
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.26
			cm.bottom_radius = 0.26
			cm.height = 0.05
			mi.mesh = cm
			mi.position = Vector3(0.28, 0.92 + 0.06 * float(i), -0.2)
			mi.material_override = _mat(Color(0.5, 0.47, 0.42))
			return_root.add_child(mi)
		i += 1
		if i >= 4:
			break

func _build_cashier() -> void:
	# Konter kasir otomatis: badan hijau + mesin register + layar menyala
	body_mesh = _box(Vector3(0, 0.4, 0), Vector3(0.95, 0.8, 0.95), Color(0.22, 0.35, 0.24))
	_box(Vector3(0, 0.83, 0), Vector3(0.99, 0.08, 0.99), Color(0.30, 0.48, 0.32), 0.6)
	_box(Vector3(0.1, 1.0, -0.1), Vector3(0.3, 0.25, 0.25), Color(0.15, 0.15, 0.18))
	var scr := _box(Vector3(0.1, 1.05, 0.04), Vector3(0.22, 0.14, 0.02), Color(0.3, 0.9, 0.5))
	scr.material_override = _mat(Color(0.3, 0.9, 0.5), 0.4, 0.0, 1.0)

func _build_plating() -> void:
	# meja rakit kuning: counter kayu + papan terang + SELALU ada piring kosong
	# (rak piring + meja plating jadi satu alur: dandan di sini langsung).
	_wood_body(Color(0.66, 0.52, 0.34))
	top_y = 0.98
	var np := FoodItem.make_plate()
	force_store(np)

func _build_spice() -> void:
	# rak bumbu dekorasi: papan + toples/botol warna-warni (tahap lanjut)
	_wood_body(Color(0.5, 0.34, 0.22))
	for i in range(3):
		_cyl(Vector3(-0.25 + 0.25 * float(i), 1.05, -0.2), 0.09, 0.18, [Color(0.8, 0.3, 0.2), Color(0.9, 0.75, 0.3), Color(0.35, 0.6, 0.3)][i])
	for i in range(2):
		_cyl(Vector3(-0.12 + 0.25 * float(i), 1.05, 0.2), 0.07, 0.14, [Color(0.75, 0.75, 0.8), Color(0.55, 0.35, 0.7)][i])

func _build_trash() -> void:
	# Chute sampah di tembok: bak metal gelap + bibir terang + lubang hitam.
	# (Barrel GLB proporsinya aneh di sel tembok, jadi full prosedural.)
	body_mesh = _box(Vector3(0, 0.35, 0), Vector3(0.9, 0.7, 0.9), Color(0.24, 0.24, 0.28), 0.5)
	_box(Vector3(0, 0.72, 0), Vector3(0.98, 0.08, 0.98), Color(0.45, 0.47, 0.52), 0.4)
	_cyl(Vector3(0, 0.74, 0), 0.32, 0.06, Color(0.05, 0.05, 0.06))
	# pedal + engsel biar kebaca tong sampah
	_box(Vector3(0, 0.12, 0.48), Vector3(0.2, 0.08, 0.06), Color(0.45, 0.47, 0.52), 0.4)

func _build_apar() -> void:
	# Meja APAR di sudut: counter kayu + tabung merah + strip putih.
	_wood_body(Color(0.66, 0.52, 0.34))
	top_y = 0.98
	var tube := _cyl(Vector3(-0.15, 1.3, 0), 0.16, 0.55, Color(0.85, 0.12, 0.10))
	tube.material_override = _mat(Color(0.85, 0.12, 0.10), 0.4, 0.0, 0.4)
	_cyl(Vector3(-0.15, 1.3, 0), 0.165, 0.1, Color(0.95, 0.95, 0.95))
	_box(Vector3(-0.15, 1.62, 0), Vector3(0.08, 0.1, 0.08), Color(0.10, 0.10, 0.12))
	_box(Vector3(0.0, 1.56, 0), Vector3(0.22, 0.04, 0.04), Color(0.10, 0.10, 0.12))

func _build_crate() -> void:
	# peti kayu berpalangnya: tiang sudut + 3 papan per sisi (berlubang)
	var wood := Color(0.55, 0.40, 0.24)
	var wood_dark := Color(0.42, 0.30, 0.18)
	for sx in [-0.42, 0.42]:
		for sz in [-0.42, 0.42]:
			_box(Vector3(sx, 0.35, sz), Vector3(0.1, 0.7, 0.1), wood_dark)
	for y in [0.14, 0.35, 0.56]:
		_box(Vector3(0, y, -0.42), Vector3(0.94, 0.14, 0.06), wood)
		_box(Vector3(0, y, 0.42), Vector3(0.94, 0.14, 0.06), wood)
		_box(Vector3(-0.42, y, 0), Vector3(0.06, 0.14, 0.94), wood)
		_box(Vector3(0.42, y, 0), Vector3(0.06, 0.14, 0.94), wood)
	_box(Vector3(0, 0.05, 0), Vector3(0.9, 0.1, 0.9), wood_dark)
	# aksen warna bahan di bibir atas
	var ing: String = station_type.replace("crate_", "")
	var accent: Color = LevelData.INGREDIENTS.get(ing, {}).get("color", Color.WHITE)
	_box(Vector3(0, 0.68, -0.42), Vector3(0.94, 0.08, 0.08), accent, 0.5)
	_box(Vector3(0, 0.68, 0.42), Vector3(0.94, 0.08, 0.08), accent, 0.5)
	# contoh bahan melayang (bob di _process), skala 1.0 x faktor bahan
	var fct: float = float(LevelData.INGREDIENTS.get(ing, {}).get("scl", 1.0))
	display_node = _glb_ingredient(ing, Vector3(0, 1.15, 0), 1.0 * fct)
	if display_node == null:
		display_node = _sphere(Vector3(0, 1.15, 0), 0.2, accent)

func _glb_ingredient(ing: String, pos: Vector3, scl: float) -> Node3D:
	var base := FOOD
	match ing:
		"tomat":
			return _glb_instance(base + "tomato.glb", pos, scl)
		"selada":
			return _glb_instance(base + "cabbage.glb", pos, scl)
		"keju":
			return _glb_instance(base + "cheese.glb", pos, scl)
		"roti":
			return _glb_instance(base + "bread.glb", pos, scl)
		"daging":
			return _glb_instance(base + "meat-raw.glb", pos, scl)
		"sup":
			return _glb_instance(base + "bowl-broth.glb", pos, scl)
	return null

func _make_burst(c: Color) -> void:
	burst = CPUParticles3D.new()
	burst.position = Vector3(0, 1.15, 0)
	burst.amount = 12
	burst.lifetime = 0.5
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.emitting = false
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 35.0
	burst.initial_velocity_min = 1.5
	burst.initial_velocity_max = 3.0
	burst.gravity = Vector3(0, -6, 0)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.06)
	bm.surface_set_material(0, _mat(c, 0.6))
	burst.mesh = bm
	add_child(burst)

func _process(delta: float) -> void:
	flicker_t += delta
	# pisau mantul saat mencincang (working diset tiap frame oleh hold_work)
	if station_type == "chop" and knife_node and is_instance_valid(knife_node):
		if working:
			knife_node.position.y = knife_base_y + absf(sin(flicker_t * 16.0)) * 0.14
			knife_node.rotation.z = sin(flicker_t * 16.0) * 0.25
		else:
			knife_node.position.y = knife_base_y
			knife_node.rotation.z = 0.0
	working = false
	# pajangan crate melayang pelan
	if display_node and is_instance_valid(display_node):
		display_node.position.y = 1.15 + sin(flicker_t * 2.0) * 0.05
		display_node.rotation.y += delta * 0.8
	# api kompor flicker (api KEBAKARAN paling besar)
	if station_type == "stove":
		if fire:
			if flame_mesh:
				flame_mesh.visible = true
				var s0 := 1.9 + sin(flicker_t * 17.0) * 0.3
				flame_mesh.scale = Vector3(s0, 1.6, s0)
			if fire_light:
				fire_light.light_energy = 2.0 + sin(flicker_t * 15.0) * 0.5
			if steam:
				steam.emitting = true
		elif cooking and stored:
			if flame_mesh:
				flame_mesh.visible = true
				var s := 1.0 + sin(flicker_t * 14.0) * 0.12
				flame_mesh.scale = Vector3(s, 1.0, s)
			if fire_light:
				fire_light.light_energy = 1.1 + sin(flicker_t * 13.0) * 0.35
			if steam:
				steam.emitting = true
		elif burning and stored:
			if flame_mesh:
				flame_mesh.visible = true
				var s2 := 1.2 + sin(flicker_t * 9.0) * 0.2
				flame_mesh.scale = Vector3(s2, 1.0, s2)
			if fire_light:
				fire_light.light_energy = 0.7 + sin(flicker_t * 8.0) * 0.2
			if steam:
				steam.emitting = true
		else:
			if flame_mesh:
				flame_mesh.visible = false
			if fire_light:
				fire_light.light_energy = 0.0
			if steam:
				steam.emitting = false
	# masak otomatis di kompor
	if station_type == "stove" and cooking and stored and not stored.is_plate:
		progress += delta
		_update_bar(progress / progress_needed, Color(1.0, 0.6, 0.15))
		if progress >= progress_needed:
			stored.cooked = true
			stored.refresh()
			cooking = false
			burning = true
			burn_timer = 0.0
			label3d.text = station_label() + " MATANG!"
			emit_signal("changed")
	if burning and stored:
		burn_timer += delta
		if burn_timer > burn_limit and not stored.burnt:
			stored.burnt = true
			stored.refresh()
			label3d.text = "GOSONG! Buang!"
			_update_bar(1.0, Color(1, 0.15, 0.1))
			emit_signal("changed")
		elif stored.burnt and station_type == "stove" and enabled and not fire:
			# gosong dibiarkan -> KEBAKARAN
			neglect_t += delta
			if neglect_t >= neglect_limit:
				_ignite()

# Gosong dibiarkan -> api. Kompor terkunci sampai dipadamkan APAR.
func _ignite() -> void:
	fire = true
	fire_alarmed = false
	cooking = false
	burning = false
	neglect_t = 0.0
	if fire_light:
		fire_light.light_color = Color(1.0, 0.25, 0.1)
	label3d.text = "KEBAKARAN!"
	emit_signal("changed")

# Padamkan api (pemain/bot pakai APAR). Gosongnya tetap, wajib dibuang.
func extinguish() -> void:
	if not fire:
		return
	fire = false
	fire_alarmed = false
	cooking = false
	burning = false
	neglect_t = 0.0
	progress = 0.0
	hide_bar()
	if fire_light:
		fire_light.light_color = Color(1.0, 0.55, 0.2)
		fire_light.light_energy = 0.0
	if flame_mesh:
		flame_mesh.visible = false
	if steam:
		steam.emitting = false
	if stored and stored.burnt:
		label3d.text = "GOSONG! Buang!"
	else:
		label3d.text = station_label()
	emit_signal("changed")

func _update_bar(frac: float, c: Color) -> void:
	bar_bg.visible = true
	bar.visible = true
	var f: float = clampf(frac, 0.0, 1.0)
	bar.scale.x = maxf(f, 0.001)
	bar.position.x = -0.43 * (1.0 - f)
	var mat: StandardMaterial3D = bar.material_override
	mat.albedo_color = c

func hide_bar() -> void:
	if bar_bg:
		bar_bg.visible = false
	if bar:
		bar.visible = false

# Highlight label station yang sedang di depan pemain (kuning), lainnya redup.
func set_highlight(on: bool) -> void:
	if label3d == null or not is_instance_valid(label3d):
		return
	if on:
		label3d.modulate = Color(1.0, 0.85, 0.3)
	else:
		label3d.modulate = Color(1, 1, 1, 0.55)

# Dipanggil tiap frame saat pemain menahan E di cutting/sink.
func hold_work(delta: float) -> bool:
	if station_type == "chop":
		if stored and not stored.is_plate and not stored.chopped and LevelData.needs_chop(stored.ingredient):
			progress += delta
			working = true
			_update_bar(progress / progress_needed, Color(0.35, 0.85, 0.35))
			if progress >= progress_needed:
				stored.chopped = true
				stored.refresh()
				progress = 0.0
				hide_bar()
				label3d.text = station_label()
				if burst:
					burst.restart()
				emit_signal("changed")
				return true
		return false
	if station_type == "sink":
		if stored and stored.is_plate and stored.dirty:
			progress += delta
			if water_stream:
				water_stream.visible = true
			_update_bar(progress / progress_needed, Color(0.35, 0.7, 1.0))
			if progress >= progress_needed:
				stored.dirty = false
				stored.refresh()
				progress = 0.0
				hide_bar()
				if water_stream:
					water_stream.visible = false
				if burst:
					burst.restart()
				emit_signal("changed")
				return true
		else:
			if water_stream:
				water_stream.visible = false
		return false
	return false

# Interaksi utama saat tekan E. return String pesan aksi.
# game.gd yang pegang item bawaan pemain, station cuma simpan/terima.
func interact(carry: FoodItem, burn_enabled: bool) -> Dictionary:
	# res: { "take": FoodItem atau null, "place_consumed": bool, "msg": String }
	var res := {"take": null, "place_consumed": false, "msg": ""}
	if station_type.begins_with("crate_"):
		var ing: String = station_type.replace("crate_", "")
		if carry != null:
			res["msg"] = "Tangan penuh!"
			return res
		if stored != null:
			res["msg"] = "Meja penuh!"
			return res
		var f := FoodItem.make_ingredient(ing)
		res["take"] = f
		res["msg"] = "Ambil " + str(LevelData.INGREDIENTS.get(ing, {}).get("label", ing))
		return res
	if station_type == "trash":
		if carry == null:
			res["msg"] = "Tidak ada yg dibuang"
			return res
		# spec: piring dikembalikan bersih, bahan hilang
		if carry.is_plate:
			carry.plate_contents.clear()
			carry.dirty = false
			res["place_consumed"] = false
			res["msg"] = "Piring dibersihkan"
			return res
		res["place_consumed"] = true
		res["msg"] = "Dibuang: " + carry.describe()
		# gosong di-reset
		burning = false
		burn_timer = 0.0
		cooking = false
		progress = 0.0
		hide_bar()
		return res
	if station_type == "spice":
		res["msg"] = "Rempah tahap lanjut"
		return res
	if station_type == "sink":
		res["msg"] = "Wastafel tahap lanjut"
		return res
	if station_type == "stove" and not enabled:
		res["msg"] = "Kompor mati"
		return res
	if station_type == "stove" and fire:
		# padamkan pakai APAR (place_consumed -> tangan bebas, generic handler)
		if carry and carry.ingredient == "apar":
			extinguish()
			res["place_consumed"] = true
			res["msg"] = "OK padam"
			return res
		res["msg"] = "KEBAKARAN! Ambil APAR!"
		return res
	if station_type == "pass":
		# Jendela Antar: taruh piring jadi di sini (game yang terbangkan).
		if carry != null and carry.is_plate:
			res["msg"] = "pass"
			return res
		res["msg"] = "Taruh piring jadi di sini"
		return res
	if station_type == "cashier":
		res["msg"] = "Kasir otomatis - fokus masak!"
		return res
	if station_type == "plates":
		# rak piring tak terbatas: ambil piring bersih kalau tangan kosong.
		# Boleh juga menaruh 1 piring bersih kosong (hasil cucian bot/pemain).
		if carry == null:
			if stored != null and stored.is_plate and not stored.dirty:
				res["take"] = stored
				stored = null
				_place_visual()
				res["msg"] = "Ambil piring"
				return res
			var p := FoodItem.make_plate()
			res["take"] = p
			res["msg"] = "Ambil piring"
			return res
		elif carry.is_plate and not carry.dirty and carry.plate_contents.is_empty() and stored == null:
			_place(carry)
			res["place_consumed"] = true
			res["msg"] = "Taruh piring bersih"
			return res
		else:
			res["msg"] = "Tangan penuh, taruh dulu di meja"
			return res
	# meja generik: cutting / stove / table / sink
	if carry == null:
		if stored == null:
			res["msg"] = "Kosong"
			return res
		# ambil dari meja (bahan gosong ikut keambil, buang di sampah)
		res["take"] = stored
		stored = null
		cooking = false
		burning = false
		progress = 0.0
		hide_bar()
		_place_visual()
		res["msg"] = "Ambil: " + str((res["take"] as FoodItem).describe())
		return res
	else:
		if stored != null:
			# gabung ke piring? dua arah
			var msg := _try_merge(carry)
			res["msg"] = msg
			# _try_merge mengatur place_consumed via flag internal? sederhanakan:
			# kalau merge sukses, carry habis (kecuali carry adalah piring yg diisi)
			if msg.begins_with("OK"):
				if carry.is_plate:
					res["place_consumed"] = false
				else:
					res["place_consumed"] = true
			return res
		# taruh di meja kosong
		# kompor: hanya bahan cincang yang belum matang (spec: chopped -> cooked)
		if station_type == "stove":
			if carry.is_plate:
				res["msg"] = "Piring tidak bisa dimasak!"
				return res
			if carry.burnt:
				res["msg"] = "Sudah gosong, buang!"
				return res
			if not carry.chopped:
				res["msg"] = "Harus dicincang dulu!"
				return res
			if carry.cooked:
				res["msg"] = "Sudah matang!"
				return res
		if station_type == "sink" and not carry.is_plate:
			res["msg"] = "Sink hanya untuk piring kotor!"
			return res
		_place(carry)
		res["place_consumed"] = true
		if station_type == "stove" and not carry.is_plate:
			cooking = true
			progress = 0.0
			burning = false
			burn_timer = 0.0
			res["msg"] = "Memasak..."
		else:
			res["msg"] = "Taruh: " + carry.describe()
		return res

func _place(f: FoodItem) -> void:
	stored = f
	progress = 0.0
	hide_bar()
	_place_visual()

func _place_visual() -> void:
	# tempelkan visual item di atas meja
	if stored:
		if stored.get_parent():
			stored.get_parent().remove_child(stored)
		add_child(stored)
		stored.position = Vector3(0, top_y, 0)
	emit_signal("changed")

func force_store(f: FoodItem) -> void:
	_place(f)

func take_stored() -> FoodItem:
	var f := stored
	stored = null
	if f and f.get_parent() == self:
		remove_child(f)
	cooking = false
	burning = false
	progress = 0.0
	neglect_t = 0.0
	hide_bar()
	# meja plating selalu restok piring kosong (gabung rak + meja)
	if station_type == "plating":
		var np := FoodItem.make_plate()
		force_store(np)
	return f

# Gabung bahan ke piring (salah satu di tangan, satu di meja).
# Syarat longgar di sini (cincang saja); validasi resep penuh saat Antar.
func _try_merge(carry: FoodItem) -> String:
	# APAR bukan makanan: jangan pernah gabung ke piring.
	if carry.ingredient == "apar" or (stored and not stored.is_plate and stored.ingredient == "apar"):
		return "Itu APAR! Bawa ke api."
	var plate: FoodItem = null
	var bahan: FoodItem = null
	if carry.is_plate and stored and not stored.is_plate:
		plate = carry
		bahan = stored
	elif stored and stored.is_plate and not carry.is_plate:
		plate = stored
		bahan = carry
	else:
		return "Tidak bisa digabung"
	if plate.dirty:
		return "Piring kotor! Cuci dulu"
	if bahan.burnt:
		return "Gosong! Buang dulu"
	# bahan siap saji (roti/keju) boleh mentah; sisanya wajib cincang dulu
	if not bahan.chopped and not LevelData.needs_no_prep(bahan.ingredient):
		return "Belum dicincang! " + bahan.describe()
	for e in plate.plate_contents:
		if str(e.get("item", "")) == bahan.ingredient:
			return "Sudah ada " + bahan.ingredient
	plate.plate_contents.append(bahan.state_snapshot())
	plate.refresh()
	# kalau bahan dari meja, hapus dari meja
	if bahan == stored:
		stored.queue_free()
		stored = null
		_place_visual()
	# kalau bahan dari tangan, game.gd akan free carry (place_consumed)
	return "OK tambah " + bahan.ingredient

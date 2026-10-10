class_name FoodItem
extends Node3D
## Carryable: bahan mentah / olahan / piring isi.

var ingredient: String = ""
var chopped: bool = false
var cooked: bool = false
var burnt: bool = false
var is_plate: bool = false
# isi piring: Array[Dictionary {item, chopped, cooked}] — snapshot saat digabung.
var plate_contents: Array = []
var dirty: bool = false
var mesh_root: Node3D

const PLATE_COLOR := Color(0.92, 0.92, 0.95)

static func make_ingredient(ing_name: String) -> FoodItem:
	var f := FoodItem.new()
	f.ingredient = ing_name
	f.is_plate = false
	f.chopped = false
	f.cooked = false
	f.burnt = false
	return f

static func make_plate() -> FoodItem:
	var f := FoodItem.new()
	f.is_plate = true
	f.ingredient = ""
	f.dirty = false
	return f

# Tabung APAR jinjing: dibawa ke kompor kebakaran, bukan bahan makanan.
static func make_apar() -> FoodItem:
	var f := FoodItem.new()
	f.ingredient = "apar"
	f.is_plate = false
	f.chopped = true
	f.cooked = false
	f.burnt = false
	return f

func _ready() -> void:
	_build_visual()

func describe() -> String:
	if ingredient == "apar":
		return "APAR"
	if is_plate:
		if dirty:
			return "Piring Kotor"
		if plate_contents.is_empty():
			return "Piring Kosong"
		var done := finished_recipe()
		if not done.is_empty():
			return "Piring " + str(done.get("label", "")) + " SIAP!"
		var s := "Piring: "
		for i in range(plate_contents.size()):
			if i > 0:
				s += ", "
			s += str(plate_contents[i].get("item", "?"))
		return s
	var info: String = str(ingredient)
	if chopped:
		info += " (cincang)"
	if cooked:
		info += " (matang)"
	if burnt:
		info += " GOSONG!"
	return info

func state_snapshot() -> Dictionary:
	return {"item": ingredient, "chopped": chopped, "cooked": cooked}

# Resep yang cocok dengan isi piring (buat visual hidangan jadi).
func finished_recipe() -> Dictionary:
	if not is_plate or dirty or plate_contents.is_empty():
		return {}
	for r in LevelData.RECIPES:
		if LevelData.match_recipe(r, plate_contents):
			return r
	return {}

func _dish_glb(recipe_id: String) -> Array:
	# return [file, scale]: salad 0.50m -> 0.7, pan-stew 0.66m -> 0.55
	match recipe_id:
		"salad":
			return ["salad.glb", 0.7]
		"roti_lapis":
			return ["sandwich.glb", 0.6]
		"burger":
			return ["burger-cheese.glb", 0.55]
		"tumis":
			return ["pan-stew.glb", 0.55]
	return ["", 0.0]

func is_ready() -> bool:
	if is_plate:
		return false
	if ingredient == "" or ingredient == "apar":
		return false
	if burnt:
		return false
	var rule: Dictionary = LevelData.INGREDIENTS.get(ingredient, {})
	var need_chop: bool = rule.get("need_chop", false)
	var need_cook: bool = rule.get("need_cook", false)
	if need_chop and not chopped:
		return false
	if need_cook and not cooked:
		return false
	return true

func can_plate() -> bool:
	return (not is_plate) and is_ready()

func refresh() -> void:
	_build_visual()

# Mapping bahan -> file Kenney food-kit (GLB). selada pakai cabbage (kit tidak ada lettuce).
func _glb_path() -> String:
	var base := "res://assets_external/food-kit/Models/GLB format/"
	if is_plate:
		return base + "plate.glb"
	match ingredient:
		"tomat":
			if chopped:
				return base + "tomato-slice.glb"
			return base + "tomato.glb"
		"selada":
			return base + "cabbage.glb"
		"keju":
			if chopped:
				return base + "cheese-cut.glb"
			return base + "cheese.glb"
		"roti":
			return base + "bread.glb"
		"daging":
			if cooked:
				return base + "meat-cooked.glb"
			return base + "meat-raw.glb"
		"sup":
			if cooked:
				return base + "bowl-soup.glb"
			return base + "bowl-broth.glb"
	return ""

func _spawn_dish(file: String, scl: float) -> bool:
	var path := "res://assets_external/food-kit/Models/GLB format/" + file
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path)
	if not (ps is PackedScene):
		return false
	var n: Node3D = (ps as PackedScene).instantiate()
	n.position = Vector3(0, 0.12, 0)
	n.scale = Vector3(scl, scl, scl)
	mesh_root.add_child(n)
	return true

func _spawn_mini(ing: String, pos: Vector3) -> bool:
	var base := "res://assets_external/food-kit/Models/GLB format/"
	var file := ""
	match ing:
		"tomat":
			file = "tomato-slice.glb"
		"selada":
			file = "cabbage.glb"
		"keju":
			file = "cheese-cut.glb"
		"roti":
			file = "bread.glb"
		"daging":
			file = "meat-cooked.glb"
		"sup":
			file = "bowl-soup.glb"
	if file == "" or not ResourceLoader.exists(base + file):
		return false
	var ps := load(base + file)
	if not (ps is PackedScene):
		return false
	var n: Node3D = (ps as PackedScene).instantiate()
	n.position = pos
	var s := 0.5 * float(LevelData.INGREDIENTS.get(ing, {}).get("scl", 1.0))
	n.scale = Vector3(s, s, s)
	mesh_root.add_child(n)
	return true

func _try_spawn_glb() -> bool:
	var path := _glb_path()
	if path == "":
		return false
	if not ResourceLoader.exists(path):
		return false
	var ps := load(path)
	if not (ps is PackedScene):
		return false
	var n: Node3D = (ps as PackedScene).instantiate()
	# Skala konsisten per fungsi: tangan 0.85 x faktor (hasil ~0.3m semua bahan).
	# plate.glb aslinya 0.89m -> skala 0.4 (piring saji ~0.36m).
	var s := 0.85 * float(LevelData.INGREDIENTS.get(ingredient, {}).get("scl", 1.0))
	if is_plate:
		s = 0.4
	n.scale = Vector3(s, s, s)
	n.position = Vector3(0, 0.05, 0)
	mesh_root.add_child(n)
	return true

func _build_visual() -> void:
	if mesh_root and is_instance_valid(mesh_root):
		mesh_root.queue_free()
	mesh_root = Node3D.new()
	add_child(mesh_root)
	# tabung APAR: badan merah + selang hitam + label putih
	if ingredient == "apar":
		_add_cylinder(Vector3(0, 0.18, 0), 0.13, 0.34, Color(0.85, 0.12, 0.10))
		_add_cylinder(Vector3(0, 0.18, 0), 0.135, 0.08, Color(0.95, 0.95, 0.95))
		_add_box(Vector3(0, 0.40, 0), Vector3(0.08, 0.10, 0.08), Color(0.10, 0.10, 0.12))
		_add_box(Vector3(0.10, 0.36, 0), Vector3(0.16, 0.04, 0.04), Color(0.10, 0.10, 0.12))
		return
	# 1. coba aset luar (Kenney GLB). Kalau ada, tambah marker kecil + fallback box tetap berguna.
	var used_glb := _try_spawn_glb()
	if is_plate:
		if not used_glb:
			var pc := PLATE_COLOR
			if dirty:
				pc = Color(0.45, 0.42, 0.38)
			_add_cylinder(Vector3(0, 0.06, 0), 0.34, 0.07, pc)
		else:
			if dirty:
				_add_box(Vector3(0, 0.3, 0), Vector3(0.2, 0.06, 0.2), Color(0.45, 0.42, 0.38))
		# isi piring: kalau cocok resep -> SATU objek hidangan jadi,
		# kalau tidak -> miniatur tiap bahan.
		var done := finished_recipe()
		if not done.is_empty():
			var spec: Array = _dish_glb(str(done.get("id", "")))
			if str(spec[0]) != "" and _spawn_dish(str(spec[0]), float(spec[1])):
				return
		var i := 0
		for entry in plate_contents:
			var iname: String = str(entry.get("item", ""))
			var pos := Vector3(-0.14 + 0.14 * float(i % 2), 0.20, -0.07 + 0.14 * float(i / 2))
			if not _spawn_mini(iname, pos):
				var c: Color = LevelData.INGREDIENTS.get(iname, {}).get("color", Color.WHITE)
				_add_box(pos, Vector3(0.11, 0.08, 0.11), c)
			i += 1
		return
	if used_glb:
		# marker status di atas model: hijau cincang, oranye matang, hitam gosong
		if burnt:
			_add_box(Vector3(0, 0.42, 0), Vector3(0.3, 0.04, 0.3), Color(0.1, 0.08, 0.08))
		else:
			if chopped:
				_add_box(Vector3(0, 0.42, 0), Vector3(0.3, 0.04, 0.3), Color(0.35, 0.9, 0.35))
			if cooked:
				_add_sphere(Vector3(0, 0.48, 0), 0.06, Color(1.0, 0.55, 0.1))
		return
	var c: Color = LevelData.INGREDIENTS.get(ingredient, {}).get("color", Color(1, 1, 1))
	if burnt:
		_add_box(Vector3(0, 0.16, 0), Vector3(0.25, 0.18, 0.25), Color(0.08, 0.07, 0.07))
		return
	if chopped:
		for xi in range(2):
			for zi in range(2):
				_add_box(Vector3(-0.08 + 0.16 * float(xi), 0.08, -0.08 + 0.16 * float(zi)), Vector3(0.13, 0.10, 0.13), c)
	else:
		_add_sphere(Vector3(0, 0.16, 0), 0.17, c)
	if cooked:
		_add_sphere(Vector3(0, 0.34, 0), 0.07, Color(1.0, 0.55, 0.1))

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(color)
	mesh_root.add_child(mi)

func _add_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(color)
	mesh_root.add_child(mi)

func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(color)
	mesh_root.add_child(mi)

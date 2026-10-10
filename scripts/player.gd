class_name PlayerCook
extends CharacterBody3D
## Koki pemain: gerak 8-arah kamera isometric, bawa 1 item, tahan E buat motong/nyuci.

var speed := 5.2
var carry: FoodItem = null
var carry_anchor: Node3D
var visual_root: Node3D
var face_dir := Vector3(0, 0, 1)
var game = null
var chop_sfx_cd := 0.0
var walk_t := 0.0
var work_t := 0.0
var working := false
var test_drive := Vector2.ZERO
var anim: CharAnim
var use_anim := false

const CHEF_MALE := "res://assets_external/characters/Chef_Male.fbx"

func _ready() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	_build_body(Color(0.30, 0.65, 1.0))
	carry_anchor = Node3D.new()
	if use_anim:
		carry_anchor.position = Vector3(0, 1.0, 0.4)
	else:
		carry_anchor.position = Vector3(0, 1.55, 0.45)
	add_child(carry_anchor)

func _build_body(c: Color) -> void:
	# collision tetap kapsul
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.2
	col.shape = cap
	col.position = Vector3(0, 0.7, 0)
	add_child(col)
	# karakter animasi internet (Quaternius CC0), fallback prosedural
	anim = CharAnim.create(CHEF_MALE, 0.75)
	if anim.ok:
		use_anim = true
		visual_root.add_child(anim)
		return
	var skin := Color(1.0, 0.80, 0.60)
	# sepatu kiri-kanan
	_add_box(Vector3(-0.15, 0.08, 0), Vector3(0.22, 0.16, 0.3), Color(0.2, 0.18, 0.22))
	_add_box(Vector3(0.15, 0.08, 0), Vector3(0.22, 0.16, 0.3), Color(0.2, 0.18, 0.22))
	# kaki / celana gelap
	_add_box(Vector3(-0.15, 0.3, 0), Vector3(0.2, 0.3, 0.24), Color(0.25, 0.25, 0.32))
	_add_box(Vector3(0.15, 0.3, 0), Vector3(0.2, 0.3, 0.24), Color(0.25, 0.25, 0.32))
	# badan jaket chef putih + celemek warna pemain
	_add_box(Vector3(0, 0.72, 0), Vector3(0.55, 0.55, 0.36), Color(0.95, 0.95, 0.96))
	_add_box(Vector3(0, 0.68, 0.19), Vector3(0.4, 0.45, 0.04), c)
	# lengan
	_add_box(Vector3(-0.36, 0.75, 0), Vector3(0.16, 0.4, 0.2), Color(0.92, 0.92, 0.94))
	_add_box(Vector3(0.36, 0.75, 0), Vector3(0.16, 0.4, 0.2), Color(0.92, 0.92, 0.94))
	_add_sphere(Vector3(-0.36, 0.52, 0), 0.09, skin)
	_add_sphere(Vector3(0.36, 0.52, 0), 0.09, skin)
	# kepala + hidung
	_add_sphere(Vector3(0, 1.18, 0), 0.22, skin)
	_add_sphere(Vector3(0, 1.16, 0.2), 0.05, Color(0.9, 0.65, 0.5))
	# topi chef: brim + atas mengembang
	_add_cylinder(Vector3(0, 1.38, 0), 0.24, 0.08, Color.WHITE)
	_add_cylinder(Vector3(0, 1.55, 0), 0.27, 0.3, Color.WHITE)

func _mat_simple(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func _add_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat_simple(color)
	visual_root.add_child(mi)

func _add_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat_simple(color)
	visual_root.add_child(mi)

func _add_cylinder(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat_simple(color)
	visual_root.add_child(mi)

func _physics_process(delta: float) -> void:
	if game and game.has_method("is_playing") and not game.is_playing():
		velocity = Vector3.ZERO
		return
	var iv := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if test_drive.length() > 0.01:
		iv = test_drive
	else:
		iv += _pad_move()
	# Kamera di (+x,+z) menghadap origin: layar-atas = (-x,-z), layar-kanan = (+x,-z).
	# iv.x = kanan-kiri, iv.y = bawah-atas, jadi world = (iv.x+iv.y, 0, -iv.x+iv.y).
	var dir := Vector3(iv.x + iv.y, 0, -iv.x + iv.y)
	# normalisasi biar diagonal tidak lebih cepat
	if dir.length() > 1.0:
		dir = dir.normalized()
	if dir.length() > 0.1:
		face_dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	# dash: tahan Shift / tombol B gamepad = 1.5x (tanpa stamina, santai)
	if ((Input.is_key_pressed(KEY_SHIFT) or _pad_dash()) and dir.length() > 0.1):
		velocity.x *= 1.5
		velocity.z *= 1.5
	# gravitasi beneran: jatuh kalau tidak di lantai, nempel kalau di lantai
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
		if velocity.y < -12.0:
			velocity.y = -12.0
	# pengaman: kalau jatuh di bawah dunia (misal spawn meleset), teleport balik
	move_and_slide()
	if global_position.y < -5.0:
		global_position = Vector3(-3, 1.0, 0)
		velocity = Vector3.ZERO
	# hadapkan badan + anim jalan (animasi internet, fallback bob prosedural)
	if dir.length() > 0.1:
		rotation.y = atan2(face_dir.x, face_dir.z)
		if use_anim and anim:
			anim.locomotion(true, carry != null)
		else:
			walk_t += delta * 11.0
			visual_root.position.y = absf(sin(walk_t)) * 0.07
			visual_root.rotation.z = sin(walk_t) * 0.045
	else:
		if use_anim and anim:
			if not working:
				anim.locomotion(false, carry != null)
		else:
			visual_root.position.y = lerpf(visual_root.position.y, 0.0, delta * 10.0)
			visual_root.rotation.z = lerpf(visual_root.rotation.z, 0.0, delta * 10.0)
	# tahan E / tombol A untuk kerja (talenan / wastafel) + anim menunduk
	working = false
	chop_sfx_cd -= delta
	if (Input.is_action_pressed("interact") or _pad_interact_held()) and game:
		var st: Station = game.nearest_station(global_position, face_dir)
		if st and (st.station_type == "chop" or st.station_type == "sink"):
			if st.stored:
				st.hold_work(delta)
				working = true
				work_t += delta * 9.0
				visual_root.rotation.x = 0.16 + sin(work_t) * 0.03
				if use_anim and anim:
					anim.hold("Punch")
				if chop_sfx_cd <= 0.0:
					game.audio.chop()
					chop_sfx_cd = 0.28
	if not working:
		visual_root.rotation.x = lerpf(visual_root.rotation.x, 0.0, delta * 10.0)

func set_carry(f: FoodItem) -> void:
	if carry and is_instance_valid(carry):
		carry.queue_free()
	carry = null
	if f == null:
		return
	carry = f
	if f.get_parent():
		f.get_parent().remove_child(f)
	carry_anchor.add_child(f)
	f.position = Vector3.ZERO

func clear_carry_free() -> void:
	if carry and is_instance_valid(carry):
		carry.queue_free()
	carry = null

func take_carry_out() -> FoodItem:
	var f := carry
	carry = null
	if f and f.get_parent() == carry_anchor:
		carry_anchor.remove_child(f)
	return f

# --- gamepad (stick kiri + D-pad + tombol B dash). Device 0 = pad pertama.
func _pad_active() -> bool:
	return Input.get_connected_joypads().size() > 0

func _pad_move() -> Vector2:
	if not _pad_active():
		return Vector2.ZERO
	var v := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if absf(v.x) < 0.25:
		v.x = 0.0
	if absf(v.y) < 0.25:
		v.y = 0.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_LEFT):
		v.x -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_RIGHT):
		v.x += 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_UP):
		v.y -= 1.0
	if Input.is_joy_button_pressed(0, JOY_BUTTON_DPAD_DOWN):
		v.y += 1.0
	return v

func _pad_dash() -> bool:
	return _pad_active() and Input.is_joy_button_pressed(0, JOY_BUTTON_B)

func _pad_interact_held() -> bool:
	return _pad_active() and Input.is_joy_button_pressed(0, JOY_BUTTON_A)

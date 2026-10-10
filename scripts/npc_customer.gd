class_name NPCCustomer
extends CharacterBody3D
## Pelanggan ruang makan (spec kitchen-prototype.md):
## SPAWN pintu -> TO_QUEUE -> QUEUED -> ORDERING (kasir) -> TO_SEAT
## -> WAIT_FOOD (patience) -> EATING -> PAY_LEAVE (+tip) | LEAVE_ANGRY | LEAVE_CALM.

enum State { TO_QUEUE, QUEUED, ORDERING, TO_SEAT, WAIT_FOOD, EATING, PAY_LEAVE, LEAVE_ANGRY, LEAVE_CALM }

const TUNICS := [Color(0.75, 0.35, 0.3), Color(0.35, 0.5, 0.8), Color(0.45, 0.65, 0.35), Color(0.7, 0.55, 0.3)]

# Variasi pelanggan (semua diverifikasi punya Walk/Idle/SitDown/Punch).
const MODELS := [
	"res://assets_external/characters/Chef_Female.fbx",
	"res://assets_external/characters/Casual_Male.fbx",
	"res://assets_external/characters/Casual_Female.fbx",
	"res://assets_external/characters/Cowboy_Female.fbx",
	"res://assets_external/characters/Doctor_Female_Young.fbx",
	"res://assets_external/characters/Kimono_Male.fbx",
	"res://assets_external/characters/OldClassy_Female.fbx",
	"res://assets_external/characters/Suit_Male.fbx",
	"res://assets_external/characters/Worker_Female.fbx",
]

var game = null
var order: Dictionary = {}
var queue_idx := -1
var seat: Dictionary = {}
var state: int = State.TO_QUEUE
var speed := 2.6
var state_t := 0.0
var bob_t := 0.0
var wps: Array = []
var visual_root: Node3D
var bubble: Label3D
var bubble_cd := 0.0
var color_idx := 0
var stuck_t := 0.0
var move_t := 0.0
var sidestep_t := 0.0
var sidestep_sign := 1.0
var sidestep_dir := Vector3.ZERO
var _want_move := false
var _last_dir := Vector3(0, 0, 1)
var anim: CharAnim
var use_anim := false
var model_path := "res://assets_external/characters/Chef_Female.fbx"

func setup(g, p_queue: int, tint: int, p_model: String = "") -> void:
	game = g
	queue_idx = p_queue
	color_idx = tint
	if p_model != "":
		model_path = p_model
	var e: Vector2 = game.npc_entrance()
	position = Vector3(e.x, 0.6, e.y)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_retarget_queue()
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.0
	col.shape = cap
	col.position = Vector3(0, 0.6, 0)
	collision_layer = 2   # NPC tembus-menembus sesama NPC
	collision_mask = 1    # tetap tabrak tembok/meja/lantai
	add_child(col)
	visual_root = Node3D.new()
	add_child(visual_root)
	# pelanggan = model acak (variasi!), fallback prosedural
	anim = CharAnim.create(model_path, 0.75)
	if anim.ok:
		use_anim = true
		visual_root.add_child(anim)
	else:
		_build_procedural()
	GameMain.blob_shadow(self, 0.4)
	bubble = Label3D.new()
	bubble.font_size = 40
	bubble.pixel_size = 0.0075
	bubble.position = Vector3(0, 1.75 + float(color_idx % 4) * 0.14, 0)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.outline_size = 8
	bubble.outline_modulate = Color(0, 0, 0, 0.9)
	bubble.modulate = Color(1, 1, 1)
	add_child(bubble)

func _build_procedural() -> void:
	var tunic: Color = TUNICS[color_idx % TUNICS.size()]
	var skin := Color(1.0, 0.82, 0.62)
	_npc_box(Vector3(-0.13, 0.12, 0), Vector3(0.16, 0.24, 0.2), Color(0.25, 0.22, 0.28))
	_npc_box(Vector3(0.13, 0.12, 0), Vector3(0.16, 0.24, 0.2), Color(0.25, 0.22, 0.28))
	_npc_box(Vector3(0, 0.55, 0), Vector3(0.44, 0.5, 0.3), tunic)
	_npc_box(Vector3(-0.3, 0.55, 0), Vector3(0.12, 0.34, 0.16), tunic.darkened(0.15))
	_npc_box(Vector3(0.3, 0.55, 0), Vector3(0.12, 0.34, 0.16), tunic.darkened(0.15))
	_npc_sphere(Vector3(0, 0.98, 0), 0.19, skin)
	_npc_cyl(Vector3(0, 1.12, -0.02), 0.2, 0.16, tunic.darkened(0.25))
	_npc_sphere(Vector3(0, 1.24, -0.02), 0.12, tunic.darkened(0.25))

func short_dish() -> String:
	if order.is_empty():
		return "..."
	var lbl: String = str(order.get("recipe", {}).get("label", "???"))
	var parts := lbl.split(" ")
	if parts.is_empty():
		return lbl
	return parts[0]

# ---- dipanggil game ----

func advance_to(qi: int) -> void:
	queue_idx = qi
	move_t = 0.0
	if state == State.QUEUED or state == State.TO_QUEUE:
		state = State.TO_QUEUE
		_retarget_queue()

func _slot_pos(qi: int) -> Vector3:
	return game.queue_slot_pos(qi)

func _retarget_queue() -> void:
	var sp := _slot_pos(queue_idx)
	# A* pintu -> slot antre (kursi orang lain tetap halangan)
	wps = game.astar_path(global_position, sp)

func start_ordering() -> void:
	state = State.ORDERING
	state_t = 0.0
	bubble.text = "?"

func assign_seat(p_seat: Dictionary, p_order: Dictionary) -> void:
	seat = p_seat
	order = p_order
	move_t = 0.0
	state = State.TO_SEAT
	state_t = 0.0
	# A* ke kursi sendiri (sel kursinya boleh dimasuki)
	var sp: Vector3 = seat["pos"]
	var cell := ProtoConfig.gpos(sp)
	wps = game.astar_path(global_position, sp, cell)
	_refresh_bubble(false)

func start_eating() -> void:
	state = State.EATING
	state_t = 0.0
	bubble.text = "Nyam!"
	bubble.modulate = Color(1.0, 0.85, 0.4)

func pay_and_leave() -> void:
	state = State.PAY_LEAVE
	state_t = 0.0
	move_t = 0.0
	bubble.text = "Makasih!"
	bubble.modulate = Color(1.0, 0.85, 0.3)
	game.free_npc_seat(self)
	_exit_path()

func angry() -> void:
	if state == State.PAY_LEAVE or state == State.LEAVE_ANGRY or state == State.LEAVE_CALM:
		return
	state = State.LEAVE_ANGRY
	state_t = 0.0
	bubble.text = "Lama!!"
	bubble.modulate = Color(1, 0.3, 0.25)
	game.free_npc_seat(self)

func leave_calm() -> void:
	state = State.LEAVE_CALM
	state_t = 0.0
	move_t = 0.0
	bubble.text = ""
	_exit_path()

func _exit_path() -> void:
	# Pulang via sel pintu (walkable), baru ke titik entrance di luar grid.
	# Langsung ke entrance = garis lurus nabrak meja (goal di luar grid).
	var e: Vector2 = game.npc_entrance()
	var d := ProtoConfig.door_cell()
	wps = game.astar_path(global_position, ProtoConfig.wpos(d.x, d.y))
	wps.append(Vector3(e.x, 0, e.y))

# ---- loop ----

func _physics_process(delta: float) -> void:
	if game == null or not game.is_playing():
		velocity = Vector3.ZERO
		return
	state_t += delta
	# watchdog: state jalan yg macet > 25 dtk -> buang (antrean tak boleh mati)
	if state == State.TO_QUEUE or state == State.TO_SEAT or state == State.PAY_LEAVE or state == State.LEAVE_CALM:
		move_t += delta
		if move_t > 25.0:
			game._npc_gone(self)
			return
	else:
		move_t = 0.0
	bob_t += delta * 9.0
	match state:
		State.TO_QUEUE:
			if _step_path(delta):
				state = State.QUEUED
				state_t = 0.0
				velocity.x = 0.0
				velocity.z = 0.0
		State.QUEUED:
			velocity.x = 0.0
			velocity.z = 0.0
			visual_root.position.y = absf(sin(bob_t)) * 0.04
			_face_cashier()
		State.ORDERING:
			velocity.x = 0.0
			velocity.z = 0.0
			_face_cashier()
			if state_t > 1.5:
				game._npc_ordered(self)
		State.TO_SEAT:
			if _step_path(delta, 0.3):
				state = State.WAIT_FOOD
				state_t = 0.0
				velocity.x = 0.0
				velocity.z = 0.0
				_sit(true)
				if use_anim and anim:
					anim.play_named("SitDown")
		State.WAIT_FOOD:
			velocity.x = 0.0
			velocity.z = 0.0
			visual_root.position.y = 0.0 + absf(sin(bob_t)) * 0.03
			_face_table()
			bubble_cd -= delta
			if bubble_cd <= 0.0:
				bubble_cd = 0.5
				var tleft := float(order.get("time_left", 99.0))
				_refresh_bubble(tleft < 20.0)
				if tleft < 20.0:
					visual_root.position.y = 0.0 + absf(sin(bob_t * 2.0)) * 0.08
		State.EATING:
			velocity.x = 0.0
			velocity.z = 0.0
			visual_root.position.y = 0.0 + absf(sin(state_t * 8.0)) * 0.06
			_face_table()
		State.PAY_LEAVE, State.LEAVE_CALM:
			_sit(false)
			if _step_path(delta):
				game._npc_gone(self)
				return
		State.LEAVE_ANGRY:
			_sit(false)
			visual_root.rotation.z = sin(state_t * 20.0) * 0.12
			if state_t > 1.2:
				visual_root.rotation.z = 0.0
				state = State.PAY_LEAVE
				_exit_path()
	# gravitasi
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
	# sidestep darurat saat kejepit sudut
	if sidestep_t > 0.0:
		sidestep_t -= delta
		velocity.x = sidestep_dir.x * speed
		velocity.z = sidestep_dir.z * speed
	move_and_slide()
	var hv := Vector2(velocity.x, velocity.z).length()
	if _want_move and hv < 0.6 and is_on_floor():
		stuck_t += delta
	else:
		stuck_t = 0.0
	if stuck_t > 0.5:
		stuck_t = 0.0
		sidestep_t = 0.8
		sidestep_sign = -sidestep_sign
		sidestep_dir = Vector3(-_last_dir.z * sidestep_sign, 0, _last_dir.x * sidestep_sign)
		if sidestep_dir.length() < 0.1:
			sidestep_dir = Vector3(0, 0, sidestep_sign)
	_want_move = false
	if use_anim and anim:
		# saat duduk biarkan pose SitDown; selain itu ikut gerak
		if state != State.WAIT_FOOD and state != State.EATING:
			var hv2 := Vector2(velocity.x, velocity.z).length()
			anim.locomotion(hv2 > 0.5, false)
	if global_position.y < -5.0:
		game._npc_gone(self)

func _sit(on: bool) -> void:
	if on:
		visual_root.position.y = 0.0
	else:
		visual_root.position.y = 0.0

func _face_cashier() -> void:
	var c: Station = game.cashier_station()
	if c:
		var d: Vector3 = c.global_position - global_position
		if d.length() > 0.1:
			rotation.y = atan2(d.x, d.z)

func _face_table() -> void:
	if seat.is_empty():
		return
	var d: Vector3 = (seat["table_pos"] as Vector3) - global_position
	if d.length() > 0.1:
		rotation.y = atan2(d.x, d.z)

func _refresh_bubble(urgent: bool) -> void:
	if urgent:
		bubble.text = "! " + short_dish() + " !"
		bubble.modulate = Color(1, 0.45, 0.4)
	else:
		bubble.text = short_dish()
		bubble.modulate = Color(1, 1, 1)

func _step_path(delta: float, arrive: float = 0.5) -> bool:
	if wps.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		_want_move = false
		return true
	var t: Vector3 = wps[0]
	var d: Vector3 = t - global_position
	d.y = 0.0
	if d.length() < arrive:
		wps.pop_front()
		if wps.is_empty():
			velocity.x = 0.0
			velocity.z = 0.0
			_want_move = false
			return true
		return false
	var dir: Vector3 = d.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_last_dir = dir
	_want_move = true
	rotation.y = atan2(dir.x, dir.z)
	visual_root.position.y = absf(sin(bob_t)) * 0.06
	return false

func _npc_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	mi.material_override = m
	visual_root.add_child(mi)

func _npc_sphere(pos: Vector3, radius: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.8
	mi.material_override = m
	visual_root.add_child(mi)

func _npc_cyl(pos: Vector3, radius: float, height: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	mi.material_override = m
	visual_root.add_child(mi)

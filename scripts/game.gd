class_name GameMain
extends Node3D
## Main orchestrator: bangun dapur 2.5D, kamera isometric, player, bot, order, UI.

var audio: AudioManager
var orders: OrderManager
var hud: HUD
var player: PlayerCook
var bots: Array = []
var stations: Array = []
var level_idx := 0
var level: Dictionary = {}
var playing := false
var paused := false
var level_root: Node3D
var floor_root: Node3D
var cam: Camera3D
var torch_lights: Array = []
var torch_t := 0.0
var env_node: WorldEnvironment
var countdown := 0.0
var _last_count := 0
var in_menu := true
var popups: Array = []
var orbit_a := 0.0
var npcs: Array = []
var queue: Array = [null, null, null]
var seats: Array = []
var flying: Array = []
var eating: Array = []
var doors: Array = []
var elapsed := 0.0
var spawn_cd := 6.0
var fired_events: Array = []
var fire_sec := 0.0
var target_ring: MeshInstance3D
var cam_offset := Vector3(13, 15, 10.5)
var cam_focus := Vector3(-2, 0, 0.5)

const BOT_COST := 50
const BOT_COST_2 := 150   # bot kedua lebih mahal (ukur: 1 bot ≈ pemain veteran)
const INTERACT_DIST := 2.4
const FURN := "res://assets_external/furniture-kit/Models/GLB format/"
const FOOD := "res://assets_external/food-kit/Models/GLB format/"
const DUNG := "res://assets_external/modular-dungeon-kit/Models/GLB format/"

func _ready() -> void:
	# game root selalu jalan (biar bisa unpause + countdown), gameplay di bawahnya pausable
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_camera_light()
	audio = AudioManager.new()
	add_child(audio)
	orders = OrderManager.new()
	orders.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(orders)
	orders.orders_changed.connect(_on_orders_changed)
	orders.score_changed.connect(_on_score_changed)
	orders.game_over.connect(_on_game_over)
	orders.order_added.connect(_on_order_added)
	orders.order_expired.connect(_on_order_expired)
	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	# backdrop menu: load level 1 visual tapi belum main
	load_level_visual(0)
	hud.show_menu()

func is_playing() -> bool:
	return playing and not paused

# ---------- setup dunia ----------

func _build_camera_light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.light_energy = 1.0
	# shadow MATI (Intel iGPU lag parah kalau nyala) — ganti fake AO: lingkaran gelap di bawah tiap station
	sun.shadow_enabled = false
	add_child(sun)
	var amb := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.06, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.53, 0.65)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# glow MATI (bloom berat di iGPU). Emissive tetap menyala tanpa bloom.
	env.glow_enabled = false
	amb.environment = env
	add_child(amb)
	env_node = amb
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12.0
	cam.position = Vector3(11, 15, 11)
	add_child(cam)
	cam.look_at(Vector3(-2, 0, 0.5))
	cam.current = true
	cam_offset = cam.position - Vector3(-2, 0, 0.5)
	cam_focus = Vector3(-2, 0, 0.5)

func _mat(c: Color, emit: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m

# Blob shadow murah (pengganti real shadow yang dimatikan demi perf).
static func blob_shadow(parent: Node3D, r: float) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.02
	mi.mesh = cm
	mi.position = Vector3(0, 0.03, 0)
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0, 0, 0, 0.35)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	parent.add_child(mi)

func clear_level() -> void:
	if level_root and is_instance_valid(level_root):
		level_root.queue_free()
	stations.clear()
	for b in bots:
		if is_instance_valid(b):
			b.queue_free()
	bots.clear()
	npcs.clear()
	queue = [null, null, null]
	seats.clear()
	flying.clear()
	eating.clear()
	target_ring = null
	popups.clear()
	if player and is_instance_valid(player):
		player.queue_free()
	player = null
	# tunggu 1 frame biar queue_free kelar? pakai remove langsung aman karena rebuild setelahnya
	level_root = null
	floor_root = null

func load_level_visual(idx: int) -> void:
	clear_level()
	level_idx = idx
	level = LevelData.LEVELS[idx]
	queue = [null, null, null]
	_init_seats()
	flying.clear()
	doors.clear()
	level_root = Node3D.new()
	level_root.name = "Level"
	add_child(level_root)
	floor_root = Node3D.new()
	level_root.add_child(floor_root)
	_build_floor()
	_build_walls()
	_build_dining()
	_build_stations()
	_spawn_player()

func _init_seats() -> void:
	seats.clear()
	for t in ProtoConfig.active_tables():
		var tp: Array = t["pos"]
		var tw := ProtoConfig.wpos(int(tp[0]), int(tp[1]))
		for s in t["seats"]:
			seats.append({"table": str(t["id"]), "pos": ProtoConfig.wpos(int(s[0]), int(s[1])), "table_pos": tw, "taken": false, "taken_by": null})

func npc_entrance() -> Vector2:
	var d := ProtoConfig.door_cell()
	var w := ProtoConfig.wpos(d.x, d.y)
	return Vector2(w.x, w.z + 0.7)

func _build_floor() -> void:
	torch_lights.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234 + level_idx * 999
	for gy in range(ProtoConfig.H):
		for gx in range(ProtoConfig.W):
			var t := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.98, 0.2, 0.98)
			t.mesh = bm
			var wp := ProtoConfig.wpos(gx, gy)
			t.position = Vector3(wp.x, -0.1, wp.z)
			# warna lantai per zona: coklat=bahan, merah=masak, kuning=rakit, biru=makan
			var v := rng.randf_range(-0.02, 0.03)
			var base := Color(0.42, 0.24, 0.20)
			match ProtoConfig.floor_zone(gx, gy):
				"bahan":
					base = Color(0.45 + v, 0.31 + v, 0.20 + v)
				"masak":
					base = Color(0.44 + v, 0.22 + v, 0.22 + v)
				"rakit":
					base = Color(0.52 + v, 0.44 + v, 0.26 + v)
				"makan":
					base = Color(0.24 + v, 0.30 + v, 0.46 + v)
			if rng.randf() < 0.06:
				base = base.darkened(0.12)
			t.material_override = _mat(base)
			floor_root.add_child(t)
	# tanah gelap raksasa di bawah arena (void biar background rapi dari semua sudut)
	var void_plane := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(80.0, 0.1, 80.0)
	void_plane.mesh = vm
	void_plane.position = Vector3(0, -0.35, 0)
	void_plane.material_override = _mat(Color(0.06, 0.055, 0.10))
	floor_root.add_child(void_plane)
	# collision lantai 16x8
	var floor_body := StaticBody3D.new()
	floor_body.name = "FloorBody"
	floor_body.position = Vector3(0, -0.25, 0)
	var fcol := CollisionShape3D.new()
	var fshape := BoxShape3D.new()
	fshape.size = Vector3(13.0, 0.5, 13.0)
	fcol.shape = fshape
	floor_body.add_child(fcol)
	floor_root.add_child(floor_body)

func _wall_box(pos: Vector3, size: Vector3, c: Color, cap_c: Color = Color(0, 0, 0, 0)) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	level_root.add_child(mi)
	# cap batu terang di atas tembok
	var cap := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(size.x + 0.1, 0.12, size.z + 0.1)
	cap.mesh = cm
	cap.position = pos + Vector3(0, size.y / 2.0 + 0.06, 0)
	if cap_c.a <= 0.0:
		cap_c = c.lightened(0.18)
	cap.material_override = _mat(cap_c)
	level_root.add_child(cap)
	var body := StaticBody3D.new()
	body.position = pos
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	level_root.add_child(body)

func _torch(pos: Vector3) -> void:
	# obor: tiang kayu + api emissive + cahaya flicker
	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = 0.06
	pm.height = 1.2
	pole.mesh = pm
	pole.position = pos + Vector3(0, 0.6, 0)
	pole.material_override = _mat(Color(0.35, 0.24, 0.15))
	level_root.add_child(pole)
	var cup := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.11
	cm.bottom_radius = 0.07
	cm.height = 0.14
	cup.mesh = cm
	cup.position = pos + Vector3(0, 1.25, 0)
	cup.material_override = _mat(Color(0.15, 0.12, 0.1))
	level_root.add_child(cup)
	var flame := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.1
	sm.height = 0.24
	flame.mesh = sm
	flame.position = pos + Vector3(0, 1.42, 0)
	flame.material_override = _mat(Color(1.0, 0.55, 0.15), 1.4)
	level_root.add_child(flame)
	var li := OmniLight3D.new()
	li.position = pos + Vector3(0, 1.6, 0)
	li.light_color = Color(1.0, 0.6, 0.25)
	li.light_energy = 0.9
	li.omni_range = 5.0
	level_root.add_child(li)
	torch_lights.append({"light": li, "flame": flame, "seed": randf() * 10.0})

func _glb_decor(path: String, pos: Vector3, scl: float, rot_y: float = 0.0) -> void:
	if path == "" or not ResourceLoader.exists(path):
		return
	var ps := load(path)
	if not (ps is PackedScene):
		return
	var n: Node3D = (ps as PackedScene).instantiate()
	n.position = pos
	n.scale = Vector3(scl, scl, scl)
	n.rotation.y = rot_y
	level_root.add_child(n)

func _build_walls() -> void:
	# tembok ungu tebal + tepi atas terang (acuan dapur.png).
	# Baris depan (selatan, sisi kamera) PENDEK biar tidak nutupi player.
	var wc := Color(0.34, 0.28, 0.48)
	for cell in ProtoConfig.wall_cells():
		var wp := ProtoConfig.wpos(cell.x, cell.y)
		var h := 0.9
		if cell.y == 11:
			h = 0.35
		elif cell.y == 7:
			h = 0.6
		_wall_box(Vector3(wp.x, h / 2.0, wp.z), Vector3(1.0, h, 1.0), wc)
	# trim warna zona di tepi lantai tiap station (bukan tembok, bukan label besar)
	_build_trims()
	# obor di 4 sudut DALAM bangunan (yang luar dihapus: ga ada fungsinya)
	for tp in [Vector3(-4.5, 0, -4.5), Vector3(4.5, 0, -4.5), Vector3(-4.5, 0, 4.5), Vector3(6.5, 0, 4.5)]:
		_torch(tp)
	# keset pintu NPC
	var dc := ProtoConfig.door_cell()
	var dw := ProtoConfig.wpos(dc.x, dc.y)
	_door_mat(Vector3(dw.x, 0.03, dw.z))
	if env_node:
		var e: Environment = env_node.environment
		e.ambient_light_color = Color(0.55, 0.53, 0.65)
		e.background_color = Color(0.07, 0.06, 0.11)

func _build_trims() -> void:
	# bingkai tipis emissive di lantai sekeliling sel station, warna per area
	for s in ProtoConfig.STATIONS:
		var p: Array = s["pos"]
		var wp := ProtoConfig.wpos(int(p[0]), int(p[1]))
		var c: Color = ProtoConfig.TRIM.get(str(s["kind"]), Color(0.6, 0.6, 0.65))
		var y := 0.025
		var t := 0.07
		_trim_box(Vector3(wp.x, y, wp.z - 0.5), Vector3(1.0, 0.02, t), c)
		_trim_box(Vector3(wp.x, y, wp.z + 0.5), Vector3(1.0, 0.02, t), c)
		_trim_box(Vector3(wp.x - 0.5, y, wp.z), Vector3(t, 0.02, 1.0), c)
		_trim_box(Vector3(wp.x + 0.5, y, wp.z), Vector3(t, 0.02, 1.0), c)

func _trim_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c, 0.9)
	level_root.add_child(mi)

func _door_mat(pos: Vector3) -> void:
	var mat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 0.05, 1.2)
	mat.mesh = bm
	mat.position = pos
	mat.material_override = _mat(Color(0.30, 0.16, 0.14))
	level_root.add_child(mat)

func _build_stations() -> void:
	for s in ProtoConfig.STATIONS:
		var st := Station.new()
		st.process_mode = Node.PROCESS_MODE_PAUSABLE
		var p: Array = s["pos"]
		var wp := ProtoConfig.wpos(int(p[0]), int(p[1]))
		var stype := str(s["kind"])
		if stype == "crate":
			stype = "crate_" + str(s["item"])
		st.setup(stype, Vector2(wp.x, wp.z), bool(s.get("active", true)))
		level_root.add_child(st)
		stations.append(st)
		blob_shadow(st, 0.7)

func _build_dining() -> void:
	# meja makan + kursi aktif saja (T3/T4 MVP nonaktif, tidak dibangun)
	for t in ProtoConfig.active_tables():
		var tp: Array = t["pos"]
		var wp := ProtoConfig.wpos(int(tp[0]), int(tp[1]))
		_dining_table(wp)
		for s in t["seats"]:
			var sp := ProtoConfig.wpos(int(s[0]), int(s[1]))
			var face := 1.5708
			if sp.x > wp.x:
				face = -1.5708
			# chair.glb ukurannya 0.2m -> skala 2.2 (kursi ~0.44m, sejajar NPC)
			_glb_decor(FURN + "chair.glb", Vector3(sp.x, 0, sp.z), 2.2, face)

func _dining_table(wp: Vector3) -> void:
	var wood := Color(0.5, 0.36, 0.24)
	# 4 kaki + papan + taplak putih
	for sx in [-0.4, 0.4]:
		for sz in [-0.4, 0.4]:
			_decor_box(Vector3(wp.x + sx, 0.35, wp.z + sz), Vector3(0.1, 0.7, 0.1), wood)
	_decor_box(Vector3(wp.x, 0.73, wp.z), Vector3(1.0, 0.08, 1.0), wood)
	_decor_box(Vector3(wp.x, 0.79, wp.z), Vector3(0.9, 0.05, 0.9), Color(0.93, 0.92, 0.88))
	# blob di bawah meja
	var blob_holder := Node3D.new()
	blob_holder.position = Vector3(wp.x, 0, wp.z)
	level_root.add_child(blob_holder)
	blob_shadow(blob_holder, 0.75)
	# collision biar NPC/player tidak jalan menembus meja
	var body := StaticBody3D.new()
	body.position = Vector3(wp.x, 0.4, wp.z)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.0, 0.8, 1.0)
	col.shape = shape
	body.add_child(col)
	level_root.add_child(body)

func _decor_box(pos: Vector3, size: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(c)
	level_root.add_child(mi)

func _spawn_player() -> void:
	player = PlayerCook.new()
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.game = self
	player.position = _free_spawn(ProtoConfig.wpos(ProtoConfig.SPAWN[0], ProtoConfig.SPAWN[1]) + Vector3(0, 0.6, 0))
	level_root.add_child(player)
	blob_shadow(player, 0.45)

func _free_spawn(prefer: Vector3) -> Vector3:
	var cands: Array = [prefer, prefer + Vector3(1, 0, 0), prefer + Vector3(-1, 0, 0), prefer + Vector3(0, 0, 1)]
	for c in cands:
		var ok := true
		for st in stations:
			if Vector2(st.position.x - c.x, st.position.z - c.z).length() < 1.2:
				ok = false
				break
		if ok:
			return c
	return prefer

# ---------- flow ----------

func start_level(idx: int) -> void:
	load_level_visual(idx)
	get_tree().paused = false
	paused = false
	playing = false
	in_menu = false
	countdown = 3.0
	_last_count = 4
	elapsed = 0.0
	spawn_cd = 8.0
	fired_events = []
	# order & klaim lama jangan bocor ke run baru (countdown 3 dtk sebelum orders mulai)
	orders.active_orders.clear()
	claims.clear()
	junk_timer.clear()
	fire_sec = 0.0
	orders.stop()
	orders.emit_signal("orders_changed")
	# kamera snap ke pemain (follow mulai dari sini)
	if cam and player:
		cam_focus = _clamp_focus(player.global_position)
		cam.position = cam_focus + cam_offset
		cam.look_at(cam_focus)
	hud.show_hud()
	audio.order_up()

func restart_level() -> void:
	start_level(level_idx)

func to_menu() -> void:
	playing = false
	paused = false
	countdown = 0.0
	get_tree().paused = false
	orders.stop()
	load_level_visual(0)
	in_menu = true
	hud.show_menu()

func toggle_pause() -> void:
	if countdown > 0.0 or not playing:
		return
	paused = not paused
	get_tree().paused = paused
	hud.show_pause(paused)

const SAVE_PATH := "user://overcooked_dungeon.cfg"

func save_best(idx: int, score: int, stars: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var ks := "best_score_%d" % idx
	if score > int(cfg.get_value("best", ks, 0)):
		cfg.set_value("best", ks, score)
		cfg.set_value("best", "best_stars_%d" % idx, stars)
		cfg.save(SAVE_PATH)
		return true
	return false

func load_best(idx: int) -> Array:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	return [int(cfg.get_value("best", "best_score_%d" % idx, 0)), int(cfg.get_value("best", "best_stars_%d" % idx, 0))]

func _on_orders_changed() -> void:
	if hud:
		hud.refresh_orders(orders.active_orders)

func _on_score_changed(_s: int) -> void:
	pass

func _on_game_over(score: int, stars: int) -> void:
	playing = false
	audio.fail()
	var rekor := save_best(level_idx, score, stars)
	hud.show_over(score, stars, str(level.get("name", "")), rekor)

func _on_order_added(_order: Dictionary) -> void:
	# Order lahir di kasir (NPC sudah antre duluan). Bunyikan saja.
	audio.order_up()

func _on_order_expired(order: Dictionary) -> void:
	release_uid(int(order.get("uid", 0)))
	var npc = order.get("npc", null)
	if npc and is_instance_valid(npc):
		npc.angry()

func _npc_gone(npc: NPCCustomer) -> void:
	for i in range(queue.size()):
		if queue[i] == npc:
			queue[i] = null
	free_npc_seat(npc)
	npcs.erase(npc)
	if is_instance_valid(npc):
		npc.queue_free()

func free_npc_seat(npc: NPCCustomer) -> void:
	for s in seats:
		if s.get("taken_by") == npc:
			s["taken"] = false
			s["taken_by"] = null

# ---------- sistem antre + kursi + spawn NPC ----------

func queue_slot_pos(qi: int) -> Vector3:
	var q: Array = ProtoConfig.queue_slots()
	var c: Array = q[clampi(qi, 0, q.size() - 1)]
	return ProtoConfig.wpos(int(c[0]), int(c[1]))

func free_queue_idx() -> int:
	for i in range(queue.size()):
		if queue[i] == null:
			return i
	return -1

func free_seat() -> Dictionary:
	for s in seats:
		if not bool(s.get("taken", false)):
			return s
	return {}

func try_spawn_npc() -> void:
	var qi := free_queue_idx()
	if qi < 0:
		return
	if free_seat().is_empty():
		return
	var npc := NPCCustomer.new()
	var mp: String = NPCCustomer.MODELS[randi() % NPCCustomer.MODELS.size()]
	npc.setup(self, qi, npcs.size() + int(Time.get_ticks_msec() % 100), mp)
	level_root.add_child(npc)
	npcs.append(npc)
	queue[qi] = npc

func advance_queue() -> void:
	# slot 0 kosong (NPC-nya ke kursi): majukan yang belakang
	queue[0] = null
	for i in [1, 2]:
		var n = queue[i]
		queue[i] = null
		if n and is_instance_valid(n):
			queue[i - 1] = n
			n.advance_to(i - 1)

func spawn_interval() -> float:
	# 15-25 detik acak, makin cepat tiap menit
	var base := float(level.get("spawn_base", 22.0))
	return maxf(9.0, base + randf_range(-3.0, 3.0) - elapsed_min() * 4.0)

func elapsed_min() -> float:
	return elapsed / 60.0

# Dipanggil NPC selesai memesan di kasir (slot 0).
func _npc_ordered(npc: NPCCustomer) -> void:
	if npc.queue_idx != 0:
		npc.leave_calm()
		return
	var seat := free_seat()
	if seat.is_empty():
		npc.leave_calm()
		queue[0] = null
		advance_queue()
		return
	var ids: Array = level.get("recipes", ["salad"])
	var rid: String = str(ids[randi() % ids.size()])
	seat["taken"] = true
	seat["taken_by"] = npc
	var order: Dictionary = orders.spawn_recipe(rid, str(seat["table"]))
	order["npc"] = npc
	npc.assign_seat(seat, order)
	audio.order_up()
	advance_queue()

# ---------- query buat player & bot ----------

# Station target = yang bersebelahan (<=1.9m) dan paling searah hadap.
func nearest_station(observer: Vector3, direction: Vector3) -> Station:
	var fwd := Vector3(direction.x, 0, direction.z)
	if fwd.length() < 0.01:
		return null
	fwd = fwd.normalized()
	var best: Station = null
	var best_d := 9999.0
	for st in stations:
		var to: Vector3 = st.global_position - observer
		to.y = 0.0
		var dist := to.length()
		if dist > 1.9 or dist < 0.01:
			continue
		if fwd.dot(to.normalized()) < 0.6:
			continue
		if dist < best_d:
			best_d = dist
			best = st
	return best

# Station chop mentah dalam radius (buat bantuan bot).
func chop_station_near(pos: Vector3, radius: float) -> Station:
	for st in stations:
		if st.station_type == "chop" and st.stored and not st.stored.is_plate and not st.stored.chopped and LevelData.needs_chop(st.stored.ingredient):
			if pos.distance_to(st.global_position) < radius:
				return st
	return null

# ---------- A* grid pathfinding (spec: NPC jalan pakai A*) ----------

func astar_blocked(gx: int, gy: int, allow_chair := Vector2i(-999, -999)) -> bool:
	if ProtoConfig.is_wall(gx, gy):
		return true
	for st in stations:
		if ProtoConfig.gpos(st.global_position) == Vector2i(gx, gy):
			return true
	for t in ProtoConfig.active_tables():
		var tp: Array = t["pos"]
		if int(tp[0]) == gx and int(tp[1]) == gy:
			return true
	for s in seats:
		if ProtoConfig.gpos(s["pos"]) == Vector2i(gx, gy):
			if Vector2i(gx, gy) == allow_chair:
				continue
			return true
	return false

func astar_path(from_w: Vector3, to_w: Vector3, allow_chair := Vector2i(-999, -999)) -> Array:
	var start := ProtoConfig.gpos(from_w)
	var goal := ProtoConfig.gpos(to_w)
	if start == goal:
		return [to_w]
	var open: Array = [start]
	var came := {}
	var gs := {start: 0.0}
	var guard := 0
	while not open.is_empty() and guard < 2000:
		guard += 1
		var bi := 0
		var bf := _as_f(open[0], goal, gs)
		for i in range(1, open.size()):
			var f := _as_f(open[i], goal, gs)
			if f < bf:
				bf = f
				bi = i
		var cur: Vector2i = open[bi]
		if cur == goal:
			return _as_build(came, cur, to_w)
		open.remove_at(bi)
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nb := Vector2i(cur.x + dx, cur.y + dy)
				if astar_blocked(nb.x, nb.y, allow_chair):
					continue
				if dx != 0 and dy != 0:
					if astar_blocked(cur.x + dx, cur.y, allow_chair):
						continue
					if astar_blocked(cur.x, cur.y + dy, allow_chair):
						continue
				var step := 1.4142 if (dx != 0 and dy != 0) else 1.0
				var ng: float = float(gs.get(cur, 99999.0)) + step
				if ng < float(gs.get(nb, 99999.0)):
					gs[nb] = ng
					came[nb] = cur
					if not (nb in open):
						open.append(nb)
	return [to_w]

func _as_f(c: Vector2i, goal: Vector2i, gs: Dictionary) -> float:
	var dx := float(c.x - goal.x)
	var dy := float(c.y - goal.y)
	return float(gs.get(c, 99999.0)) + sqrt(dx * dx + dy * dy)

func _as_build(came: Dictionary, cur: Vector2i, to_w: Vector3) -> Array:
	var cells: Array = [cur]
	var guard := 0
	while came.has(cells[0]) and guard < 500:
		guard += 1
		cells.push_front(came[cells[0]])
	var pts: Array = []
	var last_dir := Vector2i(999, 999)
	for i in range(1, cells.size()):
		var d: Vector2i = cells[i] - cells[i - 1]
		if i == 1:
			last_dir = d
		elif d != last_dir:
			pts.append(Vector3(float(cells[i - 1].x) - 5.5, 0, float(cells[i - 1].y) - 5.5))
			last_dir = d
	pts.append(to_w)
	return pts

func find_free_station(t: String) -> Station:
	for st in stations:
		if st.station_type == t and st.stored == null:
			return st
	return null

func find_crate(ing: String) -> Station:
	for st in stations:
		if st.station_type == "crate_" + ing:
			return st
	return null

func find_plate_rack() -> Station:
	for st in stations:
		if st.station_type == "plates":
			return st
	return null

func find_trash() -> Station:
	for st in stations:
		if st.station_type == "trash":
			return st
	return null

func needed_ingredient() -> String:
	# hitung bahan yg kurang dari order aktif
	var need_count := {}
	for o in orders.active_orders:
		var needs: Array = o["recipe"].get("needs", [])
		for n in needs:
			var nm := str(n.get("item", ""))
			need_count[nm] = int(need_count.get(nm, 0)) + 1
	# kurangi yg sudah ada di meja / tangan player / bot (termasuk isi piring rakitan)
	for st in stations:
		if st.stored and (st.stored.is_plate or st.stored.ingredient != ""):
			if st.stored.is_plate:
				# isi piring yg sudah dirakit ikut dihitung
				for c in st.stored.plate_contents:
					var kp: String = str(c.get("item", ""))
					if need_count.has(kp):
						need_count[kp] = int(need_count[kp]) - 1
			elif not st.stored.is_plate:
				var k: String = str(st.stored.ingredient)
				if need_count.has(k):
					need_count[k] = int(need_count[k]) - 1
	if player and player.carry and not player.carry.is_plate and player.carry.ingredient != "":
		var k2: String = str(player.carry.ingredient)
		if need_count.has(k2):
			need_count[k2] = int(need_count[k2]) - 1
	for b in bots:
		if is_instance_valid(b) and b.carry and not b.carry.is_plate and b.carry.ingredient != "":
			var k3: String = str(b.carry.ingredient)
			if need_count.has(k3):
				need_count[k3] = int(need_count[k3]) - 1
	for k in need_count.keys():
		if int(need_count[k]) > 0:
			return str(k)
	return ""

# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if playing and not paused:
			do_interact()
	elif event.is_action_pressed("bot_call"):
		if playing and not paused:
			recruit_bot()
	elif event.is_action_pressed("ui_cancel"):
		toggle_pause()
	elif event is InputEventJoypadButton and event.pressed:
		# gamepad Xbox/PS: A ambil/taruh, Y rekrut bot, Start pause (X tidak dipakai)
		match event.button_index:
			JOY_BUTTON_A:
				if playing and not paused:
					do_interact()
			JOY_BUTTON_Y:
				if playing and not paused:
					recruit_bot()
			JOY_BUTTON_START, JOY_BUTTON_BACK:
				toggle_pause()

# Ganti label tombol prompt sesuai device terakhir ([E] keyboard / [A] pad).
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		hud.set_prompt_key("[A]")
	elif event is InputEventKey and event.pressed:
		hud.set_prompt_key("[E]")

# Sajikan piring (plate sudah dilepas dari tangan caller, from_pos = posisi tangan).
# Ok: piring TERBANG ke meja NPC (pelayan), skor + tip. Gagal: caller pegang lagi.
func _serve(plate: FoodItem, at_pos: Vector3, from_pos: Vector3) -> Dictionary:
	var res: Dictionary = orders.deliver(plate)
	if bool(res.get("ok", false)):
		var done_order: Dictionary = res.get("order", {})
		release_uid(int(done_order.get("uid", 0)))
		hud.flash(str(res.get("msg", "OK")))
		audio.success()
		spawn_popup("+" + str(res.get("reward", 0)), at_pos, Color(1.0, 0.85, 0.3))
		# tip cepat relatif terhadap patience order (bukan absolut 45 dtk)
		if float(res.get("time_left", 0.0)) > float(res.get("time_max", 90.0)) * 0.5:
			orders.score += 15
			orders.emit_signal("score_changed", orders.score)
			spawn_popup("+15 tip", at_pos + Vector3(0, 0.4, 0), Color(0.5, 1.0, 0.5))
		var npc = done_order.get("npc", null)
		var tp := table_pos(str(done_order.get("table_id", "")))
		if plate.get_parent():
			plate.get_parent().remove_child(plate)
		level_root.add_child(plate)
		plate.global_position = from_pos
		flying.append({"node": plate, "from": from_pos, "to": tp + Vector3(0, 1.1, 0), "t": 0.0, "dur": 1.2, "npc": npc})
	else:
		hud.flash(str(res.get("msg", "Gagal")))
		audio.fail()
		spawn_popup(str(res.get("msg", "Gagal")), at_pos, Color(1, 0.4, 0.35))
	return res

func table_pos(table_id: String) -> Vector3:
	for t in ProtoConfig.active_tables():
		if str(t["id"]) == table_id:
			var p: Array = t["pos"]
			return ProtoConfig.wpos(int(p[0]), int(p[1]))
	return Vector3(0, 0, 3)

func pass_station() -> Station:
	for st in stations:
		if st.station_type == "pass":
			return st
	return null

func cashier_station() -> Station:
	for st in stations:
		if st.station_type == "cashier":
			return st
	return null

# Piring di meja yang isinya cocok dengan salah satu order aktif.
func find_complete_plate_station() -> Station:
	for st in stations:
		if st.stored and st.stored.is_plate and not st.stored.dirty and not st.stored.plate_contents.is_empty():
			for o in orders.active_orders:
				if LevelData.match_recipe(o["recipe"], st.stored.plate_contents):
					return st
	return null

# ---------- sinkronisasi order <-> bot (klaim + assembly) ----------

var claims := {}  # uid(int) -> {"by": BotHelper, "plate": Station/nil}

func claim_order(bot, uid: int) -> bool:
	_prune_claims()
	if claims.has(uid):
		var holder = claims[uid].get("by", null)
		if holder != null and holder != bot and is_instance_valid(holder):
			return false
	# klaim ulang bot yg sama: reserve piring dipertahankan
	claims[uid] = {"by": bot, "plate": claims.get(uid, {}).get("plate", null)}
	return true

func release_claim(bot) -> void:
	for k in claims.keys():
		if claims[k].get("by", null) == bot:
			claims.erase(k)

func release_uid(uid: int) -> void:
	claims.erase(uid)

# Tandai piring plating untuk uid (lepas otomatis bersama klaim).
func reserve_plate(uid: int, st: Station) -> void:
	if claims.has(uid):
		claims[uid]["plate"] = st

# Piring ini direserve order lain? (reserve sendiri = false)
func _plate_reserved_by_other(st: Station, uid: int) -> bool:
	for k in claims.keys():
		if int(k) != uid and claims[k].get("plate", null) == st:
			return true
	return false

func _prune_claims() -> void:
	for k in claims.keys():
		var holder = claims[k].get("by", null)
		if holder == null or not is_instance_valid(holder):
			claims.erase(k)
		elif orders.get_order(int(k)).is_empty():
			claims.erase(k)
		else:
			var rp = claims[k].get("plate", null)
			if rp != null and not is_instance_valid(rp):
				claims[k]["plate"] = null

func order_assignee(uid: int) -> String:
	_prune_claims()
	if claims.has(uid):
		return "Bot"
	return ""

# Nomor bot (1-based) yg klaim order ini, 0 kalau tak ada. Buat badge kartu order.
func order_bot_idx(uid: int) -> int:
	_prune_claims()
	if claims.has(uid):
		var holder = claims[uid].get("by", null)
		if holder != null and is_instance_valid(holder):
			return bots.find(holder) + 1
	return 0

# Status tiap need: true kalau sudah terpenuhi di piring reserve order ini.
# Buat centang chip bahan di kartu order.
func order_progress(order: Dictionary) -> Array:
	var out: Array = []
	var needs: Array = order.get("recipe", {}).get("needs", [])
	var contents: Array = []
	var uid := int(order.get("uid", 0))
	_prune_claims()
	if claims.has(uid):
		var pst = claims[uid].get("plate", null)
		if pst != null and is_instance_valid(pst) and pst.stored and pst.stored.is_plate and not pst.stored.dirty:
			contents = pst.stored.plate_contents
	for n in needs:
		var hit := false
		for c in contents:
			if LevelData.need_met(n, c):
				hit = true
				break
		out.append(hit)
	return out

# Kursi terisi / total. Buat header "N dari M kursi".
func seats_info() -> Array:
	var taken := 0
	for s in seats:
		if bool(s.get("taken", false)):
			taken += 1
	return [taken, seats.size()]

# Nomor kompor aktif (1-based, urut x) buat banner kebakaran.
func stove_index(st: Station) -> int:
	var act: Array = []
	for s in stations:
		if s.station_type == "stove" and s.enabled:
			act.append(s)
	act.sort_custom(func(a: Station, b: Station) -> bool: return a.global_position.x < b.global_position.x)
	return act.find(st) + 1

# Biaya rekrut bot berikutnya (50/150 bertingkat).
func recruit_cost() -> int:
	return BOT_COST if bots.is_empty() else BOT_COST_2

func matching_order(contents: Array) -> Dictionary:
	for o in orders.active_orders:
		if LevelData.match_recipe(o["recipe"], contents):
			return o
	return {}

func snap_of(f: FoodItem) -> Dictionary:
	return {"item": f.ingredient, "chopped": f.chopped, "cooked": f.cooked}

# need pertama yg belum terpenuhi plate ini untuk order tsb. {} kalau lengkap/tak cocok.
func plan_missing(order: Dictionary, contents: Array) -> Dictionary:
	var needs: Array = order.get("recipe", {}).get("needs", [])
	for n in needs:
		var ok := false
		for c in contents:
			if LevelData.need_met(n, c):
				ok = true
				break
		if not ok:
			return n
	return {}

# plate di meja plating yg cocok untuk order: reserve sendiri dulu, lalu
# parsial-valid, lalu kosong bersih. Piring reserve order lain dilewat.
func plate_for_order(order: Dictionary) -> Station:
	var uid := int(order.get("uid", 0))
	# 0. piring reserve milik uid ini (kalau masih layak)
	var own = claims.get(uid, {}).get("plate", null)
	if own != null and is_instance_valid(own) and own.station_type == "plating" and own.stored != null:
		var p0: FoodItem = own.stored
		if p0.is_plate and not p0.dirty:
			if p0.plate_contents.is_empty():
				return own
			if _plate_partial_ok(order, p0) and not plan_missing(order, p0.plate_contents).is_empty():
				return own
	# 1. parsial yg semua isinya valid untuk order ini + masih ada yg kurang
	for st in stations:
		if st.station_type != "plating" or st.stored == null:
			continue
		if _plate_reserved_by_other(st, uid):
			continue
		var p: FoodItem = st.stored
		if not p.is_plate or p.dirty or p.plate_contents.is_empty():
			continue
		if _plate_partial_ok(order, p) and not plan_missing(order, p.plate_contents).is_empty():
			return st
	# 2. piring kosong bersih (reserve lain dilewat)
	for st in stations:
		if st.station_type != "plating" or st.stored == null:
			continue
		if _plate_reserved_by_other(st, uid):
			continue
		var p2: FoodItem = st.stored
		if p2.is_plate and not p2.dirty and p2.plate_contents.is_empty():
			return st
	return null

# Semua isi piring valid untuk salah satu need order ini?
func _plate_partial_ok(order: Dictionary, p: FoodItem) -> bool:
	for c in p.plate_contents:
		var hit := false
		for n in order.get("recipe", {}).get("needs", []):
			if LevelData.need_met(n, c):
				hit = true
				break
		if not hit:
			return false
	return true

# Talenan berisi bahan MENTAH dgn ingredient cocok (sisa pemain/bot lain).
# Buat adopsi: bot teruskan mencincang sisa ini, bukan ambil baru dari crate.
func raw_board_for(ing: String) -> Station:
	for st in stations:
		if st.station_type == "chop" and st.stored:
			var f: FoodItem = st.stored
			if not f.is_plate and f.ingredient == ing and not f.chopped:
				return st
	return null

# Talenan terdekat dari posisi (buat tunggu aktif di area kerja).
func nearest_chop(pos: Vector3) -> Station:
	var best: Station = null
	var bd := 999999.0
	for st in stations:
		if st.station_type == "chop":
			var d: float = pos.distance_to(st.global_position)
			if d < bd:
				bd = d
				best = st
	return best

# snap cocok dgn salah satu need order yg BELUM terpenuhi isi piring ini?
# Dipakai bot biar bisa merge dini + tidak buang bahan yg masih berguna nanti.
func need_useful(order: Dictionary, contents: Array, snap: Dictionary) -> bool:
	for n in order.get("recipe", {}).get("needs", []):
		var met := false
		for c in contents:
			if LevelData.need_met(n, c):
				met = true
				break
		if not met and LevelData.need_met(n, snap):
			return true
	return false

# ingredient MENTAH masih dibutuhkan order (walau perlu olah dulu)?
# Mentah yg cocok = potensi, jangan dibuang; cincang dulu baru merge.
func need_eventual(order: Dictionary, contents: Array, ing: String) -> bool:
	for n in order.get("recipe", {}).get("needs", []):
		if str(n.get("item", "")) != ing:
			continue
		var met := false
		for c in contents:
			if LevelData.need_met(n, c):
				met = true
				break
		if not met:
			return true
	return false

# talenan ini layak dikerjakan/diambil bot? Ya kalau isinya berguna langsung,
# atau bahan mentah yg item-nya masih dibutuhkan order (adopsi sisa cincang).
func board_relevant(order: Dictionary, contents: Array, f: FoodItem) -> bool:
	if f == null or f.is_plate:
		return false
	if need_useful(order, contents, snap_of(f)):
		return true
	# bahan sudah cincang, belum matang, order masih butuh versi matangnya
	if cook_pending(order, contents, f):
		return true
	if not f.chopped:
		for n in order.get("recipe", {}).get("needs", []):
			var met := false
			for c in contents:
				if LevelData.need_met(n, c):
					met = true
					break
			if not met and str(n.get("item", "")) == f.ingredient:
				return true
	return false

# bahan sudah cincang, belum matang, dan order masih butuh versi matangnya
func cook_pending(order: Dictionary, contents: Array, f: FoodItem) -> bool:
	if f == null or f.is_plate or f.ingredient == "apar":
		return false
	if not f.chopped or f.cooked or f.burnt:
		return false
	return need_cook_for(order, contents, str(f.ingredient))

func cook_ready_board_for(order: Dictionary, contents: Array, ing: String) -> Station:
	for st in stations:
		if st.station_type == "chop" and st.stored and str(st.stored.ingredient) == ing and cook_pending(order, contents, st.stored):
			return st
	return null

# Titik siaga bot saat order kosong: lantai bebas tengah dapur (7,4),
# dekat area kerja tapi tak menghalangi spawn pemain (5,4).
func bot_standby_pos() -> Vector3:
	return ProtoConfig.wpos(7, 4)

# Kompor aktif yg kosong & tak terbakar (buat masak bot/pemain).
func free_stove() -> Station:
	for st in stations:
		if st.station_type == "stove" and st.enabled and st.stored == null and not st.fire:
			return st
	return null

# Kompor yg kebakaran duluan (buat APAR).
func burning_stove() -> Station:
	for st in stations:
		if st.station_type == "stove" and st.fire:
			return st
	return null

var junk_timer := {}  # Station -> detik sudah dianggap junk

# Makanan ini masih diinginkan order aktif? Mentah = masih bisa diolah.
func item_wanted(f: FoodItem) -> bool:
	if f == null or f.burnt:
		return false
	for o in orders.active_orders:
		for n in o.get("recipe", {}).get("needs", []):
			if str(n.get("item", "")) != str(f.ingredient):
				continue
			if LevelData.need_met(n, snap_of(f)):
				return true
			if not f.chopped and not f.cooked:
				return true
			if f.chopped and not f.cooked and bool(n.get("cook", false)):
				return true
	return false

# Piring isi yg tak cocok order mana pun dan tak bisa dipakai lagi.
func plate_orphan(p: FoodItem) -> bool:
	if p == null or not p.is_plate or p.dirty or p.plate_contents.is_empty():
		return false
	if not matching_order(p.plate_contents).is_empty():
		return false
	for o in orders.active_orders:
		var ok := true
		for c in p.plate_contents:
			var hit := false
			for n in o.get("recipe", {}).get("needs", []):
				if LevelData.need_met(n, c):
					hit = true
					break
			if not hit:
				ok = false
				break
		if ok:
			return false
	return true

# Ambang detik sebelum junk boleh diambil janitor, per tipe.
func _junk_threshold(st: Station) -> float:
	match st.station_type:
		"stove":
			return 2.0
		"chop":
			return 10.0
		"plating":
			return 10.0
	return 1e9

func _is_junk(st: Station) -> bool:
	if st.stored == null:
		return false
	match st.station_type:
		"stove":
			return (not st.stored.is_plate) and st.stored.burnt and not st.fire
		"chop":
			return (not st.stored.is_plate) and not item_wanted(st.stored)
		"plating":
			return plate_orphan(st.stored)
	return false

# Stasiun junk yg timernya matang duluan (buat janitor bot).
func junk_station() -> Station:
	for st in stations:
		if _is_junk(st) and float(junk_timer.get(st, 0.0)) >= _junk_threshold(st):
			return st
	return null

# Kompor berisi makanan gosong (buat dibersihkan bot/pemain).
func burnt_stove() -> Station:
	for st in stations:
		if st.station_type == "stove" and st.stored and not st.stored.is_plate and st.stored.burnt:
			return st
	return null

# Meja APAR (tak pernah habis).
func apar_station() -> Station:
	for st in stations:
		if st.station_type == "apar":
			return st
	return null

# ingredient ini masih butuh dimasak utk order (need cook yg belum terpenuhi)?
func need_cook_for(order: Dictionary, contents: Array, ing: String) -> bool:
	for n in order.get("recipe", {}).get("needs", []):
		if str(n.get("item", "")) != ing or not bool(n.get("cook", false)):
			continue
		var met := false
		for c in contents:
			if LevelData.need_met(n, c):
				met = true
				break
		if not met:
			return true
	return false

# bahan staged (talenan/kompor, siap saji) yg fully satisfy need. null kalau tak ada.
func staged_source(need: Dictionary) -> Station:
	for st in stations:
		if (st.station_type == "chop" or st.station_type == "stove") and st.stored:
			var f: FoodItem = st.stored
			if not f.is_plate and f.can_plate() and LevelData.need_met(need, snap_of(f)):
				return st
	return null

# Cari target assembly buat bot: {order, plate, need, via}. {} kalau tak ada yg feasible.
func assembly_target(bot) -> Dictionary:
	_prune_claims()
	for o in orders.active_orders:
		var uid := int(o.get("uid", 0))
		if uid == 0:
			continue
		var holder = claims.get(uid, {}).get("by", null)
		if holder != null and holder != bot and is_instance_valid(holder):
			continue
		var plate := plate_for_order(o)
		if plate == null:
			continue
		var need := plan_missing(o, plate.stored.plate_contents)
		if need.is_empty():
			continue
		# bot hanya kerjakan need yg fully satisfiable: staged, sisa mentah yg bisa
		# diadopsi, masak (kompor kosong), ATAU (chop-only + raw tersedia + talenan kosong)
		if staged_source(need) != null:
			return {"order": o, "plate": plate, "need": need, "via": "staged"}
		if bool(need.get("cook", false)):
			var cing := str(need.get("item", ""))
			if find_crate(cing) != null and free_stove() != null:
				if find_free_station("chop") != null or raw_board_for(cing) != null or cook_ready_board_for(o, plate.stored.plate_contents, cing) != null:
					return {"order": o, "plate": plate, "need": need, "via": "cook"}
			continue
		if not bool(need.get("cook", false)):
			if bool(need.get("chop", false)) and raw_board_for(str(need.get("item", ""))) != null:
				return {"order": o, "plate": plate, "need": need, "via": "adopt"}
			if find_crate(str(need.get("item", ""))) != null and find_free_station("chop") != null:
				return {"order": o, "plate": plate, "need": need, "via": "fetch"}
	return {}

func spawn_popup(text: String, pos: Vector3, c: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.01
	l.position = pos + Vector3(0, 1.2, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = c
	l.outline_size = 12
	l.outline_modulate = Color(0, 0, 0, 0.9)
	level_root.add_child(l)
	popups.append({"node": l, "t": 0.0})

func do_interact() -> void:
	if player == null:
		return
	var st: Station = nearest_station(player.global_position, player.face_dir)
	if st == null:
		hud.flash("Tidak ada meja di depan!")
		return
	# Meja APAR: ambil (tangan kosong) / kembalikan (bawa APAR)
	if st.station_type == "apar":
		if player.carry == null:
			player.set_carry(FoodItem.make_apar())
			audio.pickup()
			hud.flash("Ambil APAR! Bawa ke kompor yg kebakaran.")
		elif player.carry.ingredient == "apar":
			player.clear_carry_free()
			audio.place()
			hud.flash("APAR kembali ke meja.")
		else:
			hud.flash("Tangan penuh!")
		return
	# APAR cuma berguna di kompor api (ditangani station.interact) / mejanya
	if player.carry and player.carry.ingredient == "apar" and st.station_type != "stove":
		hud.flash("APAR hanya untuk api, atau kembalikan ke mejanya.")
		return
	# jendela Antar spesial: sajikan piring jadi (terbang ke meja NPC)
	if st.station_type == "pass" and player.carry != null and player.carry.is_plate:
		var from_p: Vector3 = player.carry.global_position
		var f: FoodItem = player.take_carry_out()
		var res: Dictionary = _serve(f, st.global_position, from_p)
		if not bool(res.get("ok", false)):
			player.set_carry(f)
		return
	var burn_on: bool = bool(level.get("burn_enabled", false))
	var res2: Dictionary = st.interact(player.carry, burn_on)
	var msg := str(res2.get("msg", ""))
	if res2.get("take") != null:
		var f: FoodItem = res2.get("take")
		# lepas dari station kalau masih nempel
		if f.get_parent():
			f.get_parent().remove_child(f)
		player.set_carry(f)
		audio.pickup()
		hud.flash(msg)
	elif bool(res2.get("place_consumed", false)):
		# barang di tangan pindah / habis
		if msg.begins_with("OK"):
			# merge: kalau carry bukan piring, habiskan
			if player.carry and not player.carry.is_plate:
				player.clear_carry_free()
			audio.place()
		elif msg.begins_with("Dibuang"):
			player.clear_carry_free()
			audio.fail()
		elif msg.begins_with("Taruh") or msg.begins_with("Memasak"):
			var f2: FoodItem = player.take_carry_out()
			# station sudah simpan referensi? untuk path taruh-kosong, station._place butuh node.
			# Karena interact() versi taruh tidak pegang node (carry masih di player),
			# kita set manual di sini:
			if st.stored == null and f2:
				st.force_store(f2)
			audio.place()
		else:
			# trash buang gosong dll sudah di-handle? pastikan sinkron
			if st.station_type == "trash" and player.carry:
				player.clear_carry_free()
				audio.fail()
		hud.flash(msg)
	else:
		hud.flash(msg)

func recruit_bot() -> void:
	if bots.size() >= 2:
		hud.flash("Bot maksimal 2!")
		return
	# harga bertingkat: bot pertama 50, kedua 150
	var cost := BOT_COST if bots.is_empty() else BOT_COST_2
	if orders.score < cost:
		hud.flash("Butuh %d poin buat rekrut bot! (skor: %d)" % [cost, orders.score])
		audio.fail()
		return
	orders.score -= cost
	var b := BotHelper.new()
	b.process_mode = Node.PROCESS_MODE_PAUSABLE
	b.game = self
	# spawn geser per bot + cari sel bebas: 2 bot rekrut cepat tidak boleh numpuk
	# (fisika kapsul yg interpenetrasi meledak, bot terlontar ke langit).
	b.position = _free_spawn(player.global_position + Vector3(1.2 + float(bots.size()) * 1.6, 0.6, 0.5))
	level_root.add_child(b)
	bots.append(b)
	blob_shadow(b, 0.45)
	audio.recruit()
	hud.flash("Bot auto siap bantu! (masak + antar)")
	if orders.chaos_level() == 2:
		hud.flash("Bot datang saat caos! Fokus antar, biar bot siapkan bahan.")

# ---------- HUD refresh ----------

func _process(delta: float) -> void:
	# obor flicker selalu (menu pun hidup)
	torch_t += delta
	for t in torch_lights:
		if is_instance_valid(t["light"]):
			(t["light"] as OmniLight3D).light_energy = 0.85 + sin(torch_t * 11.0 + float(t["seed"])) * 0.18
		if is_instance_valid(t["flame"]):
			var f := 1.0 + sin(torch_t * 12.0 + float(t["seed"])) * 0.12
			(t["flame"] as MeshInstance3D).scale = Vector3(f, 1.0, f)
	if hud == null or orders == null:
		return
	# kamera orbit pelan saat di menu utama
	if in_menu and cam:
		orbit_a += delta * 0.18
		cam.position = Vector3(cos(orbit_a) * 15.0, 15.0, sin(orbit_a) * 15.0)
		cam.look_at(Vector3(-2, 0, 0.5))
	elif cam and player and is_instance_valid(player) and not in_menu:
		# kamera follow pemain (smooth), dijepit biar tidak lihat void
		var want := _clamp_focus(player.global_position)
		cam_focus = cam_focus.lerp(want, minf(1.0, delta * 4.0))
		cam.position = cam_focus + cam_offset
		cam.look_at(cam_focus)
	# hitung mundur sebelum order jalan (pemain diam, dapur kelihatan)
	if countdown > 0.0:
		countdown -= delta
		var c := int(ceil(countdown))
		if c != _last_count and c >= 1:
			_last_count = c
			hud.set_countdown(str(c))
			audio.place()
		if countdown <= 0.0:
			countdown = 0.0
			hud.set_countdown("")
			orders.start_level(level)
			playing = true
			paused = false
			hud.flash("MASAK!")
	# popup skor melayang
	if not popups.is_empty():
		var done: Array = []
		for pp in popups:
			if not is_instance_valid(pp["node"]):
				done.append(pp)
				continue
			pp["t"] = float(pp["t"]) + delta
			var n: Label3D = pp["node"]
			n.position.y += delta * 1.1
			var a := 1.0 - float(pp["t"]) / 1.2
			var col: Color = n.modulate
			col.a = clampf(a, 0.0, 1.0)
			n.modulate = col
			if float(pp["t"]) >= 1.2:
				n.queue_free()
				done.append(pp)
		for d in done:
			popups.erase(d)
	# game root ALWAYS jalan: bekukan juga logika main saat pause (node lain
	# PAUSABLE sudah berhenti sendiri). Kalau tidak, timer/event/NPC jalan terus.
	if playing and not paused:
		elapsed += delta
		# kasir: NPC terdepan yang sudah sampai mulai memesan
		var front = queue[0]
		if front and is_instance_valid(front) and front.state == NPCCustomer.State.QUEUED:
			front.start_ordering()
		# spawner NPC: ada slot antre + kursi bebas
		spawn_cd -= delta
		if spawn_cd <= 0.0:
			spawn_cd = spawn_interval()
			try_spawn_npc()
		# event level data-driven (mis. rush hour L2/L3)
		for ev in level.get("events", []):
			var key := str(ev.get("at", -1.0)) + "|" + str(ev.get("kind", ""))
			if key in fired_events:
				continue
			if elapsed >= float(ev.get("at", 1e9)):
				fired_events.append(key)
				if str(ev.get("kind", "")) == "rush":
					try_spawn_npc()
					try_spawn_npc()
					hud.flash("RUSH HOUR! NPC berdatangan!")
					audio.order_up()
		# kebakaran: alarm sekali + skor bocor selama api menyala
		for st in stations:
			if st.station_type == "stove" and st.fire:
				if not st.fire_alarmed:
					st.fire_alarmed = true
					hud.flash("KEBAKARAN! Padamkan dengan APAR!")
					audio.alarm()
				fire_sec += delta
				if fire_sec >= 1.0:
					fire_sec = 0.0
					orders.score = maxi(0, orders.score - 2)
					orders.emit_signal("score_changed", orders.score)
		_update_flying(delta)
		_update_eating(delta)
		# timer junk: akumulasi selama stasiun junk, reset kalau tidak
		for s2 in stations:
			if is_instance_valid(s2) and _is_junk(s2):
				junk_timer[s2] = float(junk_timer.get(s2, 0.0)) + delta
			else:
				junk_timer.erase(s2)
		hud.set_score(orders.score)
		hud.set_time(orders.time_left)
		hud.set_bots(bots.size())
		var info := ""
		if player and player.carry:
			info = "Bawa: " + player.carry.describe()
		else:
			info = "Tangan kosong"
		var st: Station = null
		if player:
			st = nearest_station(player.global_position, player.face_dir)
		if st:
			info += "  |  Depan: " + st.station_label()
			if st.stored:
				info += " (" + st.stored.describe() + ")"
		hud.set_info(info)
		if player and player.carry:
			hud.set_carry(player.carry.describe())
		else:
			hud.set_carry("Kosong")
		hud.set_prompt(_prompt_for(st))
		for s in stations:
			if is_instance_valid(s):
				s.set_highlight(s == st)
				# label hanya dekat pemain (<=2.6m), anti tumpuk
				if s.label3d and is_instance_valid(s.label3d) and player:
					s.label3d.visible = s.global_position.distance_to(player.global_position) < 2.6
		_update_ring(st)

# QoL: kasih tahu tombol apa utk station di depan, sesuai konteks tangan.
func _prompt_for(st: Station) -> String:
	if st == null or player == null:
		return ""
	var carry: FoodItem = player.carry
	match st.station_type:
		"crate_tomat", "crate_selada", "crate_roti", "crate_keju":
			if carry:
				return "Tangan penuh"
			var ing: String = st.station_type.replace("crate_", "")
			return "Ambil " + str(LevelData.INGREDIENTS.get(ing, {}).get("label", ing))
		"chop":
			if st.stored == null:
				return "Taruh bahan di sini" if carry and not carry.is_plate else "Talenan kosong"
			if st.stored.is_plate:
				if carry and not carry.is_plate and carry.chopped:
					return "Tambah ke piring"
				return "Ambil piring"
			if not st.stored.chopped:
				return "TAHAN untuk cincang"
			return "Ambil " + st.stored.describe()
		"stove":
			if st.fire:
				return "KEBAKARAN! Ambil APAR!"
			if not st.enabled:
				return "Kompor mati"
			if st.cooking:
				return "Memasak... tunggu"
			if st.stored:
				if st.stored.burnt:
					return "Gosong! Buang di sampah"
				if st.stored.cooked:
					return "Ambil masakan"
				return "Ambil " + st.stored.describe()
			if carry and not carry.is_plate and carry.chopped and not carry.cooked:
				return "Taruh & masak"
			return "Butuh bahan cincang"
		"plates":
			return "Ambil piring bersih" if carry == null else "Taruh piring"
		"plating":
			if st.stored and st.stored.is_plate:
				if st.stored.plate_contents.is_empty():
					if carry and not carry.is_plate and carry.chopped:
						return "Tambah ke piring"
					return "Piring kosong siap rakit"
				return "Ambil piring jadi"
			return "Ambil piring"
		"pass":
			if carry and carry.is_plate and not carry.dirty and not carry.plate_contents.is_empty():
				return "Sajikan sekarang!"
			return "Bawa piring jadi ke sini"
		"cashier":
			return "Kasir otomatis"
		"sink":
			return "Wastafel tahap lanjut"
		"spice":
			return "Rempah tahap lanjut"
		"trash":
			return "Buang isi tangan" if carry else "Tong sampah"
		"apar":
			if carry and carry.ingredient == "apar":
				return "Kembalikan APAR"
			return "Ambil APAR" if carry == null else "Tangan penuh"
	return ""

func _clamp_focus(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -3.0, 3.0), 0.0, clampf(p.z, -3.0, 3.0))

func _update_ring(st) -> void:
	if target_ring == null or not is_instance_valid(target_ring):
		target_ring = MeshInstance3D.new()
		var rm := CylinderMesh.new()
		rm.top_radius = 0.55
		rm.bottom_radius = 0.55
		rm.height = 0.03
		target_ring.mesh = rm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(1.0, 0.85, 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.85, 0.3)
		m.emission_energy_multiplier = 1.2
		target_ring.material_override = m
		level_root.add_child(target_ring)
	if st and is_instance_valid(st) and playing and not paused:
		target_ring.visible = true
		target_ring.global_position = st.global_position + Vector3(0, 0.06, 0)
	else:
		target_ring.visible = false

func _update_flying(delta: float) -> void:
	if flying.is_empty():
		return
	var done: Array = []
	for fl in flying:
		var n = fl["node"]
		if n == null or not is_instance_valid(n):
			done.append(fl)
			continue
		fl["t"] = float(fl["t"]) + delta
		var k: float = clampf(float(fl["t"]) / float(fl["dur"]), 0.0, 1.0)
		(n as Node3D).global_position = (fl["from"] as Vector3).lerp(fl["to"], k) + Vector3(0, sin(k * PI) * 0.8, 0)
		if k >= 1.0:
			var npc = fl["npc"]
			# NPC belum duduk: tahan piring di meja (maks 12 dtk), jangan makan di jalan
			if npc and is_instance_valid(npc) and int(npc.state) != NPCCustomer.State.WAIT_FOOD and float(fl.get("hold", 0.0)) < 12.0:
				fl["hold"] = float(fl.get("hold", 0.0)) + delta
				fl["t"] = float(fl["dur"])
				continue
			done.append(fl)
			if npc and is_instance_valid(npc):
				npc.start_eating()
				eating.append({"npc": npc, "t": randf_range(5.0, 8.0), "plate": n})
			else:
				(n as Node3D).queue_free()
	for d in done:
		flying.erase(d)

func _update_eating(delta: float) -> void:
	# MVP spec: piring kotor lengkap di luar scope — piring habis dimakan langsung
	# dibersihkan pelayan (hilang), NPC bayar + pulang.
	if eating.is_empty():
		return
	var done: Array = []
	for e in eating:
		e["t"] = float(e["t"]) - delta
		if float(e["t"]) <= 0.0:
			done.append(e)
			var npc = e["npc"]
			var pl = e["plate"]
			if pl and is_instance_valid(pl):
				pl.queue_free()
			if npc and is_instance_valid(npc):
				npc.pay_and_leave()
	for d in done:
		eating.erase(d)

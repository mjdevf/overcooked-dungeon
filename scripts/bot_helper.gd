class_name BotHelper
extends CharacterBody3D
## Bot rekrutan (Q): full auto by default. Fetch -> cincang -> rakit -> antar,
## tersinkron order via klaim (lihat game.claims). Tanpa mode; R tidak dipakai.

var speed := 5.2
var game = null
var carry: FoodItem = null
var carry_anchor: Node3D
var visual_root: Node3D
var walk_t := 0.0
var task := ""
var task_station: Station = null
var plan := {}  # {"uid":int, "need":Dictionary} — cook-run aktif
var job_label: Label3D
var _job := "@@init@@"
var raw_hold_t := 0.0
var sidestep_t := 0.0
var sidestep_sign := 1.0
var sidestep_dir := Vector3.ZERO
var apath: Array = []
var apath_to := Vector3(999, 999, 999)
var apath_cd := 0.0
var _want_move := false
var _last_dir := Vector3(0, 0, 1)
var target: Vector3 = Vector3.ZERO
var has_target := false
var work_cd := 0.0
var stuck_t := 0.0
var anim: CharAnim
var use_anim := false
var bot_working := false

const CHEF_MALE := "res://assets_external/characters/Chef_Male.fbx"

func _ready() -> void:
	visual_root = Node3D.new()
	add_child(visual_root)
	_build_body()
	carry_anchor = Node3D.new()
	if use_anim:
		carry_anchor.position = Vector3(0, 1.0, 0.4)
	else:
		carry_anchor.position = Vector3(0, 1.55, 0.45)
	add_child(carry_anchor)
	job_label = Label3D.new()
	job_label.font_size = 40
	job_label.pixel_size = 0.0075
	job_label.position = Vector3(0, 2.0, 0)
	job_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	job_label.outline_size = 8
	job_label.outline_modulate = Color(0, 0, 0, 0.9)
	job_label.modulate = Color(0.6, 1.0, 0.6)
	add_child(job_label)
	set_job("Ikut")

func _build_body() -> void:
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.1
	col.shape = cap
	col.position = Vector3(0, 0.65, 0)
	add_child(col)
	# bot = chef internet skala sedikit kecil (beda dari player), fallback prosedural
	anim = CharAnim.create(CHEF_MALE, 0.68)
	if anim.ok:
		use_anim = true
		visual_root.add_child(anim)
		return
	var accent := Color(0.35, 0.85, 0.45)
	var skin := Color(1.0, 0.80, 0.60)
	_bot_box(Vector3(-0.14, 0.08, 0), Vector3(0.2, 0.15, 0.28), Color(0.2, 0.18, 0.22))
	_bot_box(Vector3(0.14, 0.08, 0), Vector3(0.2, 0.15, 0.28), Color(0.2, 0.18, 0.22))
	_bot_box(Vector3(-0.14, 0.28, 0), Vector3(0.18, 0.28, 0.22), Color(0.28, 0.28, 0.34))
	_bot_box(Vector3(0.14, 0.28, 0), Vector3(0.18, 0.28, 0.22), Color(0.28, 0.28, 0.34))
	_bot_box(Vector3(0, 0.68, 0), Vector3(0.5, 0.5, 0.33), Color(0.95, 0.95, 0.96))
	_bot_box(Vector3(0, 0.64, 0.18), Vector3(0.36, 0.4, 0.04), accent)
	_bot_box(Vector3(-0.33, 0.7, 0), Vector3(0.14, 0.36, 0.18), Color(0.92, 0.92, 0.94))
	_bot_box(Vector3(0.33, 0.7, 0), Vector3(0.14, 0.36, 0.18), Color(0.92, 0.92, 0.94))
	_bot_sphere(Vector3(0, 1.1, 0), 0.2, skin)
	_bot_cyl(Vector3(0, 1.28, 0), 0.22, 0.07, Color.WHITE)
	_bot_cyl(Vector3(0, 1.44, 0), 0.25, 0.26, Color(1.0, 0.9, 0.4))

func _bot_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	return m

func _bot_box(pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _bot_mat(color)
	visual_root.add_child(mi)

func _bot_sphere(pos: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _bot_mat(color)
	visual_root.add_child(mi)

func _bot_cyl(pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _bot_mat(color)
	visual_root.add_child(mi)

# Label overhead biar pemain tahu bot lagi ngapain (sinkronisasi kelihatan).
func set_job(t: String) -> void:
	if t == _job:
		return
	_job = t
	if job_label and is_instance_valid(job_label):
		job_label.text = t

	# Batalkan tugas kalau dunia berubah. Plan order yg hangus ikut dibersihkan.
func _abort_if_invalid() -> void:
	if carry and not is_instance_valid(carry):
		carry = null
	if task == "chopping":
		if task_station == null or not is_instance_valid(task_station):
			task = ""
			task_station = null
		elif plan.is_empty():
			task = ""
			task_station = null
	elif task == "watching" and plan.is_empty():
		# order hangus di tengah masak: selamatkan yg matang/gosong, jangan macet
		var wz0: Station = task_station
		task = ""
		task_station = null
		if carry == null and wz0 and is_instance_valid(wz0) and wz0.stored and not wz0.stored.is_plate:
			if wz0.stored.cooked or wz0.stored.burnt:
				var got0: FoodItem = wz0.take_stored()
				if got0:
					_attach(got0)
	elif task == "todeliver":
		if carry == null or not is_instance_valid(carry):
			task = ""
			carry = null
	if not plan.is_empty():
		if game.orders.get_order(int(plan.get("uid", 0))).is_empty():
			_clear_plan()

func _clear_plan() -> void:
	if not plan.is_empty():
		game.release_claim(self)
	plan = {}

func _plan_label() -> String:
	var o: Dictionary = game.orders.get_order(int(plan.get("uid", 0)))
	if o.is_empty():
		return ""
	var lbl := str(o.get("recipe", {}).get("label", "?")).split(" ")
	return str(lbl[0]) if not lbl.is_empty() else "?"

func _detach() -> FoodItem:
	var f := carry
	carry = null
	if f and f.get_parent() == carry_anchor:
		carry_anchor.remove_child(f)
	return f

func _free_carry() -> void:
	if carry and is_instance_valid(carry):
		carry.queue_free()
	carry = null

func _drop_to_chop(delta: float) -> void:
	if carry == null:
		return
	var tb: Station = game.find_free_station("chop")
	if tb == null:
		_follow_player(delta)
		return
	if _goto(tb.global_position, delta, 1.6):
		_place_to(tb)

func _physics_process(delta: float) -> void:
	if game == null or not game.is_playing():
		velocity = Vector3.ZERO
		return
	work_cd -= delta
	_want_move = false
	_auto_brain(delta)
	# gravitasi (lantai collision sudah ada di game.gd)
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = -0.5
	else:
		velocity.y -= 22.0 * delta
	# sidestep darurat menimpa steering saat nyangkut
	if sidestep_t > 0.0:
		sidestep_t -= delta
		velocity.x = sidestep_dir.x * speed
		velocity.z = sidestep_dir.z * speed
	move_and_slide()
	# deteksi nyangkut: mau jalan tapi tidak pindah
	var hv0 := Vector2(velocity.x, velocity.z).length()
	if _want_move and hv0 < 0.6 and is_on_floor():
		stuck_t += delta
	else:
		stuck_t = 0.0
	if stuck_t > 0.5:
		stuck_t = 0.0
		sidestep_t = 1.2
		sidestep_sign = -sidestep_sign
		sidestep_dir = Vector3(-_last_dir.z * sidestep_sign, 0, _last_dir.x * sidestep_sign)
		if sidestep_dir.length() < 0.1:
			sidestep_dir = Vector3(0, 0, sidestep_sign)
	if global_position.y < -5.0:
		global_position = Vector3(-2, 1.0, 0)
		velocity = Vector3.ZERO
	# asuransi ledakan fisika: kalau terlontar ke langit, kembalikan ke pemain
	if global_position.y > 8.0:
		if game and game.player and is_instance_valid(game.player):
			global_position = game.player.global_position + Vector3(1.0, 0.6, 0.0)
		else:
			global_position = Vector3(-2, 1.0, 0)
		velocity = Vector3.ZERO
		apath.clear()
	# anim jalan (animasi internet, fallback bob)
	var hv := Vector2(velocity.x, velocity.z).length()
	if use_anim and anim:
		anim.locomotion(hv > 0.5, carry != null)
		if bot_working:
			anim.hold("Punch")
	else:
		if hv > 0.5:
			walk_t += delta * 10.0
			visual_root.position.y = absf(sin(walk_t)) * 0.06
			visual_root.rotation.z = sin(walk_t) * 0.04
		else:
			visual_root.position.y = lerpf(visual_root.position.y, 0.0, delta * 10.0)
			visual_root.rotation.z = lerpf(visual_root.rotation.z, 0.0, delta * 10.0)
	bot_working = false

func _follow_player(delta: float) -> void:
	var p: Vector3 = game.player.global_position
	var d: Vector3 = p - global_position
	d.y = 0.0
	if d.length() > 2.2:
		var dir: Vector3 = d.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_last_dir = dir
		_want_move = true
		rotation.y = atan2(dir.x, dir.z)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_want_move = false
	# bantu cincang kalau dekat talenan yg ada bahan mentah
	if work_cd <= 0.0:
		var nst: Station = game.chop_station_near(global_position, 1.8)
		if nst:
			nst.hold_work(0.5)
			work_cd = 0.2
			bot_working = true

func _auto_brain(delta: float) -> void:
	# 0. antar: tangan pegang piring jadi yg cocok order mana pun -> langsung todeliver
	_abort_if_invalid()
	if carry and carry.is_plate and not carry.plate_contents.is_empty():
		if not game.matching_order(carry.plate_contents).is_empty():
			task = "todeliver"
	# 0b. API KEBAKARAN: prioritas di atas cook-run, tapi tangan makanan tak diganggu.
	if _handle_fire(delta):
		return
	# 1. lanjutkan plan cook-run yg aktif
	if not plan.is_empty():
		if _run_plan(delta):
			return
	# 2. piring jadi di meja (tangan kosong) -> ambil + antar
	if carry == null and task == "":
		var full: Station = game.find_complete_plate_station()
		if full:
			set_job("Antar!")
			if _goto(full.global_position, delta, 1.6):
				_attach(full.take_stored())
				task = "todeliver"
			return
	if task == "todeliver" and carry and carry.is_plate:
		var dst: Station = game.pass_station()
		if dst == null:
			_drop_to_chop(delta)
			return
		set_job("Antar!")
		if _goto(dst.global_position, delta, 1.5):
			var from_p: Vector3 = carry.global_position
			var f: FoodItem = _detach()
			var res: Dictionary = game._serve(f, dst.global_position, from_p)
			if not bool(res.get("ok", false)):
				_attach(f)
				_drop_to_chop(delta)
			task = ""
		return
	# (chopping ditangani di dalam _run_plan agar sinkron dengan plan)
	# 3. bangun plan baru (klaim order tertua yg feasible)
	if carry == null and task == "" and plan.is_empty():
		var tgt: Dictionary = game.assembly_target(self)
		if not tgt.is_empty():
			var o: Dictionary = tgt["order"]
			if game.claim_order(self, int(o.get("uid", 0))):
				plan = {"uid": int(o.get("uid", 0)), "need": tgt["need"]}
				set_job("Masak " + _plan_label())
	# 4. eksekusi langkah plan
	if not plan.is_empty():
		if _run_plan(delta):
			return
	# --- ferry bahan mentah ke talenan kosong ---
	if carry and not carry.is_plate and not carry.chopped:
		# order habis di tengah bawa -> siaga (tangan dibebaskan di sana)
		if game.orders.active_orders.is_empty():
			_standby(delta)
			return
		set_job("Bawa " + str(carry.ingredient))
		var st: Station = game.find_free_station("chop")
		if st == null:
			raw_hold_t += delta
			if raw_hold_t > 6.0:
				raw_hold_t = 0.0
				var tr: Station = game.find_trash()
				if tr == null:
					set_job("Ikut")
					_follow_player(delta)
					return
				set_job("Buang")
				if _goto(tr.global_position, delta, 1.6):
					tr.interact(carry, false)
					_free_carry()
				return
			_wander_chop(delta)
			return
		raw_hold_t = 0.0
		if _goto(st.global_position, delta, 1.6):
			_place_to(st)
		return
	# 3. kalau tangan kosong -> ambil bahan yg dibutuhkan order dari crate
	if carry == null:
		var need: String = game.needed_ingredient()
		if need == "":
			# order kosong -> siaga di dapur, JANGAN buntuti pemain
			if game.orders.active_orders.is_empty():
				_standby(delta)
			else:
				set_job("Ikut")
				_follow_player(delta)
			return
		# kalau kosong semua: ambil dari crate (piring auto-stok ada di plating,
		# jadi bot tidak perlu ambil dari rak)
		var crate: Station = game.find_crate(need)
		if crate == null:
			set_job("Ikut")
			_follow_player(delta)
			return
		# jangan ambil bahan baru kalau tidak ada talenan kosong (macet + numpuk)
		if game.find_free_station("chop") == null:
			set_job("Ikut")
			_follow_player(delta)
			return
		set_job("Ambil " + need)
		if _goto(crate.global_position, delta, 1.6):
			var res: Dictionary = crate.interact(null, false)
			if res.get("take") != null:
				_attach(res.get("take"))
		return
	# fallback
	if game.orders.active_orders.is_empty():
		_standby(delta)
	else:
		set_job("Ikut")
		_follow_player(delta)

# Eksekusi 1 langkah plan cook-run. return true kalau frame ditangani.
func _run_plan(delta: float) -> bool:
	var uid := int(plan.get("uid", 0))
	var order: Dictionary = game.orders.get_order(uid)
	if order.is_empty():
		_clear_plan()
		return false
	var plate: Station = game.plate_for_order(order)
	if plate == null or plate.stored == null or not plate.stored.is_plate:
		_clear_plan()
		return false
	var missing: Dictionary = game.plan_missing(order, plate.stored.plate_contents)
	if missing.is_empty():
		_clear_plan()
		return false
	plan["need"] = missing
	var need: Dictionary = missing
	var iname := str(need.get("item", "?"))
	# CH. lagi mencincang: selesaikan dulu (tak di-preempt, job 3 dtk).
	# Berjalan di sini (bukan branch terpisah) supaya sinkron dengan plan.
	if task == "chopping":
		var ws: Station = task_station
		if ws == null or not is_instance_valid(ws) or ws.stored == null or ws.stored.is_plate:
			task = ""
			task_station = null
			return true
		# sisa orang yg tak relevan dgn order -> lepas, JANGAN sentuh/ambil.
		if not game.board_relevant(order, plate.stored.plate_contents, ws.stored):
			task = ""
			task_station = null
			return true
		if ws.stored.chopped:
			# yg sudah jadi tapi tak berguna (sisa orang) -> tinggalkan di meja.
			if game.need_useful(order, plate.stored.plate_contents, game.snap_of(ws.stored)):
				var got: FoodItem = ws.take_stored()
				if got:
					_attach(got)
			task = ""
			task_station = null
			return true
		set_job("Cincang " + str(ws.stored.ingredient))
		bot_working = true
		if _goto(ws.global_position, delta, 1.6):
			ws.hold_work(delta)
		return true
	# W. lagi mengawasi masakan: tunggu matang lalu ambil; gosong -> buang;
	# api -> lepas (pre-check APAR ambil alih).
	if task == "watching":
		var wz: Station = task_station
		if carry != null or wz == null or not is_instance_valid(wz) or wz.stored == null or wz.stored.is_plate:
			task = ""
			task_station = null
			return true
		if wz.fire:
			task = ""
			task_station = null
			return true
		if wz.stored.burnt:
			var gb: FoodItem = wz.take_stored()
			if gb:
				_attach(gb)
			task = ""
			task_station = null
			return true
		if wz.stored.cooked:
			var gc: FoodItem = wz.take_stored()
			if gc:
				_attach(gc)
			task = ""
			task_station = null
			return true
		set_job("Masak " + str(wz.stored.ingredient))
		_goto(wz.global_position, delta, 1.6)
		return true
	# A. tangan pegang bahan olahan yg berguna utk order (boleh need berikutnya,
	# bukan cuma missing pertama) -> merger ke piring target. Mentah yg perlu olah
	# dilewat (meja tolak) supaya jatuh ke cabang B/cincang; mentah siap saji
	# (roti/keju) langsung merge.
	if carry and not carry.is_plate and (carry.chopped or LevelData.needs_no_prep(str(carry.ingredient))) and game.need_useful(order, plate.stored.plate_contents, game.snap_of(carry)):
		set_job("Rakit " + _plan_label())
		if _goto(plate.global_position, delta, 1.6):
			var res: Dictionary = plate.interact(carry, false)
			if str(res.get("msg", "")).begins_with("OK"):
				_free_carry()
				# kalau piringnya langsung jadi -> bawa antar, jangan masak lagi
				if plate.stored and not game.matching_order(plate.stored.plate_contents).is_empty():
					var take_p: FoodItem = plate.take_stored()
					if take_p:
						_attach(take_p)
						task = "todeliver"
						_clear_plan()
		return true
	# B. tangan pegang bahan mentah/olahan yg berguna -> cincang/masak.
	# Gosong tak pernah berguna -> langsung buang. Bawaan TAK berguna
	# (surplus/duplikat) -> buang, kalau tidak loop taruh-ambil selamanya.
	if carry and not carry.is_plate:
		var snap0: Dictionary = game.snap_of(carry)
		var cing := str(carry.ingredient)
		var useful0: bool = game.need_useful(order, plate.stored.plate_contents, snap0)
		var raw0: bool = not carry.chopped and not carry.cooked
		var potential0: bool = game.need_eventual(order, plate.stored.plate_contents, cing) and (raw0 or (carry.chopped and not carry.cooked and not carry.burnt and game.need_cook_for(order, plate.stored.plate_contents, cing)))
		if carry.burnt or (not useful0 and not potential0):
			set_job("Buang")
			var tr: Station = game.find_trash()
			if tr == null:
				_follow_player(delta)
				return true
			if _goto(tr.global_position, delta, 1.6):
				tr.interact(carry, false)
				_free_carry()
			return true
		# B2. bawaan cincang-mentah utk need masak -> kompor kosong -> watching
		if carry.chopped and not carry.cooked and not carry.burnt and game.need_cook_for(order, plate.stored.plate_contents, cing):
			var fz: Station = game.free_stove()
			if fz == null:
				_wait_at_boards(delta)
				return true
			set_job("Masak " + cing)
			if _goto(fz.global_position, delta, 1.6):
				var res3: Dictionary = fz.interact(carry, bool(game.level.get("burn_enabled", false)))
				if bool(res3.get("place_consumed", false)):
					_detach()
					task = "watching"
					task_station = fz
			return true
		# ada sisa mentah yg sama di talenan? buang duplikat di tangan (mentah=murah),
		# tangan kosong -> cabang C adopsi progres talenan itu. Jangan taruh baru.
		if raw0 and game.raw_board_for(cing) != null:
			set_job("Buang")
			var tr0: Station = game.find_trash()
			if tr0 == null:
				_wait_at_boards(delta)
				return true
			if _goto(tr0.global_position, delta, 1.6):
				tr0.interact(carry, false)
				_free_carry()
			return true
		if carry.chopped or carry.cooked:
			# berguna tapi gagal merge (harusnya tak terjadi) -> tunggu aman, jangan loop.
			_wait_at_boards(delta)
			return true
		var st: Station = game.find_free_station("chop")
		if st == null:
			_wait_at_boards(delta)
			return true
		set_job("Cincang " + cing)
		if _goto(st.global_position, delta, 1.6):
			_place_to(st)
			if carry == null:
				task = "chopping"
				task_station = st
		return true
	# C. tangan kosong: staged dulu, bersih gosong, else fetch mentah
	# (cincang -> B, masak -> B2/watching).
	if carry == null:
		var src: Station = game.staged_source(need)
		if src:
			set_job("Ambil " + iname)
			if _goto(src.global_position, delta, 1.6):
				var got: FoodItem = src.take_stored()
				if got:
					_attach(got)
			return true
		# kompor gosong dibiarkan macet: angkut ke sampah biar alur jalan lagi
		var bs: Station = game.burnt_stove()
		if bs:
			set_job("Buang gosong")
			if _goto(bs.global_position, delta, 1.6):
				var gb2: FoodItem = bs.take_stored()
				if gb2:
					_attach(gb2)
			return true
		var crate: Station = game.find_crate(iname)
		if crate == null:
			_clear_plan()
			return false
		# ADOPSI sisa dulu: ada bahan mentah cocok di talenan -> teruskan cincang
		# di situ (tanpa fetch baru dari crate, tanpa nunggu pemain bereskan).
		if bool(need.get("chop", false)):
			var adop0: Station = game.raw_board_for(iname)
			if adop0 != null:
				set_job("Cincang " + iname)
				task = "chopping"
				task_station = adop0
				return true
			if game.find_free_station("chop") == null:
				_wait_at_boards(delta)
				return true
		set_job("Ambil " + iname)
		if _goto(crate.global_position, delta, 1.6):
			var res2: Dictionary = crate.interact(null, false)
			if res2.get("take") != null:
				_attach(res2.get("take"))
		return true
	# D. tangan pegang piring jadi yg cocok -> serahkan ke todeliver (jangan ditelan).
	# return false supaya blok todeliver di brain tetap jalan di tick yg sama.
	if carry and carry.is_plate and not game.matching_order(carry.plate_contents).is_empty():
		task = "todeliver"
		_clear_plan()
		return false
	set_job("Ikut")
	_follow_player(delta)
	return true

func _goto(pos: Vector3, delta: float, arrive: float) -> bool:
	# Steering A* (spec): path dihitung ulang kalau target pindah / tiap 0.7 dtk.
	# Target di dalam sel ber-collision (station) -> tuju sel bebas tetangga,
	# cek tiba pakai radius asli ke target.
	if game == null:
		return false
	apath_cd -= delta
	if apath.is_empty() or apath_to.distance_to(pos) > 1.0 or apath_cd <= 0.0:
		apath = _route_to(pos)
		apath_to = pos
		apath_cd = 0.7
	while not apath.is_empty():
		var t: Vector3 = apath[0]
		var d: Vector3 = t - global_position
		d.y = 0.0
		if d.length() < 0.45:
			apath.pop_front()
			continue
		var dir: Vector3 = d.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		_last_dir = dir
		_want_move = true
		rotation.y = atan2(dir.x, dir.z)
		return false
	var dd: Vector3 = pos - global_position
	dd.y = 0.0
	if dd.length() <= arrive:
		velocity.x = 0.0
		velocity.z = 0.0
		_want_move = false
		return true
	apath = _route_to(pos)
	apath_to = pos
	apath_cd = 0.7
	return false

func _route_to(pos: Vector3) -> Array:
	var gc := ProtoConfig.gpos(pos)
	if not game.astar_blocked(gc.x, gc.y):
		return game.astar_path(global_position, pos)
	# sel tetangga bebas (ortogonal dulu biar jarak akhir <=1.0 <= radius arrive)
	for pass_i in [0, 1]:
		var best := Vector2i(-999, -999)
		var bd := 999999.0
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				if pass_i == 0 and dx != 0 and dy != 0:
					continue
				var nb := Vector2i(gc.x + dx, gc.y + dy)
				if game.astar_blocked(nb.x, nb.y):
					continue
				var w := Vector3(float(nb.x) - 5.5, 0, float(nb.y) - 5.5)
				var dd: float = w.distance_to(global_position)
				if dd < bd:
					bd = dd
					best = nb
		if best.x > -900:
			var gw := Vector3(float(best.x) - 5.5, 0, float(best.y) - 5.5)
			return game.astar_path(global_position, gw)
	return [pos]

# Siaga saat order kosong: kosongkan tangan, jalan ke titik standby, DIAM.
# Bot tidak membuntuti pemain, siap kerja seketika order datang.
func _standby(delta: float) -> void:
	set_job("Siaga")
	if carry:
		# order habis di tengah jalan: buang bawaan (crate/rak infinite, tak rugi)
		_free_carry()
		task = ""
		task_station = null
		apath.clear()
	var sp: Vector3 = game.bot_standby_pos()
	var idx: int = int(game.bots.find(self))
	if idx > 0:
		sp += Vector3(float(idx) * 1.2, 0, 0)
	var dd: Vector3 = sp - global_position
	dd.y = 0.0
	if dd.length() > 0.6:
		_goto(sp, delta, 0.6)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
		_want_move = false

# APAR & api: padamkan dulu. Tangan makanan tak diganggu (return false -> plan lanjut).
# return true kalau frame ditangani.
func _handle_fire(delta: float) -> bool:
	var fz: Station = game.burning_stove()
	var aparrying: bool = carry != null and carry.ingredient == "apar"
	if fz == null:
		# tak ada api: kembalikan APAR yg dibawa ke mejanya (rak infinite)
		if aparrying:
			var ast: Station = game.apar_station()
			if ast == null:
				_free_carry()
				return true
			set_job("APAR kembali")
			if _goto(ast.global_position, delta, 1.6):
				_free_carry()
			return true
		return false
	if aparrying:
		set_job("Padamkan!")
		if _goto(fz.global_position, delta, 1.6):
			fz.extinguish()
			game.hud.flash("Api padam!")
			game.audio.success()
		return true
	if carry != null:
		return false
	var ast2: Station = game.apar_station()
	if ast2 == null:
		return false
	set_job("Ambil APAR")
	if _goto(ast2.global_position, delta, 1.6):
		_attach(FoodItem.make_apar())
	return true

func _wander_chop(delta: float) -> void:
	var st: Station = game.find_free_station("chop")
	if st:
		_goto(st.global_position, delta, 1.6)
	else:
		_follow_player(delta)

# Tunggu AKTIF di dekat talenan: jalan ke talenan terdekat + bantu cincang sisa
# mentah di sekitar. Bot tetap di area kerja (reaktif seketika talenan kosong)
# alih-alih ikut pemain menjauh.
func _wait_at_boards(delta: float) -> void:
	set_job("Tunggu")
	var nb: Station = game.nearest_chop(global_position)
	if nb == null:
		_follow_player(delta)
		return
	_goto(nb.global_position, delta, 1.6)
	if work_cd <= 0.0:
		var nst: Station = game.chop_station_near(global_position, 1.8)
		if nst and nst.stored and not nst.stored.is_plate and not nst.stored.chopped:
			nst.hold_work(0.5)
			work_cd = 0.2
			bot_working = true

func _attach(f: FoodItem) -> void:
	carry = f

	if f.get_parent():
		f.get_parent().remove_child(f)
	carry_anchor.add_child(f)
	f.position = Vector3.ZERO

func _place_to(st: Station) -> void:
	if carry == null:
		return
	if st.stored != null:
		return

	var f: FoodItem = carry
	carry = null
	if f.get_parent() == carry_anchor:
		carry_anchor.remove_child(f)
	st.force_store(f)
	if game:
		game.audio.place()

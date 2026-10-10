class_name OrderManager
extends Node
## Order dibuat saat NPC sampai kasir (game-driven). Expire, match oldest-first, skor.

signal orders_changed
signal score_changed(score: int)
signal game_over(score: int, stars: int)
signal order_added(order: Dictionary)
signal order_expired(order: Dictionary)

var level: Dictionary = {}
var active_orders: Array = []   # Array[Dictionary {uid, recipe, table_id, time_left, time_max, npc}]
var score: int = 0
var time_left: float = 180.0
var running: bool = false
var rng := RandomNumberGenerator.new()
var _next_uid := 1

func start_level(p_level: Dictionary) -> void:
	level = p_level
	active_orders.clear()
	score = 0
	time_left = float(level.get("time", 180.0))
	running = true
	rng.randomize()
	emit_signal("orders_changed")
	emit_signal("score_changed", score)

func stop() -> void:
	running = false

func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		running = false
		emit_signal("game_over", score, stars())
		return
	# expire orders
	var expired: Array = []
	for o in active_orders:
		o["time_left"] = float(o["time_left"]) - delta
		if float(o["time_left"]) <= 0.0:
			expired.append(o)
	for o in expired:
		active_orders.erase(o)
		score = maxi(0, score - 20)
		emit_signal("score_changed", score)
		emit_signal("order_expired", o)
	emit_signal("orders_changed")

func patience() -> float:
	return float(level.get("patience", 90.0))

# Dipanggil game saat NPC memesan di kasir. return order dict.
func spawn_recipe(rid: String, table_id: String) -> Dictionary:
	var r := LevelData.get_recipe(rid)
	var o := {"uid": _next_uid, "recipe": r, "table_id": table_id, "time_left": patience(), "time_max": patience()}
	_next_uid += 1
	active_orders.append(o)
	emit_signal("order_added", o)
	emit_signal("orders_changed")
	return o

func get_order(uid: int) -> Dictionary:
	for o in active_orders:
		if int(o.get("uid", 0)) == uid:
			return o
	return {}

func stars() -> int:
	var s1 := int(level.get("star_1", 150))
	var s2 := int(level.get("star_2", 300))
	var s3 := int(level.get("star_3", 450))
	if score >= s3:
		return 3
	if score >= s2:
		return 2
	if score >= s1:
		return 1
	return 0

# Piring diantar ke delivery. return {ok, msg, reward}
func deliver(plate: FoodItem) -> Dictionary:
	if plate == null or not plate.is_plate:
		return {"ok": false, "msg": "Bukan piring!", "reward": 0}
	if plate.dirty:
		return {"ok": false, "msg": "Piring kotor!", "reward": 0}
	var got := -1
	for i in range(active_orders.size()):
		var r: Dictionary = active_orders[i]["recipe"]
		if LevelData.match_recipe(r, plate.plate_contents):
			got = i
			break
	if got == -1:
		score = maxi(0, score - 10)
		emit_signal("score_changed", score)
		return {"ok": false, "msg": "Tidak ada order cocok!", "reward": 0}
	var r: Dictionary = active_orders[got]["recipe"]
	var tleft := float(active_orders[got]["time_left"])
	var tmax := float(active_orders[got].get("time_max", 90.0))
	var done_order: Dictionary = active_orders[got]
	active_orders.remove_at(got)
	var reward := int(r.get("reward", 100))
	# bonus cepat relatif terhadap patience order (bukan absolut 60 dtk)
	if tleft > tmax * 0.66:
		reward += 30
	score += reward
	emit_signal("score_changed", score)
	emit_signal("orders_changed")
	return {"ok": true, "msg": "Order OK! +" + str(reward), "reward": reward, "order": done_order, "time_left": tleft, "time_max": tmax}

func _match(recipe: Dictionary, contents: Array) -> bool:
	return LevelData.match_recipe(recipe, contents)

func chaos_level() -> int:
	# 0 santai, 1 sibuk, 2 caos — dipakai bot buat saran
	if active_orders.size() >= 3 or time_left < 45.0:
		return 2
	if active_orders.size() >= 2:
		return 1
	return 0

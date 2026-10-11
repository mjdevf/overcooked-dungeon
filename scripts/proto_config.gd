class_name ProtoConfig
extends RefCounted
## Layout prototipe v2 (spec kitchen-prototype(1).md): 12x12, alur melingkar.
## Satu-satunya sumber kebenaran posisi: ASCII + STATIONS + DINING.
## World: 1 tile = 1m, wx = x-5.5, wz = y-5.5.

const W := 12
const H := 12

const RAW := [
	"##BXSSSShh##",
	"T..........P",
	"T..........P",
	"t..........L",
	"s....@.....L",
	"r..........L",
	"k..........W",
	"#########AK#",
	"#.cMc.cMc.q#",
	"#.........q#",
	"#.cMc.cMc.q#",
	"#####D######",
]

# kind: crate/chop/stove/spice/plates/plating/sink/trash/pass/cashier
const STATIONS := [
	{"kind": "crate", "item": "tomat", "pos": [0, 3]},
	{"kind": "crate", "item": "selada", "pos": [0, 4]},
	{"kind": "crate", "item": "roti", "pos": [0, 5]},
	{"kind": "crate", "item": "keju", "pos": [0, 6]},
	{"kind": "chop", "pos": [0, 1]},
	{"kind": "chop", "pos": [0, 2]},
	{"kind": "stove", "pos": [4, 0], "active": true},
	{"kind": "stove", "pos": [5, 0], "active": true},
	{"kind": "stove", "pos": [6, 0], "active": false},
	{"kind": "stove", "pos": [7, 0], "active": false},
	{"kind": "spice", "pos": [8, 0]},
	{"kind": "spice", "pos": [9, 0]},
	{"kind": "plates", "pos": [11, 1]},
	{"kind": "plates", "pos": [11, 2]},
	{"kind": "plating", "pos": [11, 3]},
	{"kind": "plating", "pos": [11, 4]},
	{"kind": "plating", "pos": [11, 5]},
	{"kind": "sink", "pos": [11, 6]},
	{"kind": "trash", "pos": [2, 0]},
	{"kind": "pass", "pos": [9, 7]},
	{"kind": "cashier", "pos": [10, 7]},
	# APAR di samping kompor 1 (sisi atas), jarak 1 langkah
	{"kind": "apar", "pos": [3, 0]},
]

const DINING := {
	"door": [5, 11],
	"queue": [[10, 8], [10, 9], [10, 10]],
	# CATATAN: T1/T2 digeser ke baris 9 dari spec (baris 8) — terlalu mepet kasir.
	"tables": [
		{"id": "T1", "pos": [3, 9], "seats": [[2, 9], [4, 9]], "active": true},
		{"id": "T2", "pos": [7, 9], "seats": [[6, 9], [8, 9]], "active": true},
		{"id": "T3", "pos": [3, 10], "seats": [[2, 10], [4, 10]], "active": false},
		{"id": "T4", "pos": [7, 10], "seats": [[6, 10], [8, 10]], "active": false},
	],
}

const SPAWN := [5, 4]

# sel non-tembok di baris tembok: station yang nempel tembok + pintu (D)
const NON_WALL := {"9,7": 1, "10,7": 1, "5,11": 1}

# warna trim zona per kind (tipis di tepi lantai, bukan tembok)
const TRIM := {
	"crate": Color(0.3, 0.55, 1.0),
	"chop": Color(0.3, 0.85, 0.4),
	"stove": Color(1.0, 0.3, 0.25),
	"spice": Color(1.0, 0.3, 0.25),
	"plates": Color(1.0, 0.8, 0.25),
	"plating": Color(1.0, 0.8, 0.25),
	"pass": Color(0.7, 0.4, 1.0),
	"cashier": Color(0.7, 0.4, 1.0),
	"sink": Color(0.6, 0.6, 0.65),
	"trash": Color(0.6, 0.6, 0.65),
	"apar": Color(1.0, 0.25, 0.2),
}

static func wpos(gx: int, gy: int) -> Vector3:
	return Vector3(float(gx) - 5.5, 0.0, float(gy) - 5.5)

static func gpos(w: Vector3) -> Vector2i:
	return Vector2i(int(round(w.x + 5.5)), int(round(w.z + 5.5)))

static func cell_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "#"
	return (RAW[y] as String).substr(x, 1)

static func is_wall(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return true
	if cell_at(x, y) != "#":
		return false
	return not NON_WALL.has(str(x) + "," + str(y))

static func wall_cells() -> Array:
	var out: Array = []
	for y in range(H):
		for x in range(W):
			if is_wall(x, y):
				out.append(Vector2i(x, y))
	return out

static func floor_zone(gx: int, gy: int) -> String:
	# ruang makan biru; dapur dibagi 3 zona: bahan kiri, masak atas, rakit kanan
	if gy >= 8:
		return "makan"
	if gx == 1 and gy >= 1 and gy <= 6:
		return "bahan"
	if gy == 1 and gx >= 2 and gx <= 9:
		return "masak"
	if gx == 10 and gy >= 1 and gy <= 6:
		return "rakit"
	return "masak"

static func active_tables() -> Array:
	var out: Array = []
	for t in DINING["tables"]:
		if bool(t.get("active", true)):
			out.append(t)
	return out

static func queue_slots() -> Array:
	return DINING["queue"]

static func door_cell() -> Vector2i:
	var d: Array = DINING["door"]
	return Vector2i(int(d[0]), int(d[1]))

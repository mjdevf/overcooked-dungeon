class_name LevelData
extends RefCounted

# Data resep & level. Semua string Indonesia biar gampang dibaca.
# Ingredient: { name, need_chop, need_cook }
# Recipe: { id, label, ingredients: Array[String ingredient_name], color }

const INGREDIENTS := {
	"tomat": {"label": "Tomat", "color": Color(1.0, 0.30, 0.28), "need_chop": true, "need_cook": false, "scl": 2.0},
	"selada": {"label": "Selada", "color": Color(0.45, 0.85, 0.30), "need_chop": true, "need_cook": false, "scl": 0.9},
	"keju": {"label": "Keju", "color": Color(1.0, 0.82, 0.25), "need_chop": false, "need_cook": false, "scl": 0.5},
	"roti": {"label": "Roti", "color": Color(0.85, 0.62, 0.35), "need_chop": false, "need_cook": false, "scl": 1.0},
	"daging": {"label": "Daging", "color": Color(0.62, 0.28, 0.28), "need_chop": false, "need_cook": true, "scl": 0.8},
	"sup": {"label": "Sup", "color": Color(0.95, 0.55, 0.20), "need_chop": false, "need_cook": true, "scl": 0.75},
}

const RECIPES := [
	{"id": "salad", "label": "Salad Dungeon", "needs": [
		{"item": "tomat", "chop": 1, "cook": 0},
		{"item": "selada", "chop": 1, "cook": 0}], "reward": 100},
	{"id": "roti_lapis", "label": "Roti Lapis", "needs": [
		{"item": "roti", "chop": 0, "cook": 0},
		{"item": "tomat", "chop": 1, "cook": 0}], "reward": 130},
	{"id": "burger", "label": "Burger Keju", "needs": [
		{"item": "roti", "chop": 0, "cook": 0},
		{"item": "keju", "chop": 0, "cook": 0},
		{"item": "selada", "chop": 1, "cook": 0}], "reward": 170},
	{"id": "tumis", "label": "Tumis Dungeon", "needs": [
		{"item": "tomat", "chop": 1, "cook": 1},
		{"item": "selada", "chop": 1, "cook": 1}], "reward": 180},
]

static func need_met(need: Dictionary, have: Dictionary) -> bool:
	if str(need.get("item", "")) != str(have.get("item", "")):
		return false
	# harus persis: salad menolak yang sudah matang, tumis menolak yang mentah
	if bool(need.get("chop", false)) != bool(have.get("chopped", false)):
		return false
	if bool(need.get("cook", false)) != bool(have.get("cooked", false)):
		return false
	return true

static func match_recipe(recipe: Dictionary, contents: Array) -> bool:
	var needs: Array = recipe.get("needs", [])
	if needs.size() != contents.size():
		return false
	var used: Array = []
	for n in needs:
		var found := false
		for i in range(contents.size()):
			if i in used:
				continue
			if need_met(n, contents[i]):
				used.append(i)
				found = true
				break
		if not found:
			return false
	return true

static func get_recipe(recipe_id: String) -> Dictionary:
	for r in RECIPES:
		if r["id"] == recipe_id:
			return r
	return RECIPES[0]

# Bahan yg langsung saji tanpa olah (roti/keju): boleh merge mentah ke piring.
# Tak dikenal = butuh olah (aman).
static func needs_no_prep(ing: String) -> bool:
	var d: Dictionary = INGREDIENTS.get(ing, {})
	return not bool(d.get("need_chop", true)) and not bool(d.get("need_cook", true))

# Layout: satu map prototipe v2 (ProtoConfig) untuk semua level, beda pace/resep.
# patience = waktu order sebelum hangus. spawn_base = interval dasar spawn NPC (detik).
const LEVELS := [
	{
		"name": "L1 - Dapur Latihan",
		"map": "proto",
		"time": 180.0,
		"spawn_base": 22.0,
		"patience": 90.0,
		"recipes": ["salad"],
		"star_1": 150, "star_2": 300, "star_3": 450,
	},
	{
		"name": "L2 - Ruang Rame",
		"time": 210.0,
		"map": "proto",
		"spawn_base": 18.0,
		"patience": 80.0,
		"recipes": ["salad", "roti_lapis", "tumis"],
		"events": [{"at": 60.0, "kind": "rush"}, {"at": 150.0, "kind": "rush"}],
		"star_1": 300, "star_2": 550, "star_3": 800,
	},
	{
		"name": "L3 - Rush Hour",
		"time": 240.0,
		"map": "proto",
		"spawn_base": 14.0,
		"patience": 70.0,
		"recipes": ["salad", "roti_lapis", "burger", "tumis"],
		"events": [{"at": 45.0, "kind": "rush"}, {"at": 120.0, "kind": "rush"}, {"at": 185.0, "kind": "rush"}],
		"star_1": 400, "star_2": 700, "star_3": 1000,
	},
]

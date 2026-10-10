class_name CharAnim
extends Node3D
## Karakter animasi internet (Quaternius CC0): jalan / diam / aksi.
## Animasi bernama "CharacterArmature|X" — dicari per suffix.

var ap: AnimationPlayer
var cur := ""
var ok := false

static func create(fbx_path: String, scl: float) -> CharAnim:
	var c := CharAnim.new()
	if ResourceLoader.exists(fbx_path):
		var ps := load(fbx_path)
		if ps is PackedScene:
			var n: Node3D = (ps as PackedScene).instantiate()
			n.scale = Vector3(scl, scl, scl)
			c.add_child(n)
			var found := n.find_children("*", "AnimationPlayer", true, false)
			if not found.is_empty():
				c.ap = found[0]
				c.ok = true
	return c

func _full(suffix: String) -> String:
	if ap == null:
		return ""
	for a in ap.get_animation_list():
		if a.ends_with("|" + suffix):
			return a
	return ""

func play_named(suffix: String) -> void:
	var a := _full(suffix)
	if a == "":
		return
	if cur != a or (ap and not ap.is_playing()):
		cur = a
		ap.play(a)

func locomotion(moving: bool, carrying: bool) -> void:
	if not ok:
		return
	if moving:
		play_named("Walk_Carry" if carrying else "Walk")
	else:
		play_named("Idle")

# Tahan anim aksi (mis. Punch saat mencincang): replay kalau selesai.
func hold(suffix: String) -> void:
	if not ok:
		return
	var a := _full(suffix)
	if a == "":
		return
	if cur != a or not ap.is_playing():
		cur = a
		ap.play(a)

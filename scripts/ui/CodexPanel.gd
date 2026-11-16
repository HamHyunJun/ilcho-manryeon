extends MenuPanel
class_name CodexPanel
## 무공 도감 (M9, docs/04 3장): 무공 이름, 계열, 문파, 설명, 획득 경로, 습득 여부(조각 수),
## 개방 초식, 초식별 수련 횟수와 단계, 대성 여부.

var arts: MartialArtManager
var collection: ManualCollection
var _battle: Node2D


func _init(martial_arts: MartialArtManager, battle_manager: Node2D) -> void:
	super._init("무공 도감")
	arts = martial_arts
	_battle = battle_manager


func on_open() -> void:
	collection = _battle.collection if _battle else null
	_rebuild()


func _rebuild() -> void:
	clear_root()
	var names: Dictionary = arts.registry.balance.get("collection", {})
	var th: Array = arts.registry.balance.get("training", {}).get("stage_thresholds", [])
	var ids: Array = arts.registry.martial_arts.keys()
	ids.sort()
	var start_art: String = arts.registry.balance.get("training", {}).get("start_martial_art", "")
	for id in ids:
		var a: Dictionary = arts.registry.get_martial_art(id)
		var unlocked := arts.is_unlocked(id)
		var head := "%s  ·  %s · %s" % [a.get("name", id), names.get("categories", {}).get(a.get("category", ""), a.get("category", "")), names.get("sects", {}).get(a.get("sect", ""), a.get("sect", ""))]
		root.add_child(label(head, 22, Color(1, 0.9, 0.6) if unlocked else Color(0.65, 0.65, 0.7)))
		root.add_child(label(a.get("description", ""), 16, Color(0.82, 0.82, 0.88)))
		var path_key := "start" if id == start_art else String(a.get("acquire", {}).get("type", ""))
		var status := "습득" if unlocked else "미습득 · 비급 조각 %d / %d" % [collection.fragments_of(id) if collection else 0, int(a.get("acquire", {}).get("required", 0))]
		root.add_child(label("획득 경로: %s · %s" % [names.get("acquire_paths", {}).get(path_key, path_key), status], 16))
		if unlocked:
			var lines: PackedStringArray = []
			for t in arts.techniques_of(id):
				var tid: String = t["id"]
				if not arts.is_tech_unlocked(tid):
					lines.append("  %s · 잠김" % t["name"])
					continue
				var st := "대성" if arts.is_mastered(tid) else MartialArtManager.stage_name_for(arts.count_of(tid), th)
				lines.append("  %s · %s · %s회%s" % [t["name"], st, fmt(arts.count_of(tid)), "  ★" if arts.is_mastered(tid) else ""])
			root.add_child(label("\n".join(lines), 16))
		if collection and not unlocked and OS.is_debug_build():
			var dbg := button("디버그: 조각 +10", 16)
			dbg.pressed.connect(func():
				collection.add_fragments(id, 10)
				_rebuild())
			root.add_child(dbg)
		root.add_child(HSeparator.new())

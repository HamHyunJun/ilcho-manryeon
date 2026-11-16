extends MenuPanel
class_name SummonPanel
## 장비 소환 화면 (하단 앱바 [소환]).
## - 소환패로 장비 1회 / 10회 소환 (10회는 희귀 이상 1개 보장). 소환패는 보스 처치로 얻는다.
## - 결과 카드마다 [장착] 버튼으로 바로 등록하고, [좋은 장비 자동 장착]으로 부위별 더 좋은 장비를 한 번에 장착한다.
## - 같은 부위·같은 등급이 겹친 장비는 육성 화면에서 레벨업 재료로 쓸 수 있다고 안내한다.
## 동료/영물/수호령 소환(docs/06 B)은 MVP 이후이며, 지금 소환은 장비만 다룬다.

var equipment: EquipmentManager
var battle: Node2D
var message := ""
## 마지막 소환 결과
var last_results: Array = []
var _rng := RandomNumberGenerator.new()


func _init(equipment_manager: EquipmentManager, battle_manager: Node2D = null) -> void:
	super._init("장비 소환")
	equipment = equipment_manager
	battle = battle_manager
	_rng.randomize()


func _ready() -> void:
	equipment.currencies_changed.connect(func(): if visible: _rebuild())
	equipment.equipment_changed.connect(func(): if visible: _rebuild())


func on_open() -> void:
	message = ""
	_rebuild()


func _rebuild() -> void:
	clear_root()
	var ws: Dictionary = equipment.summon_cfg().get("grade_weights", {})
	var total := 0.0
	for g in equipment.cfg.get("grades", []):
		total += float(ws.get(g["id"], 0))
	root.add_child(label("소환패 %d장 · 보관함 %d / %d" % [equipment.tickets(), equipment.items().size(), equipment.capacity()], 22, Color(1, 0.9, 0.6)))
	var rates: PackedStringArray = []
	for g in equipment.cfg.get("grades", []):
		rates.append("%s %s%%" % [g["name"], String.num(float(ws.get(g["id"], 0)) / maxf(total, 0.001) * 100.0, 1)])
	root.add_child(label("확률: " + " · ".join(rates) + "\n10회 소환은 희귀 이상 1개 보장. 소환패는 보스를 처치하면 얻습니다.", 15, Color(0.78, 0.78, 0.85)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)
	for n in [1, 10]:
		var b := button("%d회 소환\n소환패 %d" % [n, equipment.summon_cost(n)], 22)
		b.custom_minimum_size = Vector2(314, 84)
		b.disabled = equipment.tickets() < equipment.summon_cost(n)
		b.pressed.connect(do_summon.bind(n))
		row.add_child(b)
	if message != "":
		root.add_child(label(message, 18, Color(1, 0.8, 0.5)))
	if not last_results.is_empty():
		var head := HBoxContainer.new()
		root.add_child(head)
		var t := label("소환 결과", 20)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(t)
		var auto := button("좋은 장비 자동 장착", 18)
		auto.pressed.connect(func():
			var n := equipment.auto_equip_best(_alive_results())
			message = "%d부위를 더 좋은 장비로 바꿨습니다" % n if n > 0 else "지금 장비보다 좋은 장비가 없습니다"
			_rebuild())
		head.add_child(auto)
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		root.add_child(grid)
		var dup := 0
		for it in _alive_results():
			var cell := VBoxContainer.new()
			cell.add_theme_constant_override("separation", 4)
			var card := GrowScreen.EquipCard.new()
			card.item = it
			card.equipment = equipment
			card.custom_minimum_size = Vector2(124, 128)
			cell.add_child(card)
			var eqd := equipment.is_equipped(int(it["uid"]))
			var eb := button("장착 중" if eqd else "장착", 17)
			eb.disabled = eqd
			eb.pressed.connect(func():
				equipment.equip(int(it["uid"]))
				message = "%s 장착" % equipment.item_name(it))
			cell.add_child(eb)
			grid.add_child(cell)
			if not equipment.level_up_materials(int(it["uid"])).is_empty():
				dup += 1
		if dup > 0:
			root.add_child(label("같은 부위·같은 등급이 겹친 장비가 있습니다. 육성 > 장비에서 장비를 눌러 레벨업 재료로 쓸 수 있습니다.", 16, Color(0.7, 0.9, 1.0)))
	if OS.is_debug_build():
		var dbg := button("디버그: 소환패 +10", 16)
		dbg.pressed.connect(func(): equipment.add_currency("ticket", 10))
		root.add_child(dbg)


## 결과 중 아직 보관함에 남아 있는 장비 (레벨업 재료로 쓰였으면 빠진다)
func _alive_results() -> Array:
	var out: Array = []
	for it in last_results:
		if not equipment.find(int(it["uid"])).is_empty():
			out.append(it)
	return out


## 소환한다 (테스트에서도 호출)
func do_summon(count: int) -> Dictionary:
	var sc := 1.0
	if battle != null and battle.stage != null:
		sc = battle.stage.scaling()
	var r := equipment.summon(count, sc, _rng)
	if r["ok"]:
		last_results = r["items"]
		var best := 0
		for it in last_results:
			best = maxi(best, equipment.grade_index(it["grade"]))
		message = "%d개 소환! 최고 등급: %s" % [last_results.size(), equipment.cfg["grades"][best]["name"]]
	else:
		message = r["reason"]
	_rebuild()
	return r

extends MenuPanel
class_name GrowScreen
## 육성 화면 (디자인 시안 mock-grow-screen-v1 반영).
## - 맨 위: 제목, 경지 · 전투력, 재화(은냥, 강화석, 보관함)
## - 가운데: 큰 주인공과 바닥 마법진, 좌우 장비 슬롯 5부위(등급색 테두리, 강화 수치). 슬롯을 누르면 상세
## - 아래: 능력치 4칸(공격력, 방어력, 체력, 내공)과 [장비 / 소환수 / 무공] 탭
## - [장비] 탭: 등급 필터가 있는 보유 장비 목록. 장비를 누르면 상세 창에서 장착/해제, 강화, 레벨업, 버리기
##   빈 슬롯을 누르면 그 부위 장비만 보여 줘 바로 골라 등록(장착)할 수 있다.
##   레벨업: 같은 부위·같은 등급 중복 장비를 재료로 장비 레벨을 올린다 (EquipmentManager.level_up)
## - [무공] 탭: 기존 무공 장착·초식 수련 화면(GrowthPanel)을 그대로 넣는다
## 시안의 수치와 장비 종류는 예시이며, 실제 데이터(EquipmentManager 5부위, 6등급)를 따른다.
## 화면은 상단 바까지 덮고, 하단 앱바(육성 활성) 위까지 차지한다.

const SCREEN := Rect2(0, 0, 720, 1146)
const LEFT_SLOTS := ["helmet", "armor", "shoes"]
const RIGHT_SLOTS := ["weapon", "accessory"]
const STAT_NAMES := {"atk": "공격력", "def": "방어력", "max_hp": "체력", "crit_rate": "치명타 확률", "crit_mult": "치명타 피해", "mp_regen": "내공 회복", "max_mp": "내공"}
const RESULT_TEXT := {0: "강화 성공", 1: "최대 강화 단계입니다", 2: "강화석 또는 은냥이 부족합니다", 3: "장비가 없습니다", 4: "강화 실패"}
const LEVEL_TEXT := {0: "레벨업 성공", 1: "최대 레벨입니다", 2: "같은 부위·같은 등급의 재료 장비가 없습니다", 3: "은냥이 부족합니다", 4: "장비가 없습니다"}
const TAB_Y := 728.0
const LIST_Y := 790.0

var arts: MartialArtManager
var equipment: EquipmentManager
var battle: Node2D
## 지금 탭: equip / summon / arts
var tab := "equip"
## 보유 장비 등급 필터 ("" = 전체)
var grade_filter := ""
## 보유 장비 부위 필터 ("" = 전체). 빈 슬롯을 누르면 그 부위로 정해진다
var slot_filter := ""
var selected_uid := 0
var message := ""

var _canvas: GrowCanvas
var _tab_buttons: Dictionary = {}
var _list_box: Control
var _grid: GridContainer
var _chips: HBoxContainer
var _arts_panel: GrowthPanel
var _detail: PanelContainer
var _detail_box: VBoxContainer
var _rng := RandomNumberGenerator.new()
var _slot_buttons: Dictionary = {}
var _list_scroll: ScrollContainer
## 보유 장비 목록 높이. 세로로 긴 화면에서는 fit_height()로 남는 만큼 늘린다
var list_h := 350.0


func _init(martial_arts: MartialArtManager, equipment_manager: EquipmentManager = null, battle_manager: Node2D = null) -> void:
	super._init("육성")
	arts = martial_arts
	equipment = equipment_manager
	battle = battle_manager
	_rng.randomize()
	position = SCREEN.position
	size = SCREEN.size
	custom_minimum_size = SCREEN.size
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#14132a")
	add_theme_stylebox_override("panel", bg)
	# MenuPanel 기본 스크롤 본문은 쓰지 않는다 (직접 배치)
	get_child(0).visible = false
	var layer := Control.new()
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	_canvas = GrowCanvas.new()
	_canvas.screen = self
	_canvas.position = Vector2.ZERO
	_canvas.size = SCREEN.size
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_canvas)
	_build_slots(layer)
	_build_tabs(layer)
	_build_list(layer)
	_build_arts(layer)
	_build_detail(layer)


func _ready() -> void:
	if equipment != null:
		equipment.inventory_changed.connect(_refresh_list)
		equipment.equipment_changed.connect(_refresh_list)


func on_open() -> void:
	message = ""
	slot_filter = ""
	_close_detail()
	_set_tab(tab)


func _process(_delta: float) -> void:
	if visible:
		_canvas.queue_redraw()


# ---- 좌우 장비 슬롯 ----

func _build_slots(layer: Control) -> void:
	var ys := [196.0, 330.0, 464.0]
	for i in LEFT_SLOTS.size():
		_add_slot(layer, LEFT_SLOTS[i], Vector2(26, ys[i]))
	for i in RIGHT_SLOTS.size():
		_add_slot(layer, RIGHT_SLOTS[i], Vector2(608, ys[i]))


func _add_slot(layer: Control, slot: String, pos: Vector2) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.position = pos
	b.size = Vector2(86, 86)
	b.custom_minimum_size = b.size
	b.pressed.connect(func():
		if equipment == null:
			return
		var it := equipment.equipped_item(slot)
		if not it.is_empty():
			_open_detail(int(it["uid"]))
		else:
			# 빈 슬롯: 그 부위 장비만 보여 주고 골라서 등록(장착)하게 한다
			grade_filter = ""
			slot_filter = slot
			message = "%s 장비를 눌러 장착하세요" % _slot_name(slot)
			_set_tab("equip"))
	layer.add_child(b)
	_slot_buttons[slot] = b


func _slot_name(slot: String) -> String:
	if equipment == null:
		return slot
	return String(equipment.slot_data(slot).get("name", slot))


# ---- 탭 ----

func _build_tabs(layer: Control) -> void:
	var defs := [["equip", "장비"], ["summon", "소환수"], ["arts", "무공"]]
	for i in defs.size():
		var b := MenuPanel.button(defs[i][1], 24)
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.position = Vector2(22 + i * 228, TAB_Y)
		b.size = Vector2(220, 50)
		b.custom_minimum_size = b.size
		b.pressed.connect(_set_tab.bind(defs[i][0]))
		layer.add_child(b)
		_tab_buttons[defs[i][0]] = b


func _tab_style(on: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if on:
		sb.bg_color = Color(0.45, 0.28, 0.1, 0.95)
		sb.border_color = Color("#e8b94e")
	else:
		sb.bg_color = Color(0.12, 0.08, 0.1, 0.9)
		sb.border_color = Color(0.45, 0.32, 0.22)
	return sb


func _set_tab(t: String) -> void:
	tab = t
	for k in _tab_buttons.keys():
		var b: Button = _tab_buttons[k]
		var on: bool = k == tab
		b.set_pressed_no_signal(on)
		for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			b.add_theme_stylebox_override(s, _tab_style(on))
		b.add_theme_color_override("font_color", Color(1, 0.95, 0.8) if on else Color(0.75, 0.72, 0.7))
		b.add_theme_color_override("font_pressed_color", Color(1, 0.95, 0.8))
		b.add_theme_color_override("font_hover_pressed_color", Color(1, 0.95, 0.8))
	_list_box.visible = tab == "equip"
	_arts_panel.visible = tab == "arts"
	if tab == "arts":
		_arts_panel.on_open()
	elif tab == "equip":
		_refresh_list()
	_canvas.queue_redraw()


# ---- 보유 장비 목록 ----

func _build_list(layer: Control) -> void:
	_list_box = Control.new()
	_list_box.position = Vector2(20, LIST_Y)
	_list_box.size = Vector2(680, 350)
	layer.add_child(_list_box)
	var title := MenuPanel.label("보유 장비", 20, Color(1, 0.95, 0.85))
	title.position = Vector2(16, 8)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	_list_box.add_child(title)
	_chips = HBoxContainer.new()
	_chips.position = Vector2(118, 8)
	_chips.add_theme_constant_override("separation", 6)
	_list_box.add_child(_chips)
	var scroll := ScrollContainer.new()
	_list_scroll = scroll
	scroll.position = Vector2(8, 50)
	scroll.size = Vector2(664, 292)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)


func _refresh_list() -> void:
	if _grid == null or not visible:
		return
	for c in _chips.get_children():
		c.queue_free()
	for c in _grid.get_children():
		c.queue_free()
	if equipment == null:
		return
	# 등급 필터 칩: 전체 + 등급들 (등급색 테두리)
	if slot_filter != "":
		# 부위 필터 칩 (누르면 해제)
		var sf := MenuPanel.button("%s ✕" % _slot_name(slot_filter), 15)
		sf.focus_mode = Control.FOCUS_NONE
		sf.custom_minimum_size = Vector2(70, 30)
		sf.pressed.connect(func():
			slot_filter = ""
			message = ""
			_refresh_list())
		_chips.add_child(sf)
	var chips := [["", "전체", Color(0.8, 0.8, 0.85)]]
	for g in equipment.cfg.get("grades", []):
		chips.append([g["id"], g["name"], Color.html(g["color"])])
	for ch in chips:
		var b := MenuPanel.button(ch[1], 15)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(70, 30)
		var on: bool = grade_filter == ch[0]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(15)
		sb.set_border_width_all(2)
		sb.border_color = ch[2]
		sb.bg_color = Color(ch[2], 0.35) if on else Color(0.08, 0.07, 0.12, 0.9)
		for s in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(s, sb)
		b.add_theme_color_override("font_color", Color.WHITE if on else ch[2])
		b.pressed.connect(func():
			grade_filter = ch[0]
			_refresh_list())
		_chips.add_child(b)
	var items := equipment.sorted_items()
	var shown := 0
	for it in items:
		if grade_filter != "" and it["grade"] != grade_filter:
			continue
		if slot_filter != "" and it["slot"] != slot_filter:
			continue
		var card := EquipCard.new()
		card.item = it
		card.equipment = equipment
		card.custom_minimum_size = Vector2(124, 128)
		card.pressed.connect(_open_detail.bind(int(it["uid"])))
		_grid.add_child(card)
		shown += 1
	if shown == 0:
		var l := MenuPanel.label("보유한 장비가 없습니다. 몬스터와 보스가 떨어뜨립니다." if grade_filter == "" else "이 등급의 장비가 없습니다.", 17, Color(0.75, 0.75, 0.82))
		l.custom_minimum_size = Vector2(640, 0)
		_grid.add_child(l)


## 화면 높이를 맞춘다 (하단 앱바 윗선까지). 늘어난 만큼 보유 장비 목록과 무공 탭을 키운다
func fit_height(h: float) -> void:
	h = maxf(h, SCREEN.size.y)
	size = Vector2(SCREEN.size.x, h)
	custom_minimum_size = size
	_canvas.size = size
	list_h = 350.0 + (h - SCREEN.size.y)
	_list_box.size = Vector2(680, list_h)
	_list_scroll.size = Vector2(664, list_h - 58)
	_arts_panel.size = Vector2(720, h - LIST_Y + 4)
	_arts_panel.custom_minimum_size = _arts_panel.size
	_canvas.queue_redraw()


# ---- 무공 탭 (기존 무공 화면) ----

func _build_arts(layer: Control) -> void:
	_arts_panel = GrowthPanel.new(arts)
	_arts_panel.position = Vector2(0, LIST_Y - 4)
	_arts_panel.size = Vector2(720, SCREEN.size.y - LIST_Y + 4)
	_arts_panel.custom_minimum_size = _arts_panel.size
	_arts_panel.close_requested.connect(func(): _set_tab("equip"))
	layer.add_child(_arts_panel)


# ---- 장비 상세 창 ----

func _build_detail(layer: Control) -> void:
	_detail = PanelContainer.new()
	_detail.position = Vector2(60, 250)
	_detail.custom_minimum_size = Vector2(600, 0)
	_detail.size = Vector2(600, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.1, 0.98)
	sb.border_color = Color("#e8b94e")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(18)
	_detail.add_theme_stylebox_override("panel", sb)
	_detail.visible = false
	layer.add_child(_detail)
	_detail_box = VBoxContainer.new()
	_detail_box.add_theme_constant_override("separation", 10)
	_detail.add_child(_detail_box)


func _open_detail(uid: int) -> void:
	selected_uid = uid
	message = ""
	_rebuild_detail()


func _close_detail() -> void:
	selected_uid = 0
	if _detail:
		_detail.visible = false


func _rebuild_detail() -> void:
	for c in _detail_box.get_children():
		c.queue_free()
	var it := equipment.find(selected_uid) if equipment else {}
	if it.is_empty():
		_detail.visible = false
		return
	_detail.visible = true
	var name_l := MenuPanel.label("%s %s  Lv %d / %d  +%d" % [equipment.grade_data(it["grade"]).get("name", ""), _slot_name(it["slot"]), equipment.item_level(it), equipment.max_item_level(), int(it["enh"])] + ("  (장착 중)" if equipment.is_equipped(selected_uid) else ""), 24, equipment.grade_color(it["grade"]))
	_detail_box.add_child(name_l)
	var lines: PackedStringArray = []
	var bs := equipment.item_base_stats(it)
	for stat in bs.keys():
		var v := float(bs[stat])
		lines.append("%s +%s" % [STAT_NAMES.get(stat, stat), ("%.1f%%" % (v * 100.0)) if stat == "crit_rate" else str(roundi(v))])
	for o in it.get("options", []):
		lines.append("· " + equipment.option_text(o))
	_detail_box.add_child(MenuPanel.label("\n".join(lines), 19))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_detail_box.add_child(row)
	if equipment.is_equipped(selected_uid):
		var un := MenuPanel.button("해제", 20)
		un.custom_minimum_size = Vector2(110, 60)
		un.pressed.connect(func():
			equipment.unequip(it["slot"])
			_rebuild_detail())
		row.add_child(un)
	else:
		var eq := MenuPanel.button("장착", 20)
		eq.custom_minimum_size = Vector2(110, 60)
		eq.pressed.connect(func():
			equipment.equip(selected_uid)
			_rebuild_detail())
		row.add_child(eq)
	var cost := equipment.enhance_cost(it)
	var enh_text := "강화 (최대)" if int(it["enh"]) >= equipment.max_enhance() else "강화 +%d → +%d\n강화석 %d · 은냥 %s" % [int(it["enh"]), int(it["enh"]) + 1, int(cost["stone"]), fmt(int(cost["silver"]))]
	var en := MenuPanel.button(enh_text, 16)
	en.custom_minimum_size = Vector2(200, 60)
	en.pressed.connect(func():
		message = RESULT_TEXT.get(equipment.enhance(selected_uid, _rng), "")
		_rebuild_detail())
	row.add_child(en)
	var dis := MenuPanel.button("버리기", 20)
	dis.custom_minimum_size = Vector2(100, 60)
	dis.disabled = equipment.is_equipped(selected_uid)
	dis.pressed.connect(func():
		equipment.discard(selected_uid)
		_close_detail())
	row.add_child(dis)
	var close := MenuPanel.button("닫기", 20)
	close.custom_minimum_size = Vector2(100, 60)
	close.pressed.connect(_close_detail)
	row.add_child(close)
	# 장비 레벨업: 중복 장비(같은 부위·같은 등급)를 재료로 소모
	var mats := equipment.level_up_materials(selected_uid)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 8)
	_detail_box.add_child(lrow)
	var lv := equipment.item_level(it)
	var lc := equipment.level_up_cost(it)
	var ltext := "레벨업 (최대)"
	if lv < equipment.max_item_level():
		ltext = "레벨업 Lv %d → %d\n재료 %d개 · 은냥 %s" % [lv, lv + 1, int(lc["materials"]), fmt(int(lc["silver"]))]
	var lb := MenuPanel.button(ltext, 16)
	lb.custom_minimum_size = Vector2(230, 60)
	lb.disabled = not equipment.can_level_up(selected_uid)
	lb.pressed.connect(func():
		message = LEVEL_TEXT.get(equipment.level_up(selected_uid), "")
		_rebuild_detail())
	lrow.add_child(lb)
	var stat_per := float(equipment.cfg.get("level_up", {}).get("stat_per_level", 0.1)) * 100.0
	var info := MenuPanel.label("재료로 쓸 수 있는 같은 %s %s: %d개\n(레벨·강화가 낮은 것부터 사용, 레벨당 기본 능력치 +%d%%)" % [equipment.grade_data(it["grade"]).get("name", ""), _slot_name(it["slot"]), mats.size(), roundi(stat_per)], 15, Color(0.7, 0.9, 1.0))
	info.custom_minimum_size = Vector2(320, 0)
	lrow.add_child(info)
	if message != "":
		_detail_box.add_child(MenuPanel.label(message, 18, Color(1, 0.8, 0.5)))
	# 지운 자식이 빠진 뒤 크기를 다시 맞춘다
	_detail.size = Vector2(600, 0)
	_detail.reset_size.call_deferred()


# ---- 능력치 (BattleManager의 실제 적용 능력치) ----

func stats() -> Dictionary:
	if battle != null and battle.has_method("_effective_stats"):
		return battle._effective_stats()
	return {}


func hero_style() -> String:
	if battle != null and battle.player != null and "style" in battle.player:
		return battle.player.style
	if arts != null:
		return String(arts.registry.get_martial_art(arts.main_art()).get("category", "sword"))
	return "sword"


## 장비 카드: 등급색 테두리, 부위 아이콘, 강화 수치, 장착 표시(E), 이름
class EquipCard extends Button:
	var item: Dictionary
	var equipment: EquipmentManager

	func _ready() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE

	func _draw() -> void:
		var col := equipment.grade_color(item["grade"])
		var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		UiIcons.round_rect(self, r, 12, Color(0.1, 0.09, 0.15, 0.95), col, 3.0)
		draw_circle(Vector2(size.x * 0.5, 52), 34, Color(col, 0.16))
		UiIcons.slot_icon(self, item["slot"], Vector2(size.x * 0.5, 52), 46, col)
		UiIcons.round_rect(self, Rect2(8, 8, 36, 22), 8, Color(col, 0.9))
		UiIcons.text(self, Vector2(8, 25), "+%d" % int(item["enh"]), 15, Color(0.05, 0.05, 0.08), HORIZONTAL_ALIGNMENT_CENTER, 36, 0)
		var lv := equipment.item_level(item)
		UiIcons.text(self, Vector2(size.x - 60, 25), "Lv%d" % lv, 15, Color(1, 1, 1) if lv > 1 else Color(0.7, 0.7, 0.78), HORIZONTAL_ALIGNMENT_RIGHT, 50, 3)
		if equipment.is_equipped(int(item["uid"])):
			UiIcons.text(self, Vector2(size.x - 28, 84), "E", 20, Color(1, 0.9, 0.5), HORIZONTAL_ALIGNMENT_LEFT, -1, 3)
		elif equipment.can_level_up(int(item["uid"])):
			# 레벨업 가능 표시 (초록 위 화살표)
			var a := Vector2(size.x - 22, 78)
			draw_colored_polygon(PackedVector2Array([a + Vector2(0, -10), a + Vector2(9, 0), a + Vector2(3, 0), a + Vector2(3, 8), a + Vector2(-3, 8), a + Vector2(-3, 0), a + Vector2(-9, 0)]), Color("#5ee07a"))
		var grade_name: String = equipment.grade_data(item["grade"]).get("name", "")
		var slot_name: String = equipment.slot_data(item["slot"]).get("name", "")
		UiIcons.text(self, Vector2(4, size.y - 14), "%s %s" % [grade_name, slot_name], 16, Color(0.95, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, size.x - 8, 3)


## 화면 그림: 배경, 제목, 재화, 주인공과 마법진, 슬롯 테두리, 능력치, 목록 테두리
class GrowCanvas extends Control:
	var screen: GrowScreen
	var _t := 0.0

	func _process(d: float) -> void:
		_t += d

	func _draw() -> void:
		var s := screen
		# 배경: 남색 밤하늘 + 은은한 달빛
		var rows := ceili(size.y / 58.0)
		for i in rows:
			draw_rect(Rect2(0, i * 58, 720, 58), Color("#1a1838").lerp(Color("#0f0e1f"), i / float(maxi(rows - 1, 1))))
		for i in 8:
			draw_circle(Vector2(540, 230), 150 - i * 14, Color(1.0, 0.92, 0.7, 0.025))
		# 제목과 경지 · 전투력
		UiIcons.text(self, Vector2(0, 52), "육성", 38, Color(1, 0.97, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 720, 6)
		var sub := ""
		if s.battle != null and s.battle.growth != null:
			sub = "%s · Lv %d · 전투력 %s" % [s.battle.growth.realm().get("name", ""), s.battle.growth.level(), MenuPanel.fmt(s.battle.combat_power())]
		UiIcons.text(self, Vector2(0, 86), sub, 20, Color(0.85, 0.82, 0.78), HORIZONTAL_ALIGNMENT_CENTER, 720, 4)
		draw_line(Vector2(0, 102), Vector2(720, 102), Color(0.85, 0.64, 0.25, 0.5), 2.0)
		# 재화 줄
		if s.equipment != null:
			var cur := [["은냥", MenuPanel.fmt(s.equipment.silver()), Color("#d7dbe8")], ["강화석", MenuPanel.fmt(s.equipment.stone()), Color("#7fd8ff")], ["보관함", "%d / %d" % [s.equipment.items().size(), s.equipment.capacity()], Color("#f2c75c")]]
			for i in cur.size():
				var r := Rect2(20 + i * 232, 116, 216, 40)
				UiIcons.round_rect(self, r, 20, Color(0.05, 0.04, 0.09, 0.85), Color(0.85, 0.64, 0.25, 0.6), 2.0)
				draw_circle(r.position + Vector2(24, 20), 10, cur[i][2])
				UiIcons.text(self, r.position + Vector2(42, 27), cur[i][0], 17, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
				UiIcons.text(self, r.position + Vector2(0, 28), cur[i][1], 20, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 18, 0)
		# 바닥 마법진 (원근)
		var base := Vector2(360, 586)
		for k in 3:
			var rr := 190.0 - k * 50.0
			var pts := PackedVector2Array()
			for i in 61:
				var a := TAU * i / 60.0 + _t * (0.3 if k % 2 == 0 else -0.4)
				pts.append(base + Vector2(cos(a) * rr, sin(a) * rr * 0.24))
			draw_polyline(pts, Color(0.95, 0.75, 0.3, 0.75 - k * 0.15), 3.0 - k * 0.6)
		for i in 24:
			var a := TAU * i / 24.0 + _t * 0.3
			draw_line(base + Vector2(cos(a), sin(a) * 0.24) * 170.0, base + Vector2(cos(a), sin(a) * 0.24) * 186.0, Color(0.95, 0.75, 0.3, 0.6), 2.0)
		draw_set_transform(base, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, 120, Color(0, 0, 0, 0.45))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# 큰 주인공 (공격 준비 자세, 숨쉬기)
		var art := ChibiArt.hero(s.hero_style())
		var sc := 5.0
		var size_v: Vector2 = art["size"]
		var bob := roundf(sin(_t * 2.5) * 3.0)
		var feet := base + Vector2(0, -6 + bob)
		ChibiArt.draw_sprite(self, art["body"], size_v, feet, sc)
		var hand: Vector2 = feet + (Vector2(art["hand"]) - Vector2(size_v.x * 0.5, size_v.y)) * sc
		var ang := 0.55
		var off := Vector2.ZERO
		match art["weapon_kind"]:
			"fist":
				ang = 0.0
				off = Vector2(-6, -12)
			"talisman":
				ang = 0.15
				off = Vector2(-10, -16)
		ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], hand + off, ang, sc)
		# 좌우 장비 슬롯
		for slot in s._slot_buttons.keys():
			var b: Button = s._slot_buttons[slot]
			var r := Rect2(b.position, b.size)
			var it: Dictionary = s.equipment.equipped_item(slot) if s.equipment else {}
			var col := s.equipment.grade_color(it["grade"]) if not it.is_empty() else Color(0.4, 0.4, 0.48)
			UiIcons.round_rect(self, r, 14, Color(0.07, 0.06, 0.12, 0.92), col, 3.0)
			UiIcons.slot_icon(self, slot, r.get_center(), 54, col if not it.is_empty() else Color(0.35, 0.35, 0.42))
			if not it.is_empty():
				var badge := Rect2(r.position + Vector2(r.size.x - 40, -10), Vector2(46, 24))
				UiIcons.round_rect(self, badge, 12, col)
				UiIcons.text(self, badge.position + Vector2(0, 18), "+%d" % int(it["enh"]), 16, Color(0.05, 0.05, 0.08), HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 0)
			UiIcons.text(self, Vector2(r.position.x - 20, r.end.y + 26), s._slot_name(slot), 19, Color(0.95, 0.93, 0.88), HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 40, 4)
		# 능력치 4칸
		var st := s.stats()
		var cells := [["공격력", "atk", Color("#ff6a6a")], ["방어력", "def", Color("#6aa8ff")], ["체력", "max_hp", Color("#6ee08a")], ["내공", "max_mp", Color("#b48cff")]]
		var box := Rect2(20, 620, 680, 92)
		UiIcons.round_rect(self, box, 14, Color(0.05, 0.04, 0.09, 0.85), Color(0.85, 0.64, 0.25, 0.6), 2.0)
		for i in 4:
			var x := box.position.x + i * 170.0
			if i > 0:
				draw_line(Vector2(x, box.position.y + 16), Vector2(x, box.end.y - 16), Color(0.85, 0.64, 0.25, 0.35), 2.0)
			UiIcons.text(self, Vector2(x, box.position.y + 32), cells[i][0], 18, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 170, 0)
			var v := "-"
			if st.has(cells[i][1]):
				v = MenuPanel.fmt(roundi(float(st[cells[i][1]])))
			UiIcons.text(self, Vector2(x, box.position.y + 72), v, 30, cells[i][2], HORIZONTAL_ALIGNMENT_CENTER, 170, 4)
		# 탭 아래 목록 테두리
		if s.tab == "equip" or s.tab == "summon":
			var lr := Rect2(20, LIST_Y, 680, s.list_h)
			UiIcons.round_rect(self, lr, 14, Color(0.05, 0.04, 0.09, 0.85), Color(0.85, 0.64, 0.25, 0.6), 2.0)
			if s.tab == "summon":
				UiIcons.text(self, Vector2(20, LIST_Y + s.list_h * 0.5 - 5), "소환수: MVP 이후 추가 예정", 22, Color(0.85, 0.82, 0.78), HORIZONTAL_ALIGNMENT_CENTER, 680, 0)
		if s.message != "" and s.tab == "equip":
			UiIcons.text(self, Vector2(20, LIST_Y + s.list_h - 12), s.message, 16, Color(1, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 680, 3)

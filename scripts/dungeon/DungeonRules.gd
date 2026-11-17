extends RefCounted
class_name DungeonRules
## 던전 공통 규칙 (docs/07 3-2 던전 공통 구조).
## - 난이도 단계: 던전 데이터의 difficulties에서 단계별 배율, 입장 조건, 보상 덮어쓰기를 읽어 하나로 합친다.
## - 보상: 던전 종류(type)별로 지급한다.
##   manual(비급 던전) → 비급 조각, equipment(장비 던전) → 장비·강화석, currency(재화 던전) → 요일제 재화.
## - 데이터 검증.
## 수치는 모두 데이터(data/dungeons/*.json)에 있고 가안이다 (O-31).

const TYPES := ["manual", "equipment", "currency"]
const CLEAR_TYPES := ["waves", "time_attack"]
const WEEKDAY_NAMES := ["일", "월", "화", "수", "목", "금", "토"]


# ---- 난이도 ----

## 난이도 목록. 데이터에 없으면 1단계 하나로 본다
static func difficulties(dungeon: Dictionary) -> Array:
	var list: Array = dungeon.get("difficulties", [])
	if list.is_empty():
		return [{"level": 1, "name": "기본"}]
	return list


static func max_level(dungeon: Dictionary) -> int:
	return difficulties(dungeon).size()


static func difficulty(dungeon: Dictionary, level: int) -> Dictionary:
	var list := difficulties(dungeon)
	return list[clampi(level, 1, list.size()) - 1]


## 난이도를 반영한 던전 데이터. battle·rewards는 난이도 값으로 덮어쓰고, 입장 조건은 난이도 조건을 쓴다.
## 결과에 level, difficulty_name을 넣는다. 원본은 바꾸지 않는다.
static func resolve(dungeon: Dictionary, level: int = 1) -> Dictionary:
	var out: Dictionary = dungeon.duplicate(true)
	var lv := clampi(level, 1, max_level(dungeon))
	var diff := difficulty(dungeon, lv)
	var battle: Dictionary = out.get("battle", {})
	if diff.has("scaling"):
		battle["scaling"] = diff["scaling"]
	for k in diff.get("battle", {}).keys():
		battle[k] = diff["battle"][k]
	out["battle"] = battle
	var rewards: Dictionary = out.get("rewards", {})
	for k in diff.get("rewards", {}).keys():
		rewards[k] = diff["rewards"][k]
	out["rewards"] = rewards
	var entry: Dictionary = out.get("entry", {})
	if diff.has("required_cleared"):
		entry["required_cleared"] = diff["required_cleared"]
	out["entry"] = entry
	out["level"] = lv
	out["difficulty_name"] = String(diff.get("name", "%d단계" % lv))
	return out


static func clear_type(dungeon: Dictionary) -> String:
	return String(dungeon.get("clear", {}).get("type", "waves"))


# ---- 요일제 (재화 던전) ----

## today("YYYY-MM-DD")의 요일. 0=일요일 … 6=토요일
static func weekday_of(today: String) -> int:
	var unix := Time.get_unix_time_from_datetime_string(today + "T12:00:00")
	return int(Time.get_datetime_dict_from_unix_time(unix).get("weekday", 0))


## 오늘 요일 보상 {currency, mult, label}. 데이터에 요일표가 없으면 은냥 1배
static func weekday_bonus(dungeon: Dictionary, today: String) -> Dictionary:
	var table: Array = dungeon.get("weekday", [])
	var wd := weekday_of(today)
	var e: Dictionary = table[wd] if table.size() == 7 else {}
	return {
		"currency": String(e.get("currency", "silver")),
		"mult": float(e.get("mult", 1.0)),
		"label": String(e.get("label", "")),
		"weekday": wd,
	}


## 무공 이름. DataRegistry 오토로드를 직접 참조하면 DataRegistry ↔ DungeonRules 순환 컴파일이 생겨 트리에서 찾는다
static func _art_name(art_id: String) -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var reg: Node = tree.root.get_node_or_null("DataRegistry") if tree else null
	if reg == null:
		return art_id
	return String(reg.get_martial_art(art_id).get("name", art_id))


static func currency_name(kind: String) -> String:
	return {"silver": "은냥", "stone": "강화석"}.get(kind, kind)


# ---- 보상 ----

## 클리어 보상을 지급한다. dungeon은 resolve()를 거친 데이터.
## kills는 이번 진행(또는 소탕 기준)의 처치 수 (재화 던전 보상 계산용).
## 반환값: {type, fragments, pity_bonus, silver, stone, items, discarded, currency, amount, weekday_label}
static func grant(dungeon: Dictionary, kills: int, collection: ManualCollection, equipment: EquipmentManager,
		rng: RandomNumberGenerator, today: String = "") -> Dictionary:
	if today == "":
		today = ManualCollection.today_key()
	var type := String(dungeon.get("type", "manual"))
	var rw: Dictionary = dungeon.get("rewards", {})
	var res := {"type": type, "fragments": [], "pity_bonus": {}, "silver": 0, "stone": 0, "items": [], "discarded": 0}
	match type:
		"manual":
			# 비급 던전은 기존 규칙 그대로 (조각, 은냥, 천장, 클리어 기록)
			var r: Dictionary = collection.grant_clear(dungeon, rng, today)
			for k in r.keys():
				res[k] = r[k]
		"equipment":
			var st: Array = rw.get("stone", [0, 0])
			res["stone"] = rng.randi_range(int(st[0]), int(st[1]))
			res["silver"] = int(rw.get("silver", 0))
			if equipment:
				equipment.add_currency("stone", int(res["stone"]))
				equipment.add_currency("silver", int(res["silver"]))
				var item_scaling := float(rw.get("item_scaling", dungeon.get("battle", {}).get("scaling", 1.0)))
				var min_grade := String(rw.get("min_grade", ""))
				var slots := equipment.slot_ids()
				for i in int(rw.get("items", 0)):
					var grade := equipment.roll_grade(rng)
					if min_grade != "" and equipment.grade_index(grade) < equipment.grade_index(min_grade):
						grade = min_grade
					var item := equipment.generate(slots[rng.randi_range(0, slots.size() - 1)], grade, item_scaling, rng)
					if equipment.add_item(item):
						res["items"].append(item)
					else:
						res["discarded"] = int(res["discarded"]) + 1
			collection.add_clear(dungeon["id"], today)
		"currency":
			var wb := weekday_bonus(dungeon, today)
			var amount := int(round((float(rw.get("base", 0)) + float(rw.get("per_kill", 0)) * kills) * float(wb["mult"])))
			res["currency"] = wb["currency"]
			res["amount"] = amount
			res["weekday_label"] = wb["label"]
			if wb["currency"] == "silver":
				res["silver"] = amount
			elif wb["currency"] == "stone":
				res["stone"] = amount
			if equipment:
				equipment.add_currency(String(wb["currency"]), amount)
			collection.add_clear(dungeon["id"], today)
	collection.note_result(dungeon["id"], int(dungeon.get("level", 1)), kills)
	return res


## 보상 결과를 한 줄로 (배너, 던전 화면 표시용)
static func result_text(res: Dictionary, equipment: EquipmentManager = null) -> String:
	var parts: PackedStringArray = []
	for f in res.get("fragments", []):
		parts.append("%s 조각 %d" % [_art_name(f["art"]), int(f["amount"])])
	if not res.get("pity_bonus", {}).is_empty():
		parts.append("천장 보너스 %d" % int(res["pity_bonus"]["amount"]))
	var items: Array = res.get("items", [])
	if not items.is_empty():
		var names: PackedStringArray = []
		for it in items:
			names.append(equipment.item_name(it) if equipment else String(it.get("grade", "")))
		parts.append(", ".join(names))
	if int(res.get("discarded", 0)) > 0:
		parts.append("보관함이 가득 차 장비 %d개를 버림" % int(res["discarded"]))
	if int(res.get("stone", 0)) > 0:
		parts.append("강화석 %d" % int(res["stone"]))
	if int(res.get("silver", 0)) > 0:
		parts.append("은냥 %s" % MenuPanel.fmt(int(res["silver"])))
	if String(res.get("weekday_label", "")) != "":
		parts.append("(%s)" % res["weekday_label"])
	return ", ".join(parts) if not parts.is_empty() else "보상 없음"


## 선택한 난이도의 보상 안내 (던전 화면). dungeon은 resolve()를 거친 데이터
static func reward_preview(dungeon: Dictionary, equipment: EquipmentManager = null, today: String = "") -> String:
	if today == "":
		today = ManualCollection.today_key()
	var rw: Dictionary = dungeon.get("rewards", {})
	match String(dungeon.get("type", "manual")):
		"manual":
			var names: PackedStringArray = []
			for e in rw.get("pool", []):
				names.append(_art_name(e["art"]))
			var amt: Array = rw.get("fragments_per_roll", [1, 1])
			return "보상: %s 비급 조각 %d회 × %d~%d개 · 은냥 %s" % [", ".join(names), int(rw.get("fragment_rolls", 1)),
				int(amt[0]), int(amt[1]), MenuPanel.fmt(int(rw.get("silver", 0)))]
		"equipment":
			var st: Array = rw.get("stone", [0, 0])
			var grade := String(rw.get("min_grade", ""))
			var grade_name := String(equipment.grade_data(grade).get("name", grade)) if equipment and grade != "" else grade
			var t := "보상: 강화석 %d~%d · 장비 %d개" % [int(st[0]), int(st[1]), int(rw.get("items", 0))]
			if grade_name != "":
				t += " (%s 이상)" % grade_name
			if int(rw.get("silver", 0)) > 0:
				t += " · 은냥 %s" % MenuPanel.fmt(int(rw["silver"]))
			return t
		"currency":
			var wb := weekday_bonus(dungeon, today)
			var t2 := "보상: %s %s + 처치당 %s" % [currency_name(wb["currency"]), MenuPanel.fmt(int(rw.get("base", 0))),
				MenuPanel.fmt(int(rw.get("per_kill", 0)))]
			t2 += "\n오늘(%s요일) %s ×%s" % [WEEKDAY_NAMES[wb["weekday"]], currency_name(wb["currency"]), str(snappedf(wb["mult"], 0.01))]
			if wb["label"] != "":
				t2 += " · " + wb["label"]
			return t2
	return ""


## 클리어 조건 안내 (던전 화면)
static func clear_text(dungeon: Dictionary) -> String:
	var tl := int(dungeon.get("battle", {}).get("time_limit", 180))
	if clear_type(dungeon) == "time_attack":
		return "%d초 동안 최대한 많이 처치 (최소 %d마리)" % [tl, int(dungeon.get("clear", {}).get("min_kills", 1))]
	return "웨이브 %d개 처치 · 제한 %d초" % [dungeon.get("waves", []).size(), tl]


# ---- 데이터 검증 ----

## 오류 문구 목록을 돌려준다 (없으면 빈 배열)
static func validate(data: Dictionary, path: String, monsters: Dictionary, martial_arts: Dictionary, equipment_cfg: Dictionary) -> Array:
	var errors: Array = []
	var type := String(data.get("type", "manual"))
	if not TYPES.has(type):
		errors.append("%s: 모르는 던전 종류 %s" % [path, type])
	var ct := clear_type(data)
	if not CLEAR_TYPES.has(ct):
		errors.append("%s: 모르는 클리어 조건 %s" % [path, ct])
	for w in data.get("waves", []):
		if w.has("boss") and not monsters.has(w["boss"]):
			errors.append("%s: 없는 보스 %s" % [path, w["boss"]])
		for e in w.get("monsters", []):
			if not monsters.has(e.get("monster", "")):
				errors.append("%s: 없는 몬스터 %s" % [path, e.get("monster", "")])
	if ct == "waves" and data.get("waves", []).is_empty():
		errors.append("%s: 웨이브가 없음" % path)
	if ct == "time_attack":
		var pool: Array = data.get("spawn_pool", [])
		if pool.is_empty():
			errors.append("%s: 시간 제한 처치 던전에 spawn_pool 없음" % path)
		for e in pool:
			if not monsters.has(e.get("monster", "")):
				errors.append("%s: 없는 몬스터 %s" % [path, e.get("monster", "")])
	var levels: Array = data.get("difficulties", [])
	for i in levels.size():
		if int(levels[i].get("level", 0)) != i + 1:
			errors.append("%s: 난이도 level은 1부터 차례로 (%d번째)" % [path, i + 1])
		if float(levels[i].get("scaling", 1.0)) <= 0.0:
			errors.append("%s: 난이도 %d 배율은 0보다 커야 함" % [path, i + 1])
	# 보상 참조: 난이도 덮어쓰기까지 확인
	for lv in range(1, max_level(data) + 1):
		var rw: Dictionary = resolve(data, lv).get("rewards", {})
		for e in rw.get("pool", []):
			if not martial_arts.has(e.get("art", "")):
				errors.append("%s: 보상 무공 없음 %s" % [path, e.get("art", "")])
		var g := String(rw.get("min_grade", ""))
		if g != "":
			var found := false
			for gd in equipment_cfg.get("grades", []):
				if gd.get("id", "") == g:
					found = true
			if not found:
				errors.append("%s: 없는 장비 등급 %s" % [path, g])
	if type == "manual" and data.get("rewards", {}).get("pool", []).is_empty():
		errors.append("%s: 비급 던전 보상 무공이 없음" % path)
	var wk: Array = data.get("weekday", [])
	if not wk.is_empty():
		if wk.size() != 7:
			errors.append("%s: 요일표는 7칸(일~토)이어야 함" % path)
		for e in wk:
			if not ["silver", "stone"].has(String(e.get("currency", "silver"))):
				errors.append("%s: 요일 보상 재화는 silver/stone만 (%s)" % [path, e.get("currency", "")])
	return errors

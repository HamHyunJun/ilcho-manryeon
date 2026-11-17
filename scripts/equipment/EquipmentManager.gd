extends RefCounted
class_name EquipmentManager
## 장비 기본 (M8, docs/06 A).
## - 5부위 장착, 6등급, 스테이지 드롭, 보관함, 강화(강화석 + 은냥).
## - 기본 능력치와 추가 옵션, 무공 시너지 옵션(대상: 전체/계열/무공/초식).
## - 장비 소환: 소환패로 장비를 뽑는다 (1회 / 10회, 10회는 희귀 이상 1개 보장).
## - 장비 레벨업: 같은 부위·같은 등급의 중복 장비를 재료로 써서 장비 레벨(lv)을 올린다. 강화(+N)와 별개로 곱해진다.
## - 분해, 세트, 제작, 승급은 MVP 이후 (O-41).
## 상태는 저장 데이터의 equipment 섹션, 재화는 currencies 섹션을 직접 다룬다.
## 수치는 data/equipment/equipment.json (모두 가안).

signal equipment_changed()
signal inventory_changed()
signal currencies_changed()

enum EnhanceResult {OK, MAX_LEVEL, NOT_ENOUGH, NO_ITEM, FAILED}
enum LevelUpResult {OK, MAX_LEVEL, NO_MATERIAL, NOT_ENOUGH, NO_ITEM}

var state: Dictionary
var wallet: Dictionary
var cfg: Dictionary


func _init(equipment_state: Dictionary, currencies: Dictionary, equipment_config: Dictionary) -> void:
	state = equipment_state
	wallet = currencies
	cfg = equipment_config
	for k in new_state().keys():
		if not state.has(k):
			state[k] = new_state()[k]
	for k in new_currencies().keys():
		if not wallet.has(k):
			wallet[k] = 0
	# 소환패: 처음 생길 때(새 게임, 또는 소환 기능 이전 저장) 시작 지급량을 준다 (가안)
	if not wallet.has("ticket"):
		wallet["ticket"] = int(cfg.get("summon", {}).get("starter_tickets", 0))


static func new_state() -> Dictionary:
	return {"inventory": [], "equipped": {}, "next_uid": 1}


static func new_currencies() -> Dictionary:
	return {"silver": 0, "stone": 0}


# ---- 데이터 조회 ----

func slot_ids() -> Array:
	var out: Array = []
	for s in cfg.get("slots", []):
		out.append(s["id"])
	return out


func slot_data(slot: String) -> Dictionary:
	for s in cfg.get("slots", []):
		if s["id"] == slot:
			return s
	return {}


func grade_data(grade: String) -> Dictionary:
	for g in cfg.get("grades", []):
		if g["id"] == grade:
			return g
	return {}


func grade_index(grade: String) -> int:
	var gs: Array = cfg.get("grades", [])
	for i in gs.size():
		if gs[i]["id"] == grade:
			return i
	return 0


func option_data(id: String) -> Dictionary:
	for o in cfg.get("options", []):
		if o["id"] == id:
			return o
	return {}


func capacity() -> int:
	return int(cfg.get("inventory_capacity", 100))


# ---- 재화 ----

func silver() -> int:
	return int(wallet.get("silver", 0))


func stone() -> int:
	return int(wallet.get("stone", 0))


func tickets() -> int:
	return int(wallet.get("ticket", 0))


func add_currency(kind: String, amount: int) -> void:
	if amount == 0:
		return
	wallet[kind] = maxi(0, int(wallet.get(kind, 0)) + amount)
	currencies_changed.emit()


# ---- 생성과 드롭 ----

## 장비를 만든다. stage_scaling은 드롭한 스테이지 배율 (기본 능력치에 곱함)
func generate(slot: String, grade: String, stage_scaling: float, rng: RandomNumberGenerator) -> Dictionary:
	var g := grade_data(grade)
	var base: Dictionary = {}
	var no_scale: Array = cfg.get("no_level_scaling_stats", [])
	var sd: Dictionary = slot_data(slot).get("base", {})
	for stat in sd.keys():
		var v := float(sd[stat]) * float(g.get("mult", 1.0))
		if not no_scale.has(stat):
			v *= stage_scaling
		base[stat] = snappedf(v, 0.001)
	var options: Array = []
	var pool: Array = []
	var synergy_pool: Array = []
	for o in cfg.get("options", []):
		if bool(o.get("synergy", false)):
			synergy_pool.append(o)
		pool.append(o)
	var n := int(g.get("options", 0))
	var used := {}
	for i in n:
		var o: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var guard := 0
		while used.has(o["id"]) and guard < 20:
			o = pool[rng.randi_range(0, pool.size() - 1)]
			guard += 1
		used[o["id"]] = true
		options.append({"id": o["id"], "value": snappedf(rng.randf_range(float(o["min"]), float(o["max"])), 0.001)})
	# 신화: 무공 시너지 옵션 1개 고정 (docs/06 A-2)
	if bool(g.get("fixed_synergy", false)) and not synergy_pool.is_empty():
		var so: Dictionary = synergy_pool[rng.randi_range(0, synergy_pool.size() - 1)]
		options.append({"id": so["id"], "value": snappedf(float(so["max"]), 0.001), "fixed": true})
	var item := {
		"uid": int(state["next_uid"]),
		"slot": slot,
		"grade": grade,
		"enh": 0,
		"lv": 1,
		"base": base,
		"options": options,
	}
	state["next_uid"] = int(state["next_uid"]) + 1
	return item


## 등급을 가중치로 뽑는다
func roll_grade(rng: RandomNumberGenerator) -> String:
	var gs: Array = cfg.get("grades", [])
	var total := 0.0
	for g in gs:
		total += float(g.get("drop_weight", 0))
	var r := rng.randf() * total
	for g in gs:
		r -= float(g.get("drop_weight", 0))
		if r <= 0.0:
			return g["id"]
	return gs[0]["id"]


## 몬스터 처치 드롭 판정. 반환값 {item: 장비 또는 {}, stone: n, ticket: n, added: 보관함에 들어갔는지}
func roll_drop(is_boss: bool, stage_scaling: float, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = cfg.get("drop", {})
	var out := {"item": {}, "stone": 0, "added": false}
	if is_boss:
		out["stone"] = int(d.get("stone_boss_amount", 3))
	elif rng.randf() < float(d.get("stone_normal_chance", 0.05)):
		out["stone"] = int(d.get("stone_normal_amount", 1))
	if out["stone"] > 0:
		add_currency("stone", out["stone"])
	# 보스는 소환패도 준다 (소환패는 게임 플레이로만 얻는다)
	out["ticket"] = int(summon_cfg().get("boss_tickets", 0)) if is_boss else 0
	if out["ticket"] > 0:
		add_currency("ticket", out["ticket"])
	var chance := float(d.get("boss_chance" if is_boss else "normal_chance", 0.0))
	if rng.randf() < chance:
		var slots := slot_ids()
		var item := generate(slots[rng.randi_range(0, slots.size() - 1)], roll_grade(rng), stage_scaling, rng)
		out["item"] = item
		out["added"] = add_item(item)
	return out


## 보관함에 넣는다. 가득 차면 넣지 않고 false (가득 찼을 때 처리는 O-27, 가안: 버림)
func add_item(item: Dictionary) -> bool:
	if state["inventory"].size() >= capacity():
		return false
	state["inventory"].append(item)
	inventory_changed.emit()
	return true


# ---- 보관함과 장착 ----

func items() -> Array:
	return state["inventory"]


func find(uid: int) -> Dictionary:
	for it in state["inventory"]:
		if int(it["uid"]) == uid:
			return it
	return {}


func equipped_uid(slot: String) -> int:
	return int(state["equipped"].get(slot, 0))


func equipped_item(slot: String) -> Dictionary:
	var uid := equipped_uid(slot)
	return find(uid) if uid > 0 else {}


func is_equipped(uid: int) -> bool:
	for s in state["equipped"].keys():
		if int(state["equipped"][s]) == uid:
			return true
	return false


func equip(uid: int) -> bool:
	var it := find(uid)
	if it.is_empty():
		return false
	state["equipped"][it["slot"]] = uid
	equipment_changed.emit()
	return true


func unequip(slot: String) -> void:
	if state["equipped"].has(slot):
		state["equipped"].erase(slot)
		equipment_changed.emit()


## 버린다 (장착 중이면 불가). 분해는 MVP 이후 (O-41)
func discard(uid: int) -> bool:
	if is_equipped(uid):
		return false
	var it := find(uid)
	if it.is_empty():
		return false
	state["inventory"].erase(it)
	inventory_changed.emit()
	return true


## 보관함을 등급 높은 순, 레벨 높은 순, 강화 높은 순으로 정렬한 목록
func sorted_items() -> Array:
	var arr: Array = state["inventory"].duplicate()
	arr.sort_custom(func(a, b):
		var ga := grade_index(a["grade"])
		var gb := grade_index(b["grade"])
		if ga != gb:
			return ga > gb
		if item_level(a) != item_level(b):
			return item_level(a) > item_level(b)
		if int(a["enh"]) != int(b["enh"]):
			return int(a["enh"]) > int(b["enh"])
		return int(a["uid"]) > int(b["uid"]))
	return arr


# ---- 장비 소환 ----

func summon_cfg() -> Dictionary:
	return cfg.get("summon", {})


## 소환 비용 (소환패 수). count: 1 또는 10
func summon_cost(count: int) -> int:
	return int(summon_cfg().get("cost_per_pull", 1)) * count


## 소환용 등급 가중치로 뽑는다 (없으면 드롭 가중치)
func roll_summon_grade(rng: RandomNumberGenerator, min_grade: int = 0) -> String:
	var gs: Array = cfg.get("grades", [])
	var weights: Dictionary = summon_cfg().get("grade_weights", {})
	var total := 0.0
	for i in gs.size():
		if i >= min_grade:
			total += float(weights.get(gs[i]["id"], gs[i].get("drop_weight", 0)))
	var r := rng.randf() * total
	for i in gs.size():
		if i < min_grade:
			continue
		r -= float(weights.get(gs[i]["id"], gs[i].get("drop_weight", 0)))
		if r <= 0.0:
			return gs[i]["id"]
	return gs[gs.size() - 1]["id"]


## 장비를 count개 소환한다. 소환패가 부족하거나 보관함 자리가 모자라면 아무것도 하지 않는다.
## 10회 이상이면 마지막 한 개는 guarantee_grade 이상을 보장한다.
## 반환값 {ok, reason, items}
func summon(count: int, stage_scaling: float, rng: RandomNumberGenerator) -> Dictionary:
	var cost := summon_cost(count)
	if tickets() < cost:
		return {"ok": false, "reason": "소환패가 부족합니다", "items": []}
	if items().size() + count > capacity():
		return {"ok": false, "reason": "보관함 자리가 부족합니다", "items": []}
	wallet["ticket"] = tickets() - cost
	currencies_changed.emit()
	var slots := slot_ids()
	var got: Array = []
	var best := 0
	var guarantee := grade_index(String(summon_cfg().get("guarantee_grade", "rare")))
	for i in count:
		var min_g := 0
		if count >= int(summon_cfg().get("guarantee_from", 10)) and i == count - 1 and best < guarantee:
			min_g = guarantee
		var grade := roll_summon_grade(rng, min_g)
		best = maxi(best, grade_index(grade))
		var it := generate(slots[rng.randi_range(0, slots.size() - 1)], grade, stage_scaling, rng)
		state["inventory"].append(it)
		got.append(it)
	inventory_changed.emit()
	return {"ok": true, "reason": "", "items": got}


## 부위마다 더 좋은 장비로 바꿔 장착한다 (점수: 등급, 레벨, 강화 순). 바꾼 부위 수를 돌려준다
func auto_equip_best(candidates: Array = []) -> int:
	if candidates.is_empty():
		candidates = items()
	var changed := 0
	for slot in slot_ids():
		var cur := equipped_item(slot)
		var best: Dictionary = cur
		for it in candidates:
			if it["slot"] == slot and (best.is_empty() or item_score(it) > item_score(best)):
				best = it
		if not best.is_empty() and (cur.is_empty() or int(best["uid"]) != int(cur["uid"])):
			state["equipped"][slot] = int(best["uid"])
			changed += 1
	if changed > 0:
		equipment_changed.emit()
	return changed


## 장비 비교 점수 (자동 장착용)
func item_score(it: Dictionary) -> float:
	return grade_index(it["grade"]) * 1000.0 + item_level(it) * 50.0 + int(it.get("enh", 0)) * 10.0


# ---- 장비 레벨업 (중복 장비 합성) ----

func item_level(it: Dictionary) -> int:
	return int(it.get("lv", 1))


func max_item_level() -> int:
	return int(cfg.get("level_up", {}).get("max_level", 10))


## 레벨업 재료 후보: 같은 부위·같은 등급, 장착하지 않은 다른 장비.
## 아끼는 장비를 잃지 않도록 레벨, 강화가 낮은 것부터 쓴다.
func level_up_materials(uid: int) -> Array:
	var it := find(uid)
	if it.is_empty():
		return []
	var out: Array = []
	for o in items():
		if int(o["uid"]) == uid or is_equipped(int(o["uid"])):
			continue
		if o["slot"] == it["slot"] and o["grade"] == it["grade"]:
			out.append(o)
	out.sort_custom(func(a, b):
		if item_level(a) != item_level(b):
			return item_level(a) < item_level(b)
		if int(a["enh"]) != int(b["enh"]):
			return int(a["enh"]) < int(b["enh"])
		return int(a["uid"]) < int(b["uid"]))
	return out


## 다음 레벨업 비용 {materials: 재료 장비 수, silver}
func level_up_cost(it: Dictionary) -> Dictionary:
	var c: Dictionary = cfg.get("level_up", {})
	var lv := item_level(it)
	return {
		"materials": int(c.get("materials_per_level", 1)),
		"silver": int(c.get("silver_base", 100)) + int(c.get("silver_per_level", 100)) * (lv - 1),
	}


## 레벨업할 수 있는지 (재료와 은냥이 모두 있는지)
func can_level_up(uid: int) -> bool:
	var it := find(uid)
	if it.is_empty() or item_level(it) >= max_item_level():
		return false
	var c := level_up_cost(it)
	return level_up_materials(uid).size() >= int(c["materials"]) and silver() >= int(c["silver"])


## 장비 레벨을 1 올린다. 재료 장비는 사라진다. 반환값 LevelUpResult
func level_up(uid: int) -> int:
	var it := find(uid)
	if it.is_empty():
		return LevelUpResult.NO_ITEM
	if item_level(it) >= max_item_level():
		return LevelUpResult.MAX_LEVEL
	var c := level_up_cost(it)
	var mats := level_up_materials(uid)
	if mats.size() < int(c["materials"]):
		return LevelUpResult.NO_MATERIAL
	if silver() < int(c["silver"]):
		return LevelUpResult.NOT_ENOUGH
	wallet["silver"] = silver() - int(c["silver"])
	currencies_changed.emit()
	for i in int(c["materials"]):
		state["inventory"].erase(mats[i])
	it["lv"] = item_level(it) + 1
	if is_equipped(uid):
		equipment_changed.emit()
	inventory_changed.emit()
	return LevelUpResult.OK


# ---- 강화 ----

func max_enhance() -> int:
	return int(cfg.get("enhance", {}).get("max_level", 15))


## 다음 강화 비용 {stone, silver}
func enhance_cost(item: Dictionary) -> Dictionary:
	var e: Dictionary = cfg.get("enhance", {})
	var lv := int(item.get("enh", 0))
	return {
		"stone": int(e.get("stone_base", 1)) + int(e.get("stone_per_level", 1)) * lv,
		"silver": int(e.get("silver_base", 50)) + int(e.get("silver_per_level", 50)) * lv,
	}


## 강화한다. 실패 확률은 가안으로 0 (항상 성공, O-25)
func enhance(uid: int, rng: RandomNumberGenerator = null) -> int:
	var it := find(uid)
	if it.is_empty():
		return EnhanceResult.NO_ITEM
	if int(it["enh"]) >= max_enhance():
		return EnhanceResult.MAX_LEVEL
	var c := enhance_cost(it)
	if stone() < int(c["stone"]) or silver() < int(c["silver"]):
		return EnhanceResult.NOT_ENOUGH
	wallet["stone"] = stone() - int(c["stone"])
	wallet["silver"] = silver() - int(c["silver"])
	currencies_changed.emit()
	var rate := float(cfg.get("enhance", {}).get("success_rate", 1.0))
	if rate < 1.0 and rng != null and rng.randf() >= rate:
		return EnhanceResult.FAILED
	it["enh"] = int(it["enh"]) + 1
	if is_equipped(uid):
		equipment_changed.emit()
	inventory_changed.emit()
	return EnhanceResult.OK


# ---- 능력치 ----

## 강화와 장비 레벨이 반영된 기본 능력치 (두 배율을 곱한다)
func item_base_stats(item: Dictionary) -> Dictionary:
	var mult := 1.0 + float(cfg.get("enhance", {}).get("stat_per_level", 0.05)) * int(item.get("enh", 0))
	mult *= 1.0 + float(cfg.get("level_up", {}).get("stat_per_level", 0.1)) * (item_level(item) - 1)
	var out := {}
	var base: Dictionary = item.get("base", {})
	for stat in base.keys():
		out[stat] = float(base[stat]) * mult
	return out


## 장착 장비의 능력치 보너스 (PlayerStats.apply 형식)
func stat_bonuses() -> Dictionary:
	var out := {}
	for slot in state["equipped"].keys():
		var it := equipped_item(slot)
		if it.is_empty():
			continue
		var bs := item_base_stats(it)
		for stat in bs.keys():
			_add(out, stat, "flat", float(bs[stat]))
		for o in it.get("options", []):
			var od := option_data(o["id"])
			if od.has("stat"):
				_add(out, od["stat"], od.get("kind", "flat"), float(o["value"]))
	return out


static func _add(out: Dictionary, stat: String, kind: String, v: float) -> void:
	if not out.has(stat):
		out[stat] = {"flat": 0.0, "percent": 0.0}
	out[stat][kind] = float(out[stat][kind]) + v


## 장착 장비의 특수 효과 합계 (effect 옵션). 예: boss_damage, damage_reduction
func effect_total(effect: String) -> float:
	var total := 0.0
	for slot in state["equipped"].keys():
		var it := equipped_item(slot)
		for o in it.get("options", []):
			var od := option_data(o["id"])
			if od.get("effect", "") == effect and od.get("target", {}).get("type", "all") == "all":
				total += float(o["value"])
	return total


## 초식 피해 증가 합계. 시너지 대상(전체/계열/무공/초식)이 맞는 옵션만 더한다.
## 예: 매화검법 시너지 옵션은 매화검법 초식에만 적용 (docs/06 A-7)
func technique_bonus(tech_id: String, art_id: String, category: String) -> float:
	var total := 0.0
	for slot in state["equipped"].keys():
		var it := equipped_item(slot)
		for o in it.get("options", []):
			var od := option_data(o["id"])
			if od.get("effect", "") != "technique_damage":
				continue
			var tg: Dictionary = od.get("target", {})
			var ok := false
			match tg.get("type", "all"):
				"all":
					ok = true
				"category":
					ok = tg.get("id", "") == category
				"art":
					ok = tg.get("id", "") == art_id
				"technique":
					ok = tg.get("id", "") == tech_id
			if ok:
				total += float(o["value"])
	return total


## 장비 이름 (예: "희귀 무기 +3")
func item_name(item: Dictionary) -> String:
	var n := "%s %s" % [grade_data(item["grade"]).get("name", ""), slot_data(item["slot"]).get("name", "")]
	if item_level(item) > 1:
		n += " Lv%d" % item_level(item)
	if int(item.get("enh", 0)) > 0:
		n += " +%d" % int(item["enh"])
	return n


func grade_color(grade: String) -> Color:
	return Color.html(String(grade_data(grade).get("color", "#ffffff")))


## 옵션 한 줄 설명 (예: "매화검법 초식 피해 +12.0%")
func option_text(o: Dictionary) -> String:
	var od := option_data(o["id"])
	var v := float(o["value"])
	var is_pct: bool = od.get("kind", "") == "percent" or od.has("effect") or od.get("stat", "") == "crit_rate"
	var t := "%s +%s" % [od.get("name", o["id"]), ("%.1f%%" % (v * 100.0)) if is_pct else ("%.1f" % v)]
	if bool(o.get("fixed", false)):
		t += " (고정)"
	return t

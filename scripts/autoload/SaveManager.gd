extends Node
## 저장/불러오기 관리자 (M4). docs/10-save-data.md
## - 로컬 JSON 저장, 최상위 version 필드.
## - 이중 저장: save_a / save_b를 번갈아 쓴다. 임시 파일(*.tmp)에 다 쓴 뒤 이름을 바꿔 교체한다.
## - 해시 검증: 본문 JSON 문자열의 SHA-256을 함께 기록한다.
##   파일 형식: {"format": 1, "checksum": "sha256:…", "payload": "<본문 JSON 문자열>"}
##   (숫자를 다시 직렬화하면 표기가 달라질 수 있어, 본문을 문자열로 담아 쓴 그대로 검증한다)
## - 불러오기: 두 슬롯 중 해시가 맞는 것 가운데 save_seq가 큰 쪽을 쓴다. 둘 다 깨졌으면 load_error에 남긴다.
## - 저장 시점: 주요 이벤트 직후(request_save), 주기(기본 30초), 백그라운드 전환/종료 요청.
## - 마이그레이션: version이 낮으면 migrations[v]를 차례로 적용하고, 원본은 백업으로 남긴다.

signal saved(slot: String, save_seq: int)

const SAVE_DIR := "user://save"
const SLOT_A := "save_a.json"
const SLOT_B := "save_b.json"
const FILE_FORMAT := 1

## 저장 폴더 (테스트에서 바꿔 쓴다)
var save_dir := SAVE_DIR
## 주기 저장 간격(초, 가안 30). 0이면 주기 저장 안 함
var autosave_interval := 30.0
## 마지막으로 쓴 저장 순번과 슬롯
var save_seq := 0
var last_slot := ""
## 마지막 저장 시각 (엔진 시작 후 실제 경과 ms. 시간 배속 영향 없음)
var last_saved_ms := -1
## 불러오기 오류 (두 슬롯 모두 깨짐, 앱 버전이 낮음 등). 비어 있으면 정상
var load_error := ""
## 이번 실행의 부팅 세션 ID (오프라인 시간 판정용, docs/10 5장)
var boot_session_id := ""
## 버전 → 그 버전 데이터를 다음 버전으로 바꾸는 함수 (Callable(data) -> Dictionary)
## 실제 v1 → v2 변환은 저장 구조가 바뀌는 단계에서 추가한다. 테스트는 임시 변환을 넣어 확인한다.
var migrations: Dictionary = {}
## true면 자동 저장(주기, 이벤트, 백그라운드)을 하지 않는다 (테스트용 인스턴스)
var manual_only := false
## 0이 아니면 이 버전을 현재 버전으로 본다 (마이그레이션 테스트용). 0이면 GameState.SAVE_VERSION
var target_version := 0

var _pending_save := false
## 앱이 백그라운드로 간 시각 (모바일 복귀 시 오프라인 계산용)
var _paused_at: Dictionary = {}
var _last_autosave_ms := 0


func _ready() -> void:
	boot_session_id = get_node("/root/TimeService").session_id if has_node("/root/TimeService") else "%x" % (randi() ^ Time.get_ticks_usec())
	if manual_only or not has_node("/root/GameState"):
		return
	var gs = get_node("/root/GameState")
	var result := load_game()
	if result.get("ok", false):
		# 오프라인 판정에 쓸 저장 시각은 apply_loaded가 지우기 전에 꺼내 둔다 (M10)
		var saved_meta := saved_time_of(result["data"])
		gs.apply_loaded(result["data"])
		gs.apply_offline(saved_meta)
		if result.get("migrated", false):
			save_game()
	elif result.get("empty", false):
		# 처음 실행: 새 게임을 바로 저장해 둔다
		save_game()
	else:
		load_error = result.get("error", "")
		push_error("[SaveManager] 불러오기 실패: " + load_error)
	_last_autosave_ms = Time.get_ticks_msec()


func _process(_delta: float) -> void:
	if manual_only:
		return
	if autosave_interval > 0.0 and Time.get_ticks_msec() - _last_autosave_ms >= int(autosave_interval * 1000.0):
		save_game()


func _notification(what: int) -> void:
	if manual_only:
		return
	# 백그라운드 전환(Android 일시 정지), 창 포커스 잃음, 종료 요청 때 저장
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		save_game()
	# 모바일에서 앱이 멈춰 있던 시간도 오프라인 수련으로 계산한다 (M10).
	# 데스크톱 포커스 아웃은 게임이 계속 돌기 때문에 계산하지 않는다.
	if what == NOTIFICATION_APPLICATION_PAUSED and has_node("/root/TimeService"):
		_paused_at = get_node("/root/TimeService").snapshot()
	elif what == NOTIFICATION_APPLICATION_RESUMED and not _paused_at.is_empty() and has_node("/root/GameState"):
		get_node("/root/GameState").apply_offline(_paused_at)
		_paused_at = {}


## 중요 이벤트 직후 저장을 요청한다. 같은 프레임의 요청은 한 번으로 합친다.
func request_save() -> void:
	if manual_only or _pending_save:
		return
	_pending_save = true
	call_deferred("_flush_pending")


func _flush_pending() -> void:
	_pending_save = false
	save_game()


## 게임 상태를 저장한다. state를 주지 않으면 GameState의 상태를 저장한다.
func save_game(state = null) -> bool:
	if state == null:
		if not has_node("/root/GameState"):
			return false
		var gs = get_node("/root/GameState")
		gs.before_save()
		state = gs.data
	var body: Dictionary = state.duplicate(true)
	save_seq += 1
	body["save_seq"] = save_seq
	body["saved_at_unix"] = int(Time.get_unix_time_from_system())
	body["saved_at_monotonic_ms"] = Time.get_ticks_msec()
	body["boot_session_id"] = boot_session_id
	var payload := JSON.stringify(body, "", true)
	var file_text := JSON.stringify({
		"format": FILE_FORMAT,
		"checksum": "sha256:" + payload.sha256_text(),
		"payload": payload,
	})

	DirAccess.make_dir_recursive_absolute(save_dir)
	var slot := SLOT_B if last_slot == SLOT_A else SLOT_A
	var path := save_dir.path_join(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] 임시 파일을 열 수 없음: %s (%d)" % [tmp, FileAccess.get_open_error()])
		save_seq -= 1
		return false
	f.store_string(file_text)
	f.close()
	var dir := DirAccess.open(save_dir)
	if dir.file_exists(slot):
		dir.remove(slot)
	if dir.rename(tmp.get_file(), slot) != OK:
		push_error("[SaveManager] 저장 파일 교체 실패: " + path)
		save_seq -= 1
		return false
	last_slot = slot
	last_saved_ms = Time.get_ticks_msec()
	_last_autosave_ms = last_saved_ms
	saved.emit(slot, save_seq)
	if has_node("/root/EventBus"):
		get_node("/root/EventBus").game_saved.emit()
	return true


## 저장 슬롯 하나를 읽어 검증한다. 반환: {ok, data, seq} 또는 {ok: false, error}
func read_slot(slot: String) -> Dictionary:
	var path := save_dir.path_join(slot)
	if not FileAccess.file_exists(path):
		return {"ok": false, "missing": true, "error": "%s 없음" % slot}
	var text := FileAccess.get_file_as_string(path)
	var outer = JSON.parse_string(text)
	if not (outer is Dictionary) or not outer.has("payload") or not outer.has("checksum"):
		return {"ok": false, "error": "%s 형식 오류" % slot}
	var payload: String = outer["payload"]
	if "sha256:" + payload.sha256_text() != outer["checksum"]:
		return {"ok": false, "error": "%s 해시 불일치" % slot}
	var data = JSON.parse_string(payload)
	if not (data is Dictionary) or not data.has("version"):
		return {"ok": false, "error": "%s 본문 오류" % slot}
	return {"ok": true, "data": data, "seq": int(data.get("save_seq", 0))}


## 저장 데이터를 불러온다. GameState에는 적용하지 않고 결과만 돌려준다.
## 반환: {ok, data, slot, migrated} / {ok: false, empty: true} / {ok: false, error}
func load_game() -> Dictionary:
	var best := {}
	var best_slot := ""
	var errors: PackedStringArray = []
	var missing := 0
	for slot in [SLOT_A, SLOT_B]:
		var r := read_slot(slot)
		if not r["ok"]:
			if r.get("missing", false):
				missing += 1
			else:
				errors.append(r["error"])
				push_warning("[SaveManager] " + r["error"])
			continue
		if best.is_empty() or int(r["seq"]) > int(best["seq"]):
			best = r
			best_slot = slot
	if best.is_empty():
		if missing == 2:
			return {"ok": false, "empty": true}
		return {"ok": false, "error": "저장 파일이 모두 손상됨 (" + ", ".join(errors) + ")"}

	var data: Dictionary = best["data"]
	var current := current_version()
	var version := int(data["version"])
	if version > current:
		return {"ok": false, "error": "저장 데이터 버전(%d)이 앱(%d)보다 높음. 앱 업데이트 필요" % [version, current]}
	var migrated := false
	if version < current:
		_backup(best_slot, version)
		var m := migrate(data, current)
		if not m["ok"]:
			return {"ok": false, "error": m["error"]}
		data = m["data"]
		migrated = true
	save_seq = int(data.get("save_seq", 0))
	last_slot = best_slot
	return {"ok": true, "data": data, "slot": best_slot, "migrated": migrated}


## 저장 데이터의 저장 시각 묶음 {unix, mono_ms, session}
static func saved_time_of(data: Dictionary) -> Dictionary:
	return {
		"unix": int(data.get("saved_at_unix", 0)),
		"mono_ms": int(data.get("saved_at_monotonic_ms", 0)),
		"session": String(data.get("boot_session_id", "")),
	}


func current_version() -> int:
	if target_version > 0:
		return target_version
	if has_node("/root/GameState"):
		return get_node("/root/GameState").SAVE_VERSION
	return 1


## data를 target 버전까지 차례로 변환한다. 중간 변환이 없으면 실패.
func migrate(data: Dictionary, target: int) -> Dictionary:
	var d := data.duplicate(true)
	var v := int(d.get("version", 1))
	while v < target:
		if not migrations.has(v):
			return {"ok": false, "error": "v%d → v%d 마이그레이션 없음" % [v, v + 1]}
		d = migrations[v].call(d)
		v += 1
		d["version"] = v
	return {"ok": true, "data": d}


## 마이그레이션 전에 원본 슬롯을 백업으로 남긴다.
func _backup(slot: String, version: int) -> void:
	var dir := DirAccess.open(save_dir)
	if dir:
		dir.copy(save_dir.path_join(slot), save_dir.path_join("backup_v%d_%s" % [version, slot]))


## 디버그/테스트: 저장 파일을 모두 지운다.
func delete_all() -> void:
	var dir := DirAccess.open(save_dir)
	if dir == null:
		return
	for f in dir.get_files():
		dir.remove(f)
	save_seq = 0
	last_slot = ""

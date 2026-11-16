extends Node
## 임시 효과음 (M11, O-01 미확정이라 임시 적용).
## 외부 음원 없이 코드로 짧은 파형(AudioStreamWAV)을 만들어 쓴다. 정식 사운드가 정해지면 이 파일만 바꾼다.
## 배경음(BGM)은 아직 없다. 음량과 진동은 GameState.data.settings를 따른다.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array = []
var _next := 0
var _last_play_ms: Dictionary = {}
var _bound_arts = null
var _bound_growth = null
## 재생 횟수 (테스트용)
var play_count := 0


func _ready() -> void:
	_streams["technique"] = _tone([660.0, 880.0], 0.08, 0.25)
	_streams["hit"] = _tone([220.0], 0.04, 0.15)
	_streams["mastery"] = _tone([523.0, 659.0, 784.0, 1047.0], 0.5, 0.35)
	_streams["levelup"] = _tone([440.0, 660.0, 880.0], 0.3, 0.3)
	_streams["drop"] = _tone([988.0, 1319.0], 0.15, 0.25)
	_streams["clear"] = _tone([392.0, 523.0, 659.0], 0.4, 0.3)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	var bus = get_node_or_null("/root/EventBus")
	if bus:
		bus.technique_performed.connect(func(_a, _t): play("technique", 120))
		bus.stage_cleared.connect(func(_r, _s): play("clear"))


func _process(_delta: float) -> void:
	# GameState가 새 게임/불러오기로 관리자를 바꾸면 다시 연결한다
	var gs = get_node_or_null("/root/GameState")
	if gs == null:
		return
	if gs.arts != _bound_arts:
		_bound_arts = gs.arts
		gs.arts.technique_mastered.connect(func(_id):
			play("mastery")
			vibrate(120))
	if gs.growth != _bound_growth:
		_bound_growth = gs.growth
		gs.growth.leveled_up.connect(func(_l): play("levelup"))
		gs.growth.realm_promoted.connect(func(_t):
			play("mastery")
			vibrate(200))


func settings() -> Dictionary:
	var gs = get_node_or_null("/root/GameState")
	return gs.data.get("settings", {}) if gs else {}


## 효과음 재생. min_gap_ms 안에 같은 소리를 다시 부르면 건너뛴다 (소리 겹침 방지)
func play(name: String, min_gap_ms: int = 0) -> void:
	if not _streams.has(name):
		return
	var vol := float(settings().get("sfx_volume", 0.8))
	if vol <= 0.0:
		return
	var now := Time.get_ticks_msec()
	if min_gap_ms > 0 and now - int(_last_play_ms.get(name, -100000)) < min_gap_ms:
		return
	_last_play_ms[name] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[name]
	p.volume_db = linear_to_db(vol)
	p.play()
	play_count += 1


func vibrate(ms: int) -> void:
	if bool(settings().get("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


## 음 높이 목록을 차례로 이어 붙인 짧은 소리를 만든다 (사각파 + 감쇠)
func _tone(freqs: Array, total_sec: float, amp: float) -> AudioStreamWAV:
	var per := int(RATE * total_sec / freqs.size())
	var data := PackedByteArray()
	data.resize(per * freqs.size() * 2)
	var idx := 0
	for f in freqs:
		for i in per:
			var t := float(i) / RATE
			var env := 1.0 - float(i) / per
			var v := (1.0 if fmod(t * f, 1.0) < 0.5 else -1.0) * amp * env * env
			var s := int(clampf(v, -1.0, 1.0) * 32767.0)
			data.encode_s16(idx, s)
			idx += 2
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w

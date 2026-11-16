extends SceneTree
## 화면 확인용 스크린샷 도구 (개발용).
## 실행: xvfb-run godot --path . -s res://tests/screenshot.gd -- <출력 경로> [초] [메뉴]
## 메인 화면을 띄우고 지정한 시간만큼 진행한 뒤 화면을 PNG로 저장한다.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://shot.png"
	var sec := float(args[1]) if args.size() > 1 else 3.0
	var menu := args[2] if args.size() > 2 else ""
	var demo := args.size() > 3 and args[3] == "demo"
	var art := args[4] if args.size() > 4 else ""
	await process_frame
	if demo:
		_demo_data(art)
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var ui = main.get_node_or_null("GameUi")
	if ui and ui.tutorial:
		ui.tutorial.visible = false
	if ui and menu != "":
		ui.open_menu(menu)
	await create_timer(sec).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("저장: ", out, " ", img.get_size())
	quit()


## 화면 확인용 예시 데이터: 장비 여러 개(일부 장착·강화), 무공 개방, 초식 수련 단계
func _demo_data(art: String) -> void:
	var gs = root.get_node("GameState")
	gs.reset_to_new_game()
	var eq = gs.equipment
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var slots: Array = eq.slot_ids()
	var grades := ["common", "uncommon", "rare", "epic", "legendary", "mythic"]
	for i in 12:
		var it: Dictionary = eq.generate(slots[i % slots.size()], grades[(i * 2 + 1) % 6], 1.0, rng)
		it["enh"] = (i * 3) % 9
		eq.add_item(it)
		if i < 5:
			eq.equip(int(it["uid"]))
	eq.add_currency("silver", 12400)
	eq.add_currency("stone", 58)
	var arts = gs.arts
	for id in arts.registry.martial_arts.keys():
		arts.unlock(id)
	if art != "":
		arts.equip_main(art)
	# 1~3초식은 대성, 4초식 수련 중 + 연속초식으로 4가지 초식 연출이 모두 나오게 한다
	for t in arts.techniques_of(arts.main_art()):
		arts.debug_set_count(t["id"], 10000 if int(t["order"]) < 4 else 4000)
	arts.set_chain_mode(true)

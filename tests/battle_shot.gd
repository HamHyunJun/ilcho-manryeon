extends SceneTree
## 개발용: 몬스터 공격·피격 연출을 멈춘 화면으로 캡처한다.
## 실행: xvfb-run godot --path . --resolution 1080x2400 -s res://tests/battle_shot.gd -- <출력.png> <normal|boss>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var mode := args[1] if args.size() > 1 else "normal"
	await process_frame
	root.get_node("GameState").reset_to_new_game()
	var main: Node = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await create_timer(0.3).timeout
	var ui = main.get_node_or_null("GameUi")
	if ui and ui.tutorial:
		ui.tutorial.visible = false
	var bm = null
	for c in main.get_children():
		if "effects" in c and "player" in c:
			bm = c
	await create_timer(0.5).timeout
	bm.set_process(false)
	bm._clear_monsters()
	var px: float = bm.player.position.x
	var list: Array
	if mode == "boss":
		list = [["blood_lord", 210, 0.45, false], ["shadow_lord", 470, 0.0, true]]
	else:
		list = [["test_bandit", 150, 0.45, false], ["test_brute", 290, 0.15, false], ["archer", 430, 0.5, false], ["assassin", 560, 0.0, false]]
	for e in list:
		var m = bm.spawn_monster(e[0], 1.0)
		m.position.x = px + float(e[1])
		m._gap = float(e[1]) - 60.0
		m._attack_anim = m.ATTACK_TIME * (1.0 - float(e[2])) if float(e[2]) > 0.0 else 0.0
		if e[3]:
			m.telegraph_pattern = {"telegraph_sec": 1.0, "area": "line"}
			m.telegraph_left = 0.45
	if mode == "normal":
		bm.monsters[3]._hit_flash = 0.07
		bm.monsters[3]._hit_seed = 4
		bm.player._swing = 0.07
	else:
		bm.boss = bm.monsters[1]
	for m in bm.monsters:
		m.queue_redraw()
	bm.player.queue_redraw()
	bm.queue_redraw()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()

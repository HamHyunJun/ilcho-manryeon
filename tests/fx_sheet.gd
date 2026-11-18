extends SceneTree
## 개발용: 12초식 이펙트를 차례로 띄워 캡처한다. 실행: xvfb-run godot --path . -s res://tests/fx_sheet.gd -- <출력 폴더>

func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
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
	await create_timer(2.5).timeout
	var arts := [["plum_blossom_sword", "sword"], ["arhat_fist", "fist"], ["yin_yang_five_elements", "spell"]]
	for a in arts:
		bm.player.set_style(a[1])
		for o in range(1, 5):
			var tech: Dictionary = root.get_node("DataRegistry").get_technique("%s.t%d" % [a[0], o])
			var pos: Array = []
			for m in bm.monsters:
				if not m.is_dead():
					pos.append(m.position)
			if pos.is_empty():
				pos.append(bm.player.position + Vector2(220, 0))
			pos = pos.slice(0, 3)
			bm.effects.play_technique(a[1], 5, bm.player.position + Vector2(bm.player.half_width(), 0), pos, tech)
			bm.player._tech_flash = 0.3
			await create_timer(0.28).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s-%d.png" % [out, a[1], o])
			await create_timer(0.6).timeout
	quit()

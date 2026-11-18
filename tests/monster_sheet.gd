extends SceneTree
## 개발용: 몬스터 12종 그림을 한 장에 모아 캡처한다. 실행: xvfb-run godot --path . -s res://tests/monster_sheet.gd -- <출력.png>

const KINDS := ["bandit", "brute", "masked", "archer", "guard", "blood_soldier", "elite", "chief", "blood_guard", "shadow_lord", "iron_general", "blood_lord"]


class Sheet extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1080, 1100), Color("#93ab9f"))
		for i in KINDS.size():
			var art := ChibiArt.monster(KINDS[i])
			var boss: bool = i >= 7
			var sc := ChibiArt.ART_SCALE * (1.5 if boss else 1.0)
			var feet := Vector2(110 + (i % 4) * 260, 330 + (i / 4) * 360)
			var size: Vector2 = art["size"]
			draw_line(feet + Vector2(-120, 0), feet + Vector2(120, 0), Color("#5a5a4a"), 2)
			ChibiArt.draw_sprite(self, art["body"], size, feet, sc)
			var hand: Vector2 = feet + (Vector2(art["hand"]) - Vector2(size.x * 0.5, size.y)) * sc
			ChibiArt.draw_weapon(self, art["weapon"], art["weapon_pivot"], hand, -0.45, sc)
			ChibiArt.draw_sprite(self, art["ko"], size, feet + Vector2(80, 0), sc * 0.4)


func _initialize() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var s := Sheet.new()
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(s)
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	quit()

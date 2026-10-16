class_name EndScreen
extends Control
## The closing epilogue: lines of text over a snowy page, then the title.

func play(lines: Array) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.93, 0.93, 0.95)
	add_child(bg)
	var snow := SnowOverlay.new()
	snow.set_anchors_preset(Control.PRESET_FULL_RECT)
	snow.color = Color(0.6, 0.65, 0.75)
	add_child(snow)
	modulate.a = 0.0
	await create_tween().tween_property(self, "modulate:a", 1.0, 3.0).finished
	var lbl := UITheme.label("", UITheme.font_serif(), 40, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(lbl)
	UITheme.place(lbl, 0.5, 0.5, -600, -120, 600, 120)
	for l in lines:
		lbl.text = Loc.pick(l)
		lbl.modulate.a = 0.0
		var hold := 2.5 + lbl.text.split(" ").size() * 0.32
		var t := create_tween()
		t.tween_property(lbl, "modulate:a", 1.0, 1.6)
		t.tween_interval(hold)
		t.tween_property(lbl, "modulate:a", 0.0, 1.4)
		await t.finished
		await get_tree().create_timer(0.6).timeout
	var title := UITheme.label("GAME_TITLE", UITheme.spaced(UITheme.font_title(), 18), 120, UITheme.INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.modulate.a = 0.0
	add_child(title)
	UITheme.place(title, 0.5, 0.5, -700, -130, 700, 40)
	var bird := BullfinchMark.new()
	bird.modulate.a = 0.0
	add_child(bird)
	UITheme.place(bird, 0.5, 0.5, -40, 60, 40, 125)
	var t2 := create_tween()
	t2.tween_property(title, "modulate:a", 1.0, 2.5)
	t2.parallel().tween_property(bird, "modulate:a", 1.0, 3.5)
	t2.tween_interval(5.0)
	await t2.finished

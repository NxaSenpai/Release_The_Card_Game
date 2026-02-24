extends Control

var floating_cards: Array = []
var card_fan_nodes: Array = []
var time_elapsed: float = 0.0
var title_base_y: float = 0.0
var bg_base_modulate: Color
var is_transitioning: bool = false
var original_position: Vector2
var screen_shake_intensity: float = 0.0

# Glitch shader
var glitch_rect: ColorRect
var glitch_material: ShaderMaterial
var glitch_shader = preload("res://shaders/glitch.gdshader")

# CRT ambient shader
var crt_rect: ColorRect
var crt_material: ShaderMaterial
var crt_shader = preload("res://shaders/crt.gdshader")

# Font
var custom_font = preload("res://fonts/Unitblock-JpJma.ttf")

# Card textures for the decorative fan
var fan_card_paths = [
	"res://textures/card_background/cardSpadesA.png",
	"res://textures/card_background/cardHeartsK.png",
	"res://textures/card_background/cardDiamondsQ.png",
	"res://textures/card_background/cardClubsJ.png",
	"res://textures/card_background/cardHearts10.png",
]

func _ready():
	modulate.a = 0
	original_position = position

	if has_node("Background"):
		bg_base_modulate = $Background.modulate

	setup_glitch_shader()
	setup_crt_shader()
	spawn_card_fan()
	spawn_floating_cards()

	await get_tree().process_frame
	animate_entrance()

func _process(delta):
	time_elapsed += delta

	# Screen shake
	if screen_shake_intensity > 0:
		position = original_position + Vector2(
			randf_range(-screen_shake_intensity, screen_shake_intensity),
			randf_range(-screen_shake_intensity, screen_shake_intensity)
		)
		screen_shake_intensity = lerp(screen_shake_intensity, 0.0, delta * 10)
	else:
		position = original_position

	# Subtle title float
	if has_node("CenterContainer/TitleLabel") and not is_transitioning:
		var title = $CenterContainer/TitleLabel
		title.position.y = title_base_y + sin(time_elapsed * 1.5) * 3.0

	# Move floating cards
	for card_data in floating_cards:
		if is_instance_valid(card_data["node"]):
			var node = card_data["node"] as Control
			card_data["angle"] += delta * card_data["speed"]
			node.position.x = card_data["start_x"] + sin(card_data["angle"]) * card_data["sway"]
			node.position.y += card_data["drift"] * delta
			node.rotation_degrees = sin(card_data["angle"] * 0.7) * card_data["rotation_range"]
			if node.position.y > get_viewport_rect().size.y + 100:
				node.position.y = -200
				node.position.x = randf_range(0, get_viewport_rect().size.x)

	# Subtle background breathing
	if has_node("Background") and bg_base_modulate != null:
		var breath = sin(time_elapsed * 0.8) * 0.03
		$Background.modulate = Color(
			bg_base_modulate.r + breath,
			bg_base_modulate.g + breath * 1.5,
			bg_base_modulate.b + breath,
			1.0
		)

func shake_screen(intensity: float = 8.0):
	screen_shake_intensity = intensity

# -------------------------------------------------------
# SHADERS
# -------------------------------------------------------
func setup_glitch_shader():
	var canvas = CanvasLayer.new()
	canvas.name = "GlitchCanvas"
	canvas.layer = 10
	add_child(canvas)

	glitch_rect = ColorRect.new()
	glitch_rect.name = "GlitchRect"
	glitch_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	glitch_material = ShaderMaterial.new()
	glitch_material.shader = glitch_shader
	glitch_material.set_shader_parameter("shake_power", 0.01)
	glitch_material.set_shader_parameter("shake_rate", 0.0)
	glitch_material.set_shader_parameter("shake_speed", 3.0)
	glitch_material.set_shader_parameter("shake_block_size", 30.5)
	glitch_material.set_shader_parameter("shake_color_rate", 0.003)

	glitch_rect.material = glitch_material
	canvas.add_child(glitch_rect)

func setup_crt_shader():
	var canvas = CanvasLayer.new()
	canvas.name = "CRTCanvas"
	canvas.layer = 9
	add_child(canvas)

	crt_rect = ColorRect.new()
	crt_rect.name = "CRTRect"
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	crt_material = ShaderMaterial.new()
	crt_material.shader = crt_shader
	crt_material.set_shader_parameter("overlay", false)
	crt_material.set_shader_parameter("scanlines_opacity", 0.08)
	crt_material.set_shader_parameter("scanlines_width", 0.25)
	crt_material.set_shader_parameter("grille_opacity", 0.03)
	crt_material.set_shader_parameter("resolution", Vector2(1152.0, 648.0))
	crt_material.set_shader_parameter("pixelate", false)
	crt_material.set_shader_parameter("roll", true)
	crt_material.set_shader_parameter("roll_speed", 0.8)
	crt_material.set_shader_parameter("roll_size", 5.0)
	crt_material.set_shader_parameter("roll_variation", 1.8)
	crt_material.set_shader_parameter("distort_intensity", 0.001)
	crt_material.set_shader_parameter("noise_opacity", 0.02)
	crt_material.set_shader_parameter("noise_speed", 2.0)
	crt_material.set_shader_parameter("static_noise_intensity", 0.008)
	crt_material.set_shader_parameter("aberration", 0.005)
	crt_material.set_shader_parameter("brightness", 1.02)
	crt_material.set_shader_parameter("discolor", false)
	crt_material.set_shader_parameter("warp_amount", 0.2)
	crt_material.set_shader_parameter("clip_warp", false)
	crt_material.set_shader_parameter("vignette_intensity", 0.2)
	crt_material.set_shader_parameter("vignette_opacity", 0.25)

	crt_rect.material = crt_material
	canvas.add_child(crt_rect)

	# Apply saved setting
	var gs = get_node_or_null("/root/GameSettings")
	if gs and crt_rect:
		crt_rect.visible = gs.crt_enabled

# -------------------------------------------------------
# EFFECTS
# -------------------------------------------------------
func glitch_effect(intensity: float = 1.0):
	var gs = get_node_or_null("/root/GameSettings")
	if gs and not gs.glitch_enabled:
		return
	var gs_scale = gs.glitch_intensity if gs else 1.0  # renamed from 'scale'
	intensity *= gs_scale

	if glitch_material:
		var glitch_rate = clamp(intensity * 0.55, 0.0, 1.0)
		var glitch_power = clamp(intensity * 0.06, 0.0, 0.25)
		var glitch_color_rate = clamp(intensity * 0.025, 0.0, 0.12)
		var glitch_speed = clamp(5.0 + intensity * 8.0, 5.0, 40.0)
		var glitch_block = clamp(30.5 - intensity * 4.0, 8.0, 30.5)

		glitch_material.set_shader_parameter("shake_rate", glitch_rate)
		glitch_material.set_shader_parameter("shake_power", glitch_power)
		glitch_material.set_shader_parameter("shake_color_rate", glitch_color_rate)
		glitch_material.set_shader_parameter("shake_speed", glitch_speed)
		glitch_material.set_shader_parameter("shake_block_size", glitch_block)

		var shader_tween = create_tween()
		shader_tween.tween_interval(0.05 + intensity * 0.03)
		shader_tween.tween_method(
			func(val: float):
				if glitch_material:
					glitch_material.set_shader_parameter("shake_rate", val)
					glitch_material.set_shader_parameter("shake_power", val * 0.11)
					glitch_material.set_shader_parameter("shake_color_rate", val * 0.045)
					glitch_material.set_shader_parameter("shake_speed", 5.0 + val * 15.0)
					glitch_material.set_shader_parameter("shake_block_size", 30.5 - val * 6.0),
			glitch_rate,
			0.0,
			0.25 + intensity * 0.18
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1152, 648)

	for i in range(randi_range(4, 8)):
		var strip = ColorRect.new()
		var strip_height = randf_range(3, 12) * intensity
		strip.size = Vector2(viewport_size.x, strip_height)
		strip.position = Vector2(randf_range(-30, 30) * intensity, randf_range(0, viewport_size.y))
		strip.color = [Color(1, 0, 0, 0.30), Color(0, 1, 0.5, 0.22), Color(0, 0.3, 1, 0.28)][i % 3]
		strip.z_index = 90
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(strip)

		var strip_tween = create_tween().set_parallel(true)
		strip_tween.tween_property(strip, "position:x", strip.position.x + randf_range(-50, 50) * intensity, randf_range(0.04, 0.12))
		strip_tween.tween_property(strip, "modulate:a", 0.0, randf_range(0.06, 0.15))
		strip_tween.tween_callback(strip.queue_free).set_delay(0.18)

	if intensity > 0.5:
		var red_rect = ColorRect.new()
		red_rect.size = viewport_size
		red_rect.position = Vector2(randf_range(5, 12) * intensity, 0)
		red_rect.color = Color(1, 0, 0, clamp(0.12 * intensity, 0.0, 0.35))
		red_rect.z_index = 88
		red_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(red_rect)

		var blue_rect = ColorRect.new()
		blue_rect.size = viewport_size
		blue_rect.position = Vector2(randf_range(-12, -5) * intensity, 0)
		blue_rect.color = Color(0, 0.2, 1, clamp(0.12 * intensity, 0.0, 0.35))
		blue_rect.z_index = 88
		blue_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(blue_rect)

		var rgb_tween = create_tween().set_parallel(true)
		rgb_tween.tween_property(red_rect, "modulate:a", 0.0, 0.10)
		rgb_tween.tween_property(blue_rect, "modulate:a", 0.0, 0.10)
		rgb_tween.tween_callback(red_rect.queue_free).set_delay(0.12)
		rgb_tween.tween_callback(blue_rect.queue_free).set_delay(0.12)

	var jitter = intensity * 5.0
	var jitter_tween = create_tween()
	jitter_tween.tween_property(self, "position", original_position + Vector2(randf_range(-jitter, jitter), randf_range(-jitter * 0.5, jitter * 0.5)), 0.02)
	jitter_tween.tween_property(self, "position", original_position + Vector2(randf_range(-jitter * 0.5, jitter * 0.5), randf_range(-jitter * 0.3, jitter * 0.3)), 0.02)
	jitter_tween.tween_property(self, "position", original_position, 0.03)

func button_press_effect(button: Button):
	button.pivot_offset = button.size / 2
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.85, 0.85), 0.04)
	tween.tween_property(button, "scale", Vector2(1.12, 1.12), 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.08)

	var original_modulate = button.modulate
	var flash_tween = create_tween()
	flash_tween.tween_property(button, "modulate", Color(1.4, 1.3, 1.1, 1), 0.05)
	flash_tween.tween_property(button, "modulate", original_modulate, 0.15)

# -------------------------------------------------------
# SPAWNING
# -------------------------------------------------------
func spawn_card_fan():
	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1152, 648)

	var center_x = viewport_size.x / 2.0
	var center_y = viewport_size.y / 2.0 - 40
	var fan_spread = 12.0
	var card_count = fan_card_paths.size()

	for i in range(card_count):
		var path = fan_card_paths[i]
		if not FileAccess.file_exists(path):
			continue

		var card_rect = TextureRect.new()
		card_rect.texture = load(path)
		card_rect.custom_minimum_size = Vector2(100, 140)
		card_rect.size = Vector2(100, 140)
		card_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_rect.z_index = -1
		card_rect.pivot_offset = Vector2(50, 140)
		card_rect.position = Vector2(center_x - 50, center_y - 100)

		var angle = (i - card_count / 2.0) * fan_spread
		card_rect.rotation_degrees = angle
		card_rect.modulate = Color(1, 1, 1, 0)

		add_child(card_rect)
		move_child(card_rect, 2)
		card_fan_nodes.append(card_rect)

func spawn_floating_cards():
	var viewport_size = get_viewport_rect().size
	if viewport_size == Vector2.ZERO:
		viewport_size = Vector2(1152, 648)

	var suit_symbols = ["♥", "♠", "♦", "♣"]
	var suit_colors = [
		Color(1, 0.4, 0.35, 0.12),
		Color(0.9, 0.95, 0.85, 0.1),
		Color(1, 0.4, 0.35, 0.12),
		Color(0.9, 0.95, 0.85, 0.1)
	]

	for i in range(8):
		var card_rect = ColorRect.new()
		card_rect.custom_minimum_size = Vector2(45, 65)
		card_rect.size = Vector2(45, 65)
		card_rect.color = Color(1, 1, 0.9, 0.04)
		card_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_rect.z_index = -2

		var suit_label = Label.new()
		suit_label.text = suit_symbols[i % 4]
		suit_label.add_theme_font_size_override("font_size", 18)
		suit_label.add_theme_color_override("font_color", suit_colors[i % 4])
		suit_label.position = Vector2(12, 18)
		suit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_rect.add_child(suit_label)

		card_rect.position = Vector2(
			randf_range(0, viewport_size.x),
			randf_range(-200, viewport_size.y)
		)
		card_rect.pivot_offset = Vector2(22, 32)
		card_rect.modulate.a = 0

		add_child(card_rect)
		move_child(card_rect, 1)

		floating_cards.append({
			"node": card_rect,
			"start_x": card_rect.position.x,
			"angle": randf_range(0, TAU),
			"speed": randf_range(0.2, 0.5),
			"sway": randf_range(20, 60),
			"drift": randf_range(8, 20),
			"rotation_range": randf_range(3, 10)
		})

		var fade_tween = create_tween()
		fade_tween.tween_property(card_rect, "modulate:a", 1.0, randf_range(0.8, 2.5)).set_delay(randf_range(0.3, 2.0))

# -------------------------------------------------------
# ANIMATION
# -------------------------------------------------------
func animate_entrance():
	var main_tween = create_tween()
	main_tween.tween_property(self, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)

	for i in range(card_fan_nodes.size()):
		var card = card_fan_nodes[i]
		var target_rotation = card.rotation_degrees
		card.rotation_degrees = 0
		card.modulate = Color(1, 1, 1, 0)
		card.scale = Vector2(0.5, 0.5)

		var delay = 0.3 + i * 0.1
		var fan_tween = create_tween().set_parallel(true)
		fan_tween.tween_property(card, "modulate:a", 0.5, 0.3).set_delay(delay)
		fan_tween.tween_property(card, "rotation_degrees", target_rotation, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		fan_tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT).set_delay(delay)

	if has_node("CenterContainer/TitleLabel"):
		var title = $CenterContainer/TitleLabel
		title_base_y = title.position.y
		var target_y = title.position.y
		title.position.y = -120
		title.modulate.a = 0

		var title_tween = create_tween().set_parallel(true)
		title_tween.tween_property(title, "position:y", target_y, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
		title_tween.tween_property(title, "modulate:a", 1.0, 0.35).set_delay(0.15)

	if has_node("CenterContainer/SubtitleLabel"):
		var sub = $CenterContainer/SubtitleLabel
		sub.modulate.a = 0
		var sub_tween = create_tween()
		sub_tween.tween_property(sub, "modulate:a", 1.0, 0.5).set_delay(0.6)

	# Buttons — Play, HowToPlay, Settings, Exit in order
	var buttons = []
	if has_node("CenterContainer/PlayButton"):
		buttons.append($CenterContainer/PlayButton)
	if has_node("CenterContainer/HowToPlayButton"):
		buttons.append($CenterContainer/HowToPlayButton)
	if has_node("CenterContainer/SettingsButton"):
		buttons.append($CenterContainer/SettingsButton)
	if has_node("CenterContainer/ExitButton"):
		buttons.append($CenterContainer/ExitButton)

	for i in range(buttons.size()):
		var btn = buttons[i]
		var original_y = btn.position.y
		btn.position.y += 80
		btn.modulate.a = 0
		btn.pivot_offset = btn.size / 2
		btn.scale = Vector2(0.85, 0.85)

		var delay = 0.5 + i * 0.12
		var btn_tween = create_tween().set_parallel(true)
		btn_tween.tween_property(btn, "position:y", original_y, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)
		btn_tween.tween_property(btn, "modulate:a", 1.0, 0.3).set_delay(delay)
		btn_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(delay)

	if has_node("VersionLabel"):
		$VersionLabel.modulate.a = 0
		var v_tween = create_tween()
		v_tween.tween_property($VersionLabel, "modulate:a", 0.4, 0.8).set_delay(1.2)

# -------------------------------------------------------
# BUTTON HANDLERS
# -------------------------------------------------------
func _on_play_button_pressed():
	if is_transitioning:
		return
	is_transitioning = true
	button_press_effect($CenterContainer/PlayButton)
	shake_screen(6.0)
	glitch_effect(2.8)

	await get_tree().create_timer(0.18).timeout

	var transition = get_tree().root.get_node_or_null("SceneTransition")
	if transition:
		transition.transition_with_fade("res://scenes/main.tscn", 0.5)
	else:
		var fade = create_tween()
		fade.tween_property(self, "modulate:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
		await fade.finished
		get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_how_to_play_button_pressed():
	if is_transitioning:
		return
	button_press_effect($CenterContainer/HowToPlayButton)
	shake_screen(3.0)
	glitch_effect(1.0)
	# Show the existing HowToPlayPanel from the scene
	if has_node("HowToPlayPanel"):
		var panel = $HowToPlayPanel
		panel.visible = true
		panel.modulate.a = 0
		panel.scale = Vector2(0.9, 0.9)
		panel.pivot_offset = panel.size / 2
		if has_node("DimOverlay"):
			$DimOverlay.visible = true
			$DimOverlay.modulate.a = 0
			var d = create_tween()
			d.tween_property($DimOverlay, "modulate:a", 1.0, 0.2)
		var t = create_tween().set_parallel(true)
		t.tween_property(panel, "modulate:a", 1.0, 0.2)
		t.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _on_close_button_pressed():
	if has_node("HowToPlayPanel"):
		button_press_effect($CenterContainer/SettingsButton)
		shake_screen(4.0)
		glitch_effect(1.2)
		var panel = $HowToPlayPanel
		var t = create_tween().set_parallel(true)
		t.tween_property(panel, "modulate:a", 0.0, 0.15)
		t.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.15)
		t.tween_callback(func():
			panel.visible = false
			panel.scale = Vector2(1.0, 1.0)
		).set_delay(0.15)
		if has_node("DimOverlay"):
			var d = create_tween()
			d.tween_property($DimOverlay, "modulate:a", 0.0, 0.15)
			d.tween_callback(func(): $DimOverlay.visible = false)

func _on_settings_button_pressed():
	if is_transitioning:
		return
	button_press_effect($CenterContainer/SettingsButton)
	shake_screen(4.0)
	glitch_effect(1.2)
	open_settings()

func _on_exit_button_pressed():
	button_press_effect($CenterContainer/ExitButton)
	shake_screen(5.0)
	glitch_effect(2.0)
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

# -------------------------------------------------------
# SETTINGS PANEL
# -------------------------------------------------------
func open_settings():
	if has_node("SettingsPanel"):
		return

	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		push_error("GameSettings autoload not found!")
		return

	# Dim overlay
	if has_node("DimOverlay"):
		$DimOverlay.visible = true
		$DimOverlay.modulate.a = 0
		var d = create_tween()
		d.tween_property($DimOverlay, "modulate:a", 1.0, 0.2)

	# --- Panel ---
	var panel = PanelContainer.new()
	panel.name = "SettingsPanel"
	panel.z_index = 200

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.04, 0.02, 0.97)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.7, 0.55, 0.2, 0.9)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_size = 12
	style.shadow_color = Color(0, 0, 0, 0.6)
	panel.add_theme_stylebox_override("panel", style)

	# Use same anchor approach as HowToPlayPanel
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230.0
	panel.offset_top = -240.0
	panel.offset_right = 230.0
	panel.offset_bottom = 240.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0, 1))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_font_override("font", custom_font)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# CRT toggle
	vbox.add_child(_make_toggle("CRT Screen Effect", gs.crt_enabled, func(val: bool):
		gs.crt_enabled = val
		gs.save_settings()
		_apply_settings_to_scene()
	))

	# Glitch toggle
	vbox.add_child(_make_toggle("Glitch Effect", gs.glitch_enabled, func(val: bool):
		gs.glitch_enabled = val
		gs.save_settings()
		_apply_settings_to_scene()
	))

	# Glitch intensity
	vbox.add_child(_make_label("Glitch Intensity"))
	var glitch_slider = HSlider.new()
	glitch_slider.min_value = 0.1
	glitch_slider.max_value = 2.0
	glitch_slider.step = 0.05
	glitch_slider.value = gs.glitch_intensity
	glitch_slider.custom_minimum_size.y = 28
	glitch_slider.value_changed.connect(func(val: float):
		gs.glitch_intensity = val
		gs.save_settings()
	)
	vbox.add_child(glitch_slider)

	# Screen shake toggle
	vbox.add_child(_make_toggle("Screen Shake", gs.screen_shake_enabled, func(val: bool):
		gs.screen_shake_enabled = val
		gs.save_settings()
	))

	# Screen shake intensity
	vbox.add_child(_make_label("Shake Intensity"))
	var shake_slider = HSlider.new()
	shake_slider.min_value = 0.0
	shake_slider.max_value = 2.0
	shake_slider.step = 0.05
	shake_slider.value = gs.screen_shake_intensity
	shake_slider.custom_minimum_size.y = 28
	shake_slider.value_changed.connect(func(val: float):
		gs.screen_shake_intensity = val
		gs.save_settings()
	)
	vbox.add_child(shake_slider)

	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Close button
	var close_style = StyleBoxFlat.new()
	close_style.bg_color = Color(0.15, 0.06, 0.04, 0.85)
	close_style.border_width_left = 2
	close_style.border_width_top = 2
	close_style.border_width_right = 2
	close_style.border_width_bottom = 2
	close_style.border_color = Color(0.7, 0.3, 0.2, 0.6)
	close_style.corner_radius_top_left = 8
	close_style.corner_radius_top_right = 8
	close_style.corner_radius_bottom_right = 8
	close_style.corner_radius_bottom_left = 8

	var close_style_hover = StyleBoxFlat.new()
	close_style_hover.bg_color = Color(0.25, 0.1, 0.06, 1)
	close_style_hover.border_width_left = 2
	close_style_hover.border_width_top = 2
	close_style_hover.border_width_right = 2
	close_style_hover.border_width_bottom = 2
	close_style_hover.border_color = Color(0.9, 0.4, 0.3, 0.9)
	close_style_hover.corner_radius_top_left = 8
	close_style_hover.corner_radius_top_right = 8
	close_style_hover.corner_radius_bottom_right = 8
	close_style_hover.corner_radius_bottom_left = 8

	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(0, 50)
	close_btn.add_theme_font_override("font", custom_font)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.85, 0.5, 0.4, 1))
	close_btn.add_theme_color_override("font_hover_color", Color(1, 0.65, 0.5, 1))
	close_btn.add_theme_stylebox_override("normal", close_style)
	close_btn.add_theme_stylebox_override("hover", close_style_hover)
	close_btn.pressed.connect(func():
		if has_node("DimOverlay"):
			button_press_effect($CenterContainer/SettingsButton)
			shake_screen(4.0)
			glitch_effect(1.2)
			var d = create_tween()
			d.tween_property($DimOverlay, "modulate:a", 0.0, 0.15)
			d.tween_callback(func(): $DimOverlay.visible = false)
		var close_tween = create_tween().set_parallel(true)
		close_tween.tween_property(panel, "modulate:a", 0.0, 0.15)
		close_tween.tween_property(panel, "scale", Vector2(0.9, 0.9), 0.15)
		close_tween.tween_callback(panel.queue_free).set_delay(0.16)
	)
	vbox.add_child(close_btn)

	add_child(panel)

	# Animate in — same as HowToPlayPanel
	panel.modulate.a = 0
	panel.scale = Vector2(0.9, 0.9)
	panel.pivot_offset = panel.size / 2
	var open_tween = create_tween().set_parallel(true)
	open_tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	open_tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_toggle(label_text: String, default_val: bool, callback: Callable) -> HBoxContainer:
	var hbox = HBoxContainer.new()

	var lbl = Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", 19)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 1))
	hbox.add_child(lbl)

	var chk = CheckButton.new()
	chk.button_pressed = default_val
	chk.toggled.connect(callback)
	hbox.add_child(chk)
	return hbox

func _make_label(text: String) -> Label:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", custom_font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 1))
	return lbl

func _apply_settings_to_scene():
	var gs = get_node_or_null("/root/GameSettings")
	if not gs:
		return
	if crt_rect:
		crt_rect.visible = gs.crt_enabled
	if glitch_rect:
		glitch_rect.visible = gs.glitch_enabled
	var main = get_tree().root.get_node_or_null("Main")
	if main:
		var crt_node = main.get_node_or_null("CRTCanvas/CRTRect")
		if crt_node:
			crt_node.visible = gs.crt_enabled
		var glitch_node = main.get_node_or_null("GlitchCanvas/GlitchRect")
		if glitch_node:
			glitch_node.visible = gs.glitch_enabled

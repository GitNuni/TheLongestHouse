class_name BodycamHUD
extends CanvasLayer
## Diegetic bodycam overlay (per the GDD: HUD lives inside the camera
## fiction, not floating game UI). Builds all its Controls in code; only the
## screen shader is an external file.
##
## Everything on screen is something a real body-worn camera would show —
## REC light, timestamp, battery — plus the department's "smart" additions:
## round counter and evidence sync. The horror channels (static, possession
## red) are driven through the full-screen shader.

const SCREEN_SHADER := preload("res://assets/shaders/bodycam.gdshader")

var _screen: ColorRect
var _shader_material: ShaderMaterial
var _rec_label: Label
var _info_label: Label
var _ammo_label: Label
var _evidence_label: Label
var _tag_label: Label
var _alert_label: Label
var _crosshair: Label

var _static_amount := 0.0
var _possession := 0.0
var _possessed := false
var _battery := 93.0
var _blink_time := 0.0


func _ready() -> void:
	_screen = ColorRect.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = SCREEN_SHADER
	_screen.material = _shader_material
	add_child(_screen)

	_rec_label = _make_label(Control.PRESET_TOP_LEFT, Vector2(24, 16))
	_rec_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_info_label = _make_label(Control.PRESET_TOP_RIGHT, Vector2(-320, 16))
	_info_label.size = Vector2(300, 60)
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ammo_label = _make_label(Control.PRESET_BOTTOM_LEFT, Vector2(24, -48))
	_evidence_label = _make_label(Control.PRESET_BOTTOM_RIGHT, Vector2(-320, -48))
	_evidence_label.size = Vector2(300, 30)
	_evidence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_crosshair = _make_label(Control.PRESET_CENTER, Vector2(-4, -12))
	_crosshair.text = "·"
	_tag_label = _make_label(Control.PRESET_CENTER, Vector2(-70, 30))
	_tag_label.size = Vector2(140, 24)
	_tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tag_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))

	_alert_label = _make_label(Control.PRESET_CENTER, Vector2(-150, -60))
	_alert_label.size = Vector2(300, 60)
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 34)
	_alert_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	_alert_label.visible = false


func _make_label(preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.set_anchors_preset(preset)
	label.position += offset
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.85, 0.88, 0.85))
	label.add_theme_font_size_override("font_size", 15)
	_screen.add_child(label)
	return label


func attach(player: Player, generator: HouseGenerator) -> void:
	player.health_changed.connect(_on_health_changed)
	player.ammo_changed.connect(_on_ammo_changed)
	player.tag_progress_changed.connect(_on_tag_progress)
	player.possession_changed.connect(_on_possession_changed)
	player.static_flash.connect(func() -> void: _static_amount = 1.0)
	player.died.connect(_on_died)
	player.respawned.connect(_on_respawned)
	generator.evidence_logged.connect(_on_evidence_logged)
	_on_ammo_changed(player.ammo_loaded, player.ammo_reserve)
	_on_evidence_logged(0, generator.evidence_total)


func _process(delta: float) -> void:
	_blink_time += delta
	_battery = maxf(1.0, _battery - delta * 0.012)

	var now := Time.get_datetime_dict_from_system()
	var rec_dot := "●" if fmod(_blink_time, 1.2) < 0.7 else " "
	_rec_label.text = "%s REC  %02d:%02d:%02d" % [rec_dot, now["hour"],
			now["minute"], now["second"]]
	_info_label.text = "AXON BODY 3\nOFC. UNIT-2  BAT %d%%" % int(_battery)

	_static_amount = maxf(0.0, _static_amount - delta * 1.8)
	_possession = move_toward(_possession, 1.0 if _possessed else 0.0, delta * 1.5)
	_shader_material.set_shader_parameter("static_amount", _static_amount)
	_shader_material.set_shader_parameter("possession", _possession)
	# Grain worsens as the battery dies. The camera is also mortal.
	_shader_material.set_shader_parameter("grain_amount",
			lerpf(0.1, 0.28, 1.0 - _battery / 100.0))


func _on_health_changed(value: int) -> void:
	if value < 40:
		_alert_label.visible = true
		_alert_label.text = "VITALS CRITICAL"
	elif _alert_label.text == "VITALS CRITICAL":
		_alert_label.visible = false


func _on_ammo_changed(loaded: int, reserve: int) -> void:
	_ammo_label.text = "RND %d / %d" % [loaded, reserve]


func _on_tag_progress(progress: float) -> void:
	if progress <= 0.0:
		_tag_label.text = ""
		return
	var filled := int(progress * 10.0)
	_tag_label.text = "TAGGING " + "|".repeat(filled) + "-".repeat(10 - filled)


func _on_evidence_logged(count: int, total: int) -> void:
	_evidence_label.text = "EVIDENCE SYNC %d/%d" % [count, total]
	if count >= total and total > 0:
		_alert_label.visible = true
		_alert_label.text = "CASE FILE COMPLETE — RETURN TO EXIT"


func _on_possession_changed(active: bool) -> void:
	_possessed = active


func _on_died() -> void:
	_static_amount = 1.0
	_alert_label.visible = true
	_alert_label.text = "SIGNAL LOST"


func _on_respawned() -> void:
	_alert_label.visible = false
	_static_amount = 1.0

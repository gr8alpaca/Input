@tool
class_name InputTexture extends Texture2D

const Settings:= preload("settings.gd")

@export var event: InputEvent: set = set_event

@export var force_joy_only: bool = false:
	set(val):
		if force_joy_only == val: return
		force_joy_only = val
		update_texture()
		notify_property_list_changed()

@export var force_platform: InputData.DeviceType = InputData.DeviceType.INVALID:
	set(val):
		force_platform = val
		update_texture()
 
var input_data: InputData
var texture: Texture2D: set = set_texture

func _init() -> void:
	input_data = Settings.get_input_data()
	if input_data and not Engine.is_editor_hint():
		Input.connect(InputData.SIGNALS.DEVICE_CHANGED.name, _on_device_type_changed)
		Input.connect(InputData.SIGNALS.ACTION_CHANGED.name, _on_action_changed)

func _on_device_type_changed(device_type: InputData.DeviceType) -> void:
	if not force_joy_only and force_platform != InputData.DeviceType.INVALID:
		return
	update_texture()

func _on_action_changed(action: StringName) -> void:
	if event is InputEventAction and event.action == action:
		update_texture()

func update_texture() -> void:
	texture = get_input_texture()

func has_texture() -> bool:
	return texture != null

func get_joy_device() -> InputData.DeviceType:
	if input_data and input_data.is_joypad_active():
		return input_data.current_device_type
	return InputData.DeviceType.DEFAULT_JOYSTICK

func get_input_texture() -> Texture2D:
	if not input_data:
		input_data = Settings.get_input_data()
		if not input_data:
			push_warning("No 'input_data' set -- Cannot update %s." % self)
			return null
	
	if force_joy_only:
		return input_data.get_event_texture(event, get_joy_device())
	
	return input_data.get_event_texture(event, force_platform)

func set_texture(val: Texture2D):
		#if texture == val: return
		texture = val
		emit_changed()

func set_event(val: InputEvent) -> void:
	if event == val: return
	if event and event.changed.is_connected(update_texture):
		event.changed.disconnect(update_texture)
	event = val
	if event and Engine.is_editor_hint():
		event.changed.connect(update_texture)
	
	update_texture()

func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if texture: texture.draw(to_canvas_item, pos, modulate, transpose)

func _draw_rect(to_canvas_item: RID, rect: Rect2, tile: bool, modulate: Color, transpose: bool) -> void:
	if texture: texture.draw_rect(to_canvas_item, rect, tile, modulate, transpose)
	
func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if texture: texture.draw_rect_region(to_canvas_item, rect, src_rect, modulate, transpose, clip_uv)
	
func _get_height() -> int:
	return texture.get_height() if texture else 0

func _get_width() -> int:
	return texture.get_width() if texture else 0

func _has_alpha() -> bool:
	return texture.has_alpha() if texture else false

func _validate_property(property: Dictionary) -> void:
	if force_joy_only and property.name == "force_platform":
		property.usage &= ~PROPERTY_USAGE_EDITOR

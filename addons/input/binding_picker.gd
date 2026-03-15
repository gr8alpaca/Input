@tool
class_name BindingPicker extends Button

const Settings:= preload("settings.gd")

enum {MOUSE_BUTTONS = 1, KEYS = 2, JOYPAD_BUTTONS = 4, JOYPAD_MOTION = 8}

signal binding_rejected(event: InputEvent)
signal binding_changed(event: InputEvent)

signal listening_started
signal listening_finished

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin,loose_mode") 
var action: StringName: set = set_action, get = get_action

## Custom display name to show with [member action_label]. If not
## set the [method String.capitalize] version of [member action] is used.
@export_placeholder("Action Name") 
var display_name: String

@export_range(0, 50, 1, "suffix:%") 
var icon_column_stretch_ratio: int = 20:
	set(val):
		icon_column_stretch_ratio = val
		if not is_node_ready():
			await ready
		action_label.size_flags_stretch_ratio = 100 - val * 2
		key_margin_container.size_flags_stretch_ratio = val
		joy_margin_container.size_flags_stretch_ratio = val

@export var minimum_size_override: Vector2 = Vector2.ZERO:
	set(val):
		minimum_size_override = Vector2(maxi(val.x, 0), maxi(val.y, 0))
		_on_minimum_size_changed()

@export_group("Input Binding")

@export_custom(PROPERTY_HINT_INPUT_NAME, "show_builtin")
var cancel_rebind_action: StringName = &"ui_close_dialog"

@export_flags("Mouse Buttons", "Keys", "Joypad Buttons", "Joypad Motion")
var allowed_actions: int = MOUSE_BUTTONS | KEYS | JOYPAD_BUTTONS | JOYPAD_MOTION:
	set(val):
		allowed_actions = val
		notify_property_list_changed()

@export_subgroup("Disallowed", "disallowed_")
@export var disallowed_mouse_buttons: Array[MouseButton] = [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]
@export var disallowed_keys: Array[Key]
@export var disallowed_joy_buttons: Array[JoyButton]
@export var disallowed_joy_axis: Array[JoyAxis]

@export_group("Node References")
@export var container: Container:
	set(val):
		if container and container.minimum_size_changed.is_connected(_on_minimum_size_changed):
			container.minimum_size_changed.disconnect(_on_minimum_size_changed)
		container = val
		if container:
			container.minimum_size_changed.connect(_on_minimum_size_changed)
		_on_minimum_size_changed()

@export var action_label: Label:
	set(val):
		action_label = val
		if action_label:
			action_label.text = get_display_name()

@export var key_texture_rect: TextureRect:
	set(val):
		if key_texture_rect and key_texture_rect.texture.changed.is_connected(_on_input_texture_changed):
			key_texture_rect.texture.changed.disconnect(_on_input_texture_changed)
		key_texture_rect = val
		if key_texture_rect:
			key_texture_rect.texture = create_input_texture(false)

@export var key_label: Label

@export var joy_texture_rect: TextureRect:
	set(val):
		if joy_texture_rect and joy_texture_rect.texture and joy_texture_rect.texture.changed.is_connected(_on_input_texture_changed):
			joy_texture_rect.texture.changed.disconnect(_on_input_texture_changed)
		joy_texture_rect = val
		joy_texture_rect.texture = create_input_texture(true)

@export var joy_label: Label
@export var key_margin_container: MarginContainer
@export var joy_margin_container: MarginContainer

var input_data: InputData = Settings.get_input_data()
var event: InputEventAction = InputEventAction.new()

var listening: bool = false: set = set_listening, get = is_listening

func set_listening(val: bool) -> void:
		listening = val
		set_process_input(listening)
		emit_signal(listening_started.get_name() if val else listening_finished.get_name())

func is_listening() -> bool:
	return listening

func _ready() -> void:
	set_process_input(false)
	if Engine.is_editor_hint(): return
	button_mask = MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_MB_XBUTTON1 | MOUSE_BUTTON_MASK_MB_XBUTTON2 \
			| MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT
	mouse_exited.connect(_mouse_exit, CONNECT_DEFERRED)
	input_data.device_changed_to_joy.connect(_on_changed_to_joy)

func _on_changed_to_joy() -> void:
	if visible and not get_viewport().gui_get_focus_owner():
		grab_focus()

func _mouse_exit() -> void:
	if not listening and has_focus():
		release_focus()

func set_action(val: StringName) -> void:
	if Engine.is_editor_hint():
		name = val.to_pascal_case() if val else &"BindingPicker"
	
	#if action == val: return
	action = val
	
	event.action = action
	
	if action_label:
		action_label.text = get_display_name()
	
	if key_texture_rect:
		key_texture_rect.texture.update_texture()
	
	if joy_texture_rect:
		joy_texture_rect.texture.update_texture()

func get_action() -> StringName:
	return action

func create_input_texture(force_joy_only: bool) -> InputTexture:
	var tex: InputTexture = InputTexture.new()
	tex.resource_local_to_scene = true
	tex.force_platform = InputData.DeviceType.KEYBOARD
	tex.force_joy_only = force_joy_only
	tex.event = event
	tex.changed.connect(_on_input_texture_changed.bind(tex))
	return tex

func _on_input_texture_changed(input_texture: InputTexture) -> void:
	if not input_texture or not action: return
	var texture_rect: TextureRect = joy_texture_rect if input_texture.force_joy_only else key_texture_rect
	var label: Label = joy_label if input_texture.force_joy_only else key_label
	var has_texture: bool = input_texture.has_texture()
	texture_rect.visible = has_texture
	label.visible = !has_texture
	
	if label.visible:
		var event_text: String = get_event_text(input_texture.force_joy_only)
		label.text = event_text
		print("%s texture changed | %s '%s' | Event Text: %s" % [action, label, label.text, event_text])
	
	if input_texture.has_texture():
		texture_rect.show()
		label.hide()
	
	else:
		
		texture_rect.hide()
		
		label.show()

func action_get_event(force_joy_only: bool) -> InputEvent:
	return input_data.action_get_event(action, force_joy_only)

func get_event_text(force_joy_only: bool) -> String:
	return input_data.event_get_display_text(action_get_event(force_joy_only))

func get_display_name() -> String:
	if display_name:
		return display_name
	return get_action_display_name(action)

func get_action_display_name(action: StringName) -> String:
	var result: String = action.capitalize()
	if result.left(3) == "Ui ":
		result[1] = "I"
	return result

## Grab focus when hovering with mouse.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if not has_focus():
			grab_focus()
	elif event is InputEventMouseButton:
		if event.is_pressed() and event.double_click:
			set_pressed(true)
			accept_event()

func _input(event: InputEvent) -> void:
	if not listening: return
	
	accept_event()
	
	if not event.is_pressed() or event.is_echo():
		return
	
	if not event.is_action_type() or event.is_action(cancel_rebind_action, true) or event.is_action(action, true):
		reject_binding(event)
		return
	
	if event is InputEventMouseButton:
		if not MOUSE_BUTTONS & allowed_actions or event.button_index in disallowed_mouse_buttons:
			reject_binding(event)
			return
	
	elif event is InputEventKey:
		if not KEYS & allowed_actions or event.keycode in disallowed_keys:
			reject_binding(event)
			return
	
	elif event is InputEventJoypadButton:
		if not JOYPAD_BUTTONS & allowed_actions or event.button_index in disallowed_joy_buttons:
			reject_binding(event)
			return
	
	elif event is InputEventJoypadMotion:
		if not JOYPAD_MOTION & allowed_actions or event.axis in disallowed_joy_axis:
			reject_binding(event)
			return
	
	rebind_action(event)
	listening = false

func rebind_action(event: InputEvent) -> void:
	input_data.rebind(action, event)

	binding_changed.emit(event)


func _pressed() -> void:
	listening = true
	grab_focus()

func reject_binding(event: InputEvent) -> void:
	binding_rejected.emit(event)
	listening = false

func _on_minimum_size_changed() -> void:
	var container_min_size: Vector2 = container.get_combined_minimum_size() if container else Vector2.ZERO
	custom_minimum_size = Vector2(
		maxi(minimum_size_override.x, container_min_size.x), 
		maxi(minimum_size_override.y, container_min_size.y)
		)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings: PackedStringArray
	for prop in ["container", "action_label", "key_texture_rect", "key_label", "joy_texture_rect", "joy_label"]:
		if not get(prop):
			warnings.push_back("No '%s' set." % prop)
	return warnings

func _validate_property(property: Dictionary) -> void:
	match property.name:
		"custom_minimum_size":
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"Disallowed" when not allowed_actions:
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"disallowed_mouse_buttons" when not allowed_actions & MOUSE_BUTTONS:
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"disallowed_keys" when not allowed_actions & KEYS:
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"disallowed_joy_buttons" when not allowed_actions & JOYPAD_BUTTONS:
			property.usage &= ~PROPERTY_USAGE_EDITOR
		"disallowed_joy_axis" when not allowed_actions & JOYPAD_MOTION:
			property.usage &= ~PROPERTY_USAGE_EDITOR

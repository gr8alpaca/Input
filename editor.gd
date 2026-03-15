@tool
extends EditorScript

const Settings := preload("uid://c2b817jrfaqhb")

@warning_ignore_start("unused_variable", "unused_parameter", "unused_local_constant")

@export var mb: JoyAxis

func _run() -> void:
	var scene: Control = EditorInterface.get_edited_scene_root()
	var map: InputData = Settings.get_input_data()
	var e: InputEventJoypadButton = InputEventJoypadButton.new()
	
	#printt(e.as_text())
	
	for i in JOY_BUTTON_MAX:
		e.button_index = i as JoyButton
		printt(e.as_text())
		#printt(e, " | ", parse_text(e.as_text(), e.axis_value), " | ", e.as_text())


#func parse_text(txt: String) -> String:
	#var ps: PackedStringArray = txt.get_slice("(", 1).get_slice(")", 0).split(",", false)
	#for s: String in ps:
		#if not s.containsn("Left") and not s.contains("Right"): continue
		#return s.trim_prefix(" ").replace("X-Axis", "Left" if axis_value < 0 else "Right").replace("Y-Axis", "Down" if axis_value < 0 else "Up")
	#return "ERROR" if ps.is_empty() else ps[0]
	#
	#print()
	
	#print(InputData.event_get_key_text(event).capitalize())
	
	#var menu: RebindMenu = EditorInterface.get_edited_scene_root().get_node_or_null("Bindings")
	##printt(find_property("input_name"))
	#
	#for act in menu.editor_load_actions():
		#print(act)
	#
	#var result: Array[StringName]
	#var cfg: ConfigFile = menu.get_project_config()
	#
	#for action: String in cfg.get_section_keys("input"):
		#print("\nACTION: %s" % action)
		#result.push_back(action)
		#var events: Array = cfg.get_value("input", action, {}).get("events", [])
		#for event: InputEvent in events:
			#var txt: String = event.as_text() + (" \t%s" % event.axis_value if "axis_value" in event else "")
			#printt(event.get_class(), txt)

	#print(ProjectSettings.check_changed_settings_in_group("input"))
	#print(map.get_mouse_texture(MouseButton.MOUSE_BUTTON_LEFT))



func populate_keymap() -> void:
	const USE_OUTLINES: bool = true
	const DIR: String = "res://addons/input/data/textures/keyboard/"
	var map := load("res://addons/input/data/texture_map.tres")
	var files: PackedStringArray = DirAccess.get_files_at(DIR)
	
	var i: int = files.size()
	while i > 0:
		i -= 1
		if int(USE_OUTLINES) ^ int(files[i].contains("_outline")):
			files.remove_at(i)
	
	for key: Key in map.get_key_list():
		var key_name: String = OS.get_keycode_string(key)
		var file_path: String = DIR.path_join("keyboard_" + key_name + ("_outline" if USE_OUTLINES else "") + ".svg")
		if FileAccess.file_exists(file_path):
			map.set_key_texture(key, ResourceLoader.load(file_path, "Texture2D"))
	
	map.notify_property_list_changed()

func find_property(property: StringName) -> Dictionary:
	for dict in get_property_list():
		if dict.name == property: return dict
	return {}

@tool
extends Object

const PROJECT_SETTING_SECTION: String = "input_plus/config/"

const CONFIG: Dictionary[String, Dictionary] = {
	
	texture_map = {
		value = "res://addons/input/data/input_data.tres",
		type = TYPE_STRING,
		hint = PROPERTY_HINT_FILE_PATH,
		hint_string = "*.tres,*.res",
	},
}

static func init_settings() -> void:
	for dict: Dictionary in CONFIG.values():
		set_project_setting(CONFIG.find_key(dict), dict.value, dict)

static func set_project_setting(key: String, value: Variant, property_info: Dictionary = {}) -> void:
	var path: String = PROJECT_SETTING_SECTION.path_join(key)
	if not ProjectSettings.has_setting(path):
		ProjectSettings.set_setting(path, value)
	ProjectSettings.set_initial_value(path, value)
	ProjectSettings.add_property_info({
		name = path,
		type = property_info.get("type", typeof(value)),
		hint = property_info.get("hint", PROPERTY_HINT_NONE),
		hint_string = property_info.get("hint_string", ""),
	})
	ProjectSettings.save()


static func get_project_setting(key: String, default: Variant = null) -> Variant:
	return ProjectSettings.get_setting(PROJECT_SETTING_SECTION.path_join(key), default)

static func get_input_data() -> InputData:
	return load(get_project_setting(CONFIG.find_key(CONFIG.texture_map), CONFIG.texture_map.value))

static func get_input_data_path() -> String:
	return get_project_setting(CONFIG.find_key(CONFIG.texture_map), CONFIG.texture_map.value)

extends Control

@export var input_data: InputData
@export var save_path: String = "input_map.cfg"

var print_gui_changes: bool = false

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

func _on_gui_focus_changed(control: Control) -> void:
	if print_gui_changes:
		print(control.get("action"))

func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	
	if event is InputEventKey:
		#print("Event Device #%d | KEY" % [event.device])
		
		if event.keycode == KEY_F:
			print("Focus => ", get_viewport().gui_get_focus_owner().get("action") if get_viewport().gui_get_focus_owner() else "")
	
		elif event.keycode == KEY_O:
			print_gui_changes = !print_gui_changes 

func _on_save_pressed() -> void:
	input_data.save_cfg(ConfigFile.new()).save(save_path)

func _on_load_pressed() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(save_path)
	input_data.load_cfg(cfg)

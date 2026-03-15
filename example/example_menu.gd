extends Control

var print_gui_changes: bool = false

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)

func _on_gui_focus_changed(control: Control) -> void:
	if print_gui_changes:
		print(control.get("action"))

func _input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion:
		#print("%s" % [event.screen_relative])
	
	if not event.is_pressed() or event.is_echo(): return
	
	if event is InputEventKey:
		#print("Event Device #%d | KEY" % [event.device])
		
		if event.keycode == KEY_F:
			print("Focus => ", get_viewport().gui_get_focus_owner().get("action") if get_viewport().gui_get_focus_owner() else "")
	
		elif event.keycode == KEY_O:
			print_gui_changes = !print_gui_changes 
	#
	#elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		#print("Event Device #%d | JOY" % [event.device])
	#
		#
	##if event.is_pressed():
		##
		##example_menu.set_event(event)
	
	#if event.is_action_pressed(&"ui_up", false, true):
		#example_menu.event = event
		#label.text = "Strength: %01.02f" % event.get_action_strength(&"ui_up", true)
		#
	#elif event.is_action_pressed(&"ui_down", false, true):
		#example_menu.event = event
		#label.text = "Strength: %01.02f" % event.get_action_strength(&"ui_down", true)
		#
	#elif event.is_action_pressed(&"ui_right", false, true):
		#example_menu.event = event
		#label.text = "Strength: %01.02f" % event.get_action_strength(&"ui_right", true)
		#
	#elif event.is_action_pressed(&"ui_left", false, true):
		#example_menu.event = event
		#label.text = "Strength: %01.02f" % event.get_action_strength(&"ui_left", true)

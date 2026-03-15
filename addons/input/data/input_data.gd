@tool
class_name InputData extends Resource

enum DeviceType{INVALID = -2, KEYBOARD = -1, DEFAULT_JOYSTICK = 0, XBOX = 1, PLAYSTATION = 2, SWITCH = 3}

const SIGNALS: Dictionary[String, Dictionary] = {
	ACTION_CHANGED = {
		name = "action_changed",
		args = [{name = "action", type = TYPE_STRING_NAME}]
	},
	DEVICE_CHANGED = {
		name = "device_changed",
		args = [{name = "device_type", type = TYPE_INT}]
	},
	DEVICE_CHANGED_TO_JOY = {
		name = "device_changed_to_joy",
		args = []
	},
	DEVICE_CHANGED_TO_KEYBOARD = {
		name = "device_changed_to_keyboard",
		args = []
	},
	ACTION_EVENT_ERASED = {
		name = "action_event_erased",
		args = [
			{name = "action", type = TYPE_STRING_NAME},
			{name = "event", type = TYPE_OBJECT}]
	},
	ACTION_EVENT_ADDED = {
		name = "action_event_added",
		args = [
			{name = "action", type = TYPE_STRING_NAME},
			{name = "event", type = TYPE_OBJECT}]
	}
	}

const PLATFORM_LIST: PackedStringArray = ["default", "xbox", "ps", "switch"]

enum MouseButtonProperties{
	left = MOUSE_BUTTON_LEFT, 
	right = MOUSE_BUTTON_RIGHT,
	middle = MOUSE_BUTTON_MIDDLE,
	wheel_up = MOUSE_BUTTON_WHEEL_UP,
	wheel_down = MOUSE_BUTTON_WHEEL_DOWN,
	wheel_left = MOUSE_BUTTON_WHEEL_LEFT,
	wheel_right = MOUSE_BUTTON_WHEEL_RIGHT,
	extra_button_1 = MOUSE_BUTTON_XBUTTON1,
	extra_button_2 = MOUSE_BUTTON_XBUTTON2,
	}

enum JoyInput{
	invalid = JOY_BUTTON_INVALID,
	a = JOY_BUTTON_A,
	b = JOY_BUTTON_B,
	x = JOY_BUTTON_X,
	y = JOY_BUTTON_Y,
	dpad_up = JOY_BUTTON_DPAD_UP,
	dpad_down = JOY_BUTTON_DPAD_DOWN,
	dpad_left = JOY_BUTTON_DPAD_LEFT,
	dpad_right = JOY_BUTTON_DPAD_RIGHT,
	left_shoulder = JOY_BUTTON_LEFT_SHOULDER,
	right_shoulder = JOY_BUTTON_RIGHT_SHOULDER,
	back = JOY_BUTTON_BACK,
	start = JOY_BUTTON_START,
	left_stick = JOY_BUTTON_LEFT_STICK,
	right_stick = JOY_BUTTON_RIGHT_STICK,
	guide = JOY_BUTTON_GUIDE,
	misc = JOY_BUTTON_MISC1,
	ls_left, 
	ls_right, 
	ls_up, 
	ls_down, 
	rs_left, 
	rs_right, 
	rs_up, 
	rs_down, 
	trigger_left, 
	trigger_right
	}

## Emitted when the device changes.
signal device_changed
signal device_changed_to_joy
signal device_changed_to_keyboard

## Emitted when the bindings for an action change.
signal action_changed(action: StringName)
signal action_event_erased(action: StringName, event: InputEvent)
signal action_event_added(action: StringName, event: InputEvent)

signal data_loaded

@export_storage var key_list: PackedInt32Array = get_default_keylist()

@export_storage var data: Dictionary[String, Dictionary]: set = set_data

var connected_joys: Dictionary[int, Dictionary]

var current_device: int = -2: set = set_current_device
var current_device_type: DeviceType = DeviceType.KEYBOARD: set = set_current_device_type

func _init() -> void:
	set("keyboard/key_list", get_default_keylist())
	
	for signal_dict: Dictionary in SIGNALS.values():
		if not Input.has_user_signal(signal_dict.name):
			Input.add_user_signal(signal_dict.name, signal_dict.args)
		connect(signal_dict.name, _relay_signal.bind(signal_dict.name))
	
	if Engine.is_editor_hint(): return
	Engine.get_main_loop().root.window_input.connect(_on_root_input)
	Input.joy_connection_changed.connect.call_deferred(_on_joy_connection_changed)
	data_loaded.connect(init_sync, CONNECT_ONE_SHOT)

func init_sync() -> void:
	var sync_actions: Dictionary[StringName, Array] = get_sync_actions()
	for key_action: StringName in sync_actions:
		for value_action: StringName in sync_actions[key_action]:
			var value_event_list:= action_get_event_list(value_action)
			for key_event: InputEvent in action_get_event_list(key_action):
				if not value_event_list.any(key_event.is_match):
					action_add_event(value_action, key_event)

func rebind(action: StringName, event: InputEvent) -> void:
	if InputMap.action_has_event(action, event):
		return
	
	var is_joy: bool = is_joypad_event(event)
	var old_event: InputEvent = action_get_event(action, is_joy)
	
	for a: StringName in InputMap.get_actions():
		if action_has_event(a, event):
			action_erase_event(a, event)
	
	action_erase_event(action, old_event, false)
	action_add_event(action, event)

func action_erase_event(action: StringName, event: InputEvent, emit_action_change_signal: bool = true) -> void:
	if not event or not action_has_event(action, event): 
		return
	
	InputMap.action_erase_event(action, event)

	for sub_action: StringName in get_sync_actions().get(action, []):
		action_erase_event(sub_action, event)
	
	action_event_erased.emit(action, event)
	if emit_action_change_signal:
		action_changed.emit(action)

func action_add_event(action: StringName, event: InputEvent, emit_action_change_signal: bool = true) -> void:
	if not event or action_has_event(action, event): 
		return
	
	InputMap.action_add_event(action, event)
	
	for sub_action: StringName in get_sync_actions().get(action, []):
		action_add_event(sub_action, event)
	
	action_event_added.emit(action, event)
	if emit_action_change_signal:
		action_changed.emit(action)

func get_action_texture(action: StringName, force_device_type: DeviceType = DeviceType.INVALID) -> Texture2D:
	var device_type: DeviceType = force_device_type if force_device_type > -2 else current_device_type
	var is_joypad: bool = device_type > DeviceType.KEYBOARD
	return get_event_texture(action_get_event(action, is_joypad))

func get_event_texture(event: InputEvent, force_device_type: DeviceType = DeviceType.INVALID) -> Texture2D:
	if event is InputEventAction and event.action:
		return get_action_texture(event.action, force_device_type)
	elif event is InputEventMouseButton:
		return get_mouse_texture(event.button_index)
	elif event is InputEventKey:
		return get_key_texture(event_get_key_text(event))
	elif is_joypad_event(event):
		return get_joypad_texture(parse_joy_input(event), get_joypad_platform(force_device_type))
	return null

func action_has_event(action: StringName, event: InputEvent) -> bool:
	return action_get_event_list(action).any(event.is_match)

func action_get_event(action: StringName, force_joy_only: bool) -> InputEvent:
	for event: InputEvent in action_get_event_list(action):
		if force_joy_only:
			if is_joypad_event(event):
				return event
		elif is_keyboard_event(event):
			return event
	return null

func action_get_event_list(action: StringName) -> Array[InputEvent]:
	var result: Array[InputEvent] = InputMap.action_get_events(action)
	if Engine.is_editor_hint():
		var setting_property: String = "input/" + action 
		if ProjectSettings.has_setting(setting_property):
			result.assign(ProjectSettings.get_setting_with_override(setting_property).get("events", []))
	
	var ignored_events: Array = get_ignored_events().get(action, [])
	var i: int = result.size()
	while i > 0:
		i -= 1
		for e: InputEvent in ignored_events:
			if result[i].is_match(e):
				result.remove_at(i)
				break
	
	return result

func get_sync_actions() -> Dictionary[StringName, Array]:
	return get("actions/sync")

func get_ignored_events() -> Dictionary[StringName, Array]:
	return get("actions/ignored_events")

static func is_keyboard_event(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton

static func is_joypad_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

func get_mouse_texture(mouse_button: MouseButton) -> Texture2D:
	return get("textures/mouse/%s" % MouseButtonProperties.find_key(mouse_button))

func set_mouse_texture(mouse_button: MouseButton, texture: Texture2D) -> void:
	set("textures/mouse/%s" % MouseButtonProperties.find_key(mouse_button), texture)

func get_joypad_texture(joy_button: JoyInput, platform: String = "default") -> Texture2D:
	var texture_key: String = JoyInput.find_key(joy_button) 
	var result : Texture2D = get("textures/joy/%s/%s" % [platform, texture_key])
	return result if result else get("textures/joy/default/%s" % texture_key)
	
func set_joypad_texture(joy_button: JoyInput, texture: Texture2D, platform: String = "") -> void:
	set("textures/joy/%s/%s" % [platform, JoyInput.find_key(joy_button)], texture)

func get_key_texture(key_text: String) -> Texture2D:
	return get("textures/keyboard/" + key_text)

func set_key_texture(key: Key, texture: Texture2D) -> void:
	set("textures/keyboard/" + OS.get_keycode_string(key), texture)

func get_joypad_platform(force_device_type: DeviceType = DeviceType.INVALID) -> String:
	if 0 < force_device_type and force_device_type < PLATFORM_LIST.size():
		return PLATFORM_LIST[force_device_type]
	return PLATFORM_LIST[clampi(current_device_type, DeviceType.DEFAULT_JOYSTICK, DeviceType.SWITCH)]

func is_keyboard_active() -> bool:
	return current_device_type == DeviceType.KEYBOARD

func is_joypad_active() -> bool:
	return current_device_type > 0

func _on_root_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		const SCREEN_RELATIVE_SQUARED_THRESHOLD: float = 4.0
		if (event.screen_relative.length_squared() < SCREEN_RELATIVE_SQUARED_THRESHOLD):
			return
	
	set_current_device(event.device)
	set_current_device_type(event_get_device_type(event))

func event_get_device_type(event: InputEvent) -> DeviceType:
	if event is InputEventKey or event is InputEventMouse:
		return DeviceType.KEYBOARD
	return device_get_joy_type(event.device)

func set_current_device(device: int) -> void:
	if current_device == device: return
	current_device = device
 
func set_current_device_type(val: DeviceType) -> void:
		if current_device_type == val: return
		var is_keyboard_to_joy: bool = current_device_type == DeviceType.KEYBOARD and val > DeviceType.KEYBOARD
		var is_joy_to_keyboard: bool = val == DeviceType.KEYBOARD and current_device_type > DeviceType.KEYBOARD
		print("Device Type Changed %s => %s" % [DeviceType.find_key(current_device_type), DeviceType.find_key(val)])
		current_device_type = val
		
		device_changed.emit(val)
		
		if is_keyboard_to_joy:
			device_changed_to_joy.emit()
		elif is_joy_to_keyboard:
			device_changed_to_keyboard.emit()

func device_get_joy_type(device: int) -> DeviceType:
	var input_name: String = Input.get_joy_name(device)
	if input_name.containsn("ps4") or input_name.containsn("ps5") or input_name.containsn("playstation"):
		return DeviceType.PLAYSTATION
	if input_name.containsn("xbox"):
		return DeviceType.XBOX
	if input_name.containsn("switch"):
		return DeviceType.SWITCH
	return DeviceType.DEFAULT_JOYSTICK

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		set_current_device(device)
		set_current_device_type(device_get_joy_type(device))

	print("Joy '%s' %sconnected." % [Input.get_joy_name(device), "" if connected else "dis"])

func parse_joy_input(event: InputEvent) -> JoyInput:
	if event is InputEventJoypadButton:
		return event.button_index as JoyInput
	elif event is InputEventJoypadMotion:
		match event.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return JoyInput.trigger_left
			JOY_AXIS_TRIGGER_RIGHT:
				return JoyInput.trigger_right
			JOY_AXIS_LEFT_X:
				return JoyInput.ls_left if event.axis_value < 0 else JoyInput.ls_right
			JOY_AXIS_LEFT_Y:
				return JoyInput.ls_up if event.axis_value < 0 else JoyInput.ls_down
			JOY_AXIS_RIGHT_X:
				return JoyInput.rs_left if event.axis_value < 0 else JoyInput.rs_right
			JOY_AXIS_RIGHT_Y:
				return JoyInput.rs_up if event.axis_value < 0 else JoyInput.rs_down
	return JoyInput.invalid

static func event_get_key_text(event: InputEventKey) -> String:
	if event.keycode:
		return event.as_text_keycode()
	elif event.physical_keycode:
		return event.as_text_physical_keycode()
	return event.as_text_key_label()

func get_key_list() -> Array[Key]:
	var result: Array[Key]
	result.assign(key_list)
	return result

func get_default_keylist() -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	result.append_array(
		PackedInt32Array(
		[KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN] +
		[KEY_ENTER, KEY_SPACE, KEY_SHIFT,] +
		range(KEY_A, KEY_Z + 1) +
		range(KEY_0, KEY_9 + 1) +
		range(KEY_F1, KEY_F13) +
		range(KEY_PLUS, KEY_SLASH + 1) +
		[KEY_EQUAL, KEY_TAB, KEY_CAPSLOCK, KEY_BACKSPACE, KEY_ESCAPE,] +
		[KEY_ALT, KEY_CTRL, KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BACKSLASH, KEY_QUOTELEFT,] +
		[KEY_INSERT, KEY_HOME, KEY_DELETE, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_NUMLOCK]
		))
	return result

func event_get_display_text(event: InputEvent) -> String:
	if event is InputEventJoypadMotion:
		for s: String in event.as_text().get_slice("(", 1).get_slice(")", 0).split(",", false):
			if not s.containsn("Left") and not s.contains("Right"): continue
			return s.trim_prefix(" ").replace("X-Axis", "Left" if event.axis_value < 0 else "Right")\
				.replace("Y-Axis", "Down" if event.axis_value < 0 else "Up")
		return event.as_text()
	if event is InputEventJoypadButton:
		return event.as_text().get_slice("(", 1).get_slice(")", 0).get_slice(",", 0)
	if event is InputEventKey:
		return event_get_key_text(event).capitalize()
	if event is InputEventMouseButton:
		return event.as_text()
	return ""

func save_override() -> void:
	ProjectSettings.save_custom("override.cfg")

func save_cfg(cfg: ConfigFile = ConfigFile.new()) -> ConfigFile:
	for action: String in InputMap.get_actions():
		cfg.set_value("input", action, {
			deadzone = InputMap.action_get_deadzone(action),
			events = InputMap.action_get_events(action),
		})
	return cfg

func load_cfg(cfg: ConfigFile) -> void:
	for action: String in cfg.get_section_keys("input"):
		var map: Dictionary = cfg.get_value("input", action, {})
		InputMap.action_set_deadzone(action, map.get("deadzone", 0.5))
		
		for event: InputEvent in InputMap.action_get_events(action):
			action_erase_event(action, event, false)
		
		for event: InputEvent in map.get("events", []):
			action_add_event(action, event, false)
			
		action_changed.emit(action)

## All internal signals are connected to be emitted again as a user_signal in Input. Last arg must be StringName.
func _relay_signal(...args: Array) -> void:
	var emit_args: Array = args.duplicate()
	emit_args.push_front(emit_args.pop_back())
	Input.emit_signal.callv(emit_args)

func set_data(val: Dictionary[String, Dictionary]) -> void:
	data = val
	data_loaded.emit()

func _get_property_list() -> Array[Dictionary]:
	var props: Array[Dictionary]
	
	props.push_back({
		name = "actions/sync",
		type = TYPE_DICTIONARY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "21/43:loose_mode;28:21/43:show_builtin,loose_mode"
	})
	
	props.push_back({
		name = "actions/ignored_events",
		type = TYPE_DICTIONARY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "21/43:show_builtin;28:24/17:InputEvent"
	})
	
	props.push_back({
		name = "keyboard/key_list",
		type = TYPE_ARRAY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "%d/%d:%s" % [TYPE_INT, PROPERTY_HINT_ENUM, "Key None:0,Key Special:4194304,Key Escape:4194305,Key Tab:4194306,Key Backtab:4194307,Key Backspace:4194308,Key Enter:4194309,Key Kp Enter:4194310,Key Insert:4194311,Key Delete:4194312,Key Pause:4194313,Key Print:4194314,Key Sysreq:4194315,Key Clear:4194316,Key Home:4194317,Key End:4194318,Key Left:4194319,Key Up:4194320,Key Right:4194321,Key Down:4194322,Key Pageup:4194323,Key Pagedown:4194324,Key Shift:4194325,Key Ctrl:4194326,Key Meta:4194327,Key Alt:4194328,Key Capslock:4194329,Key Numlock:4194330,Key Scrolllock:4194331,Key F 1:4194332,Key F 2:4194333,Key F 3:4194334,Key F 4:4194335,Key F 5:4194336,Key F 6:4194337,Key F 7:4194338,Key F 8:4194339,Key F 9:4194340,Key F 10:4194341,Key F 11:4194342,Key F 12:4194343,Key F 13:4194344,Key F 14:4194345,Key F 15:4194346,Key F 16:4194347,Key F 17:4194348,Key F 18:4194349,Key F 19:4194350,Key F 20:4194351,Key F 21:4194352,Key F 22:4194353,Key F 23:4194354,Key F 24:4194355,Key F 25:4194356,Key F 26:4194357,Key F 27:4194358,Key F 28:4194359,Key F 29:4194360,Key F 30:4194361,Key F 31:4194362,Key F 32:4194363,Key F 33:4194364,Key F 34:4194365,Key F 35:4194366,Key Kp Multiply:4194433,Key Kp Divide:4194434,Key Kp Subtract:4194435,Key Kp Period:4194436,Key Kp Add:4194437,Key Kp 0:4194438,Key Kp 1:4194439,Key Kp 2:4194440,Key Kp 3:4194441,Key Kp 4:4194442,Key Kp 5:4194443,Key Kp 6:4194444,Key Kp 7:4194445,Key Kp 8:4194446,Key Kp 9:4194447,Key Menu:4194370,Key Hyper:4194371,Key Help:4194373,Key Back:4194376,Key Forward:4194377,Key Stop:4194378,Key Refresh:4194379,Key Volumedown:4194380,Key Volumemute:4194381,Key Volumeup:4194382,Key Mediaplay:4194388,Key Mediastop:4194389,Key Mediaprevious:4194390,Key Medianext:4194391,Key Mediarecord:4194392,Key Homepage:4194393,Key Favorites:4194394,Key Search:4194395,Key Standby:4194396,Key Openurl:4194397,Key Launchmail:4194398,Key Launchmedia:4194399,Key Launch 0:4194400,Key Launch 1:4194401,Key Launch 2:4194402,Key Launch 3:4194403,Key Launch 4:4194404,Key Launch 5:4194405,Key Launch 6:4194406,Key Launch 7:4194407,Key Launch 8:4194408,Key Launch 9:4194409,Key Launcha:4194410,Key Launchb:4194411,Key Launchc:4194412,Key Launchd:4194413,Key Launche:4194414,Key Launchf:4194415,Key Globe:4194416,Key Keyboard:4194417,Key Jis Eisu:4194418,Key Jis Kana:4194419,Key Unknown:8388607,Key Space:32,Key Exclam:33,Key Quotedbl:34,Key Numbersign:35,Key Dollar:36,Key Percent:37,Key Ampersand:38,Key Apostrophe:39,Key Parenleft:40,Key Parenright:41,Key Asterisk:42,Key Plus:43,Key Comma:44,Key Minus:45,Key Period:46,Key Slash:47,Key 0:48,Key 1:49,Key 2:50,Key 3:51,Key 4:52,Key 5:53,Key 6:54,Key 7:55,Key 8:56,Key 9:57,Key Colon:58,Key Semicolon:59,Key Less:60,Key Equal:61,Key Greater:62,Key Question:63,Key At:64,Key A:65,Key B:66,Key C:67,Key D:68,Key E:69,Key F:70,Key G:71,Key H:72,Key I:73,Key J:74,Key K:75,Key L:76,Key M:77,Key N:78,Key O:79,Key P:80,Key Q:81,Key R:82,Key S:83,Key T:84,Key U:85,Key V:86,Key W:87,Key X:88,Key Y:89,Key Z:90,Key Bracketleft:91,Key Backslash:92,Key Bracketright:93,Key Asciicircum:94,Key Underscore:95,Key Quoteleft:96,Key Braceleft:123,Key Bar:124,Key Braceright:125,Key Asciitilde:126,Key Yen:165,Key Section:167"],
	})
	
	#
	# TEXTURES
	const TEXTURE_PROP_DICT: Dictionary = {
		type = TYPE_OBJECT,
		hint = PROPERTY_HINT_RESOURCE_TYPE,
		hint_string = "Texture2D",
	}
	
	for sub: String in ["keyboard", "mouse", "joy"]:
		props.push_back({
		name = "textures/%s/generic" % sub,
		type = TYPE_DICTIONARY,
		hint = PROPERTY_HINT_TYPE_STRING,
		hint_string = "4:;24/17:Texture2D",
		})
		
	for key: Key in get_key_list():
		props.push_back({name = "textures/keyboard/" + OS.get_keycode_string(key as Key)}.merged(TEXTURE_PROP_DICT))
	
	for mb_property_name: String in MouseButtonProperties.keys():
		props.push_back({name = "textures/mouse/" + mb_property_name}.merged(TEXTURE_PROP_DICT))
	
	for platform in PLATFORM_LIST:
		for joy_property_name: String in JoyInput.keys():
			if joy_property_name.containsn("invalid"): continue
			props.push_back({name = "textures/joy/%s/%s" % [platform, joy_property_name]}.merged(TEXTURE_PROP_DICT))

	return props

func _get(property: StringName) -> Variant:
	if property.contains("/"):
		var dict: Dictionary = data
		var keys: PackedStringArray = property.split("/")
		for i: int in keys.size():
			if i < keys.size() - 1:
				dict = dict.get_or_add(keys[i], {})
			else:
				return dict.get(keys[i])

	return null

func _set(property: StringName, value: Variant) -> bool:
	if property.contains("/"):
		var keys: PackedStringArray = property.split("/")
		var subdict: Dictionary = data
		for i: int in keys.size():
			if i == keys.size() - 1:
				subdict.set(keys[i], value)
			else:
				subdict = subdict.get_or_add(keys[i], {})
		notify_property_list_changed()
		return true
	
	return false

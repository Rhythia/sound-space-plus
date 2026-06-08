extends Button

var has_been_pressed:bool = false
var detected_controllers = Input.get_connected_joypads().size()

func files_dropped(files:PoolStringArray,_screen:int):
	if has_been_pressed: return
	if files.size() == 1 and files[0].get_extension() == "sspre":
		has_been_pressed = true
		Rhythia.replay = Replay.new()
		Rhythia.replaying = true
		Rhythia.replay_path = files[0]
		get_viewport().get_node("Menu").black_fade_target = true
		yield(get_tree().create_timer(0.35),"timeout")
		get_tree().change_scene("res://scenes/loaders/songload.tscn")
	else:
		var song
		for file in files:
			if file.get_extension() != "sspm": continue
			song = Song.new()
			song.load_from_sspm(file)
			var result = song.convert_to_sspm()
			if result == "Converted!":
				Rhythia.registry_song.check_and_remove_id(song.id)
				song = Rhythia.registry_song.add_sspm_map("user://maps/%s.sspm" % song.id)
		var list = $"/root/Menu/Main/MapRegistry/S/G"
		list.prepare_songs()
		list.reload_to_current_page()
		if song:
			Rhythia.select_song(song)
			list.switch_to_play_screen()

func _input(event:InputEvent):
	if get_viewport().get_node("Menu/Main/Results").visible == true:
		if !disabled && !has_been_pressed && event is InputEventJoypadButton:
			if event.button_index == JOY_XBOX_A && event.pressed:
				grab_focus()
				grab_click_focus()
				pressed = true
		if !disabled && !has_been_pressed && event is InputEventKey:
			if event.pressed and event.scancode == KEY_SPACE:
				grab_focus()
				grab_click_focus()
				pressed = true

func _pressed():
	# button functionality
	if !Rhythia.selected_song: return
	if has_been_pressed: return

	# Controller detection
	if detected_controllers >= 1 and !Rhythia.ignore_controller_detection:
		var sel = 1
		Globals.confirm_prompt.s_alert.play()
		Globals.confirm_prompt.open("A controller or joypad was detected.\nWould you like to play the song with it?\n\n(Connected controllers may cause your cursor to not work when using your mouse!)","Possible controller detected",[{text="No"},{text="Yes",wait=2}])
		sel = yield(Globals.confirm_prompt,"option_selected")
		Globals.confirm_prompt.s_next.play()
		Globals.confirm_prompt.close()
		yield(Globals.confirm_prompt,"done_closing")
		if bool(sel):
			Rhythia.ignore_controller_detection = true
			has_been_pressed = true
			get_viewport().get_node("Menu").black_fade_target = true
			yield(get_tree().create_timer(0.35),"timeout")
			get_tree().change_scene("res://scenes/loaders/songload.tscn")
			return
	else:
		get_viewport().get_node("Menu").black_fade_target = true
		yield(get_tree().create_timer(0.35),"timeout")
		get_tree().change_scene("res://scenes/loaders/songload.tscn")

	# Debug printing
#	print("Connected controllers:\n")
#	print(detected_controllers)
#	print("\n\n\n\n")

func _ready():
	get_tree().connect("files_dropped",self,"files_dropped")

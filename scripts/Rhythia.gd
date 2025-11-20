extends Node

onready var rootg = get_tree().root

# Signals
signal mods_changed
signal speed_mod_changed
signal selected_song_changed
signal selected_space_changed
signal selected_colorset_changed
signal selected_mesh_changed
signal selected_hit_effect_changed
signal selected_miss_effect_changed
signal init_stage_reached
signal init_stage_num
signal map_list_ready
signal volume_changed
signal favorite_songs_changed
signal menu_music_state_changed
signal download_start
signal download_done


# Directories
var user_pack_dir:String = Globals.p("user://packs")
var user_mod_dir:String = Globals.p("user://mods")
var user_vmap_dir:String = Globals.p("user://vmaps")
var user_map_dir:String = Globals.p("user://maps")
var user_best_dir:String = Globals.p("user://bests")
var user_colorset_dir:String = Globals.p("user://colorsets")
var user_friend_dir:String = Globals.p("user://friend")
var user_mesh_dir:String = Globals.p("user://meshes")

# Installed content info
var installed_dlc:Array = ["ssp_basegame"]
var installed_mods:Array = []
var installed_packs:Array = []


# Registries
var registry_colorset:Registry
var registry_song:Registry
var registry_world:Registry
var registry_mesh:Registry
var registry_effect:Registry
# Selected items
var selected_space:BackgroundWorld
var selected_colorset:ColorSet
var selected_song:Song
var selected_mesh:NoteMesh
var selected_hit_effect:NoteEffect
var selected_miss_effect:NoteEffect
# Selectors
func select_colorset(set:ColorSet):
	if set:
		selected_colorset = set
		emit_signal("selected_colorset_changed",set)
func select_world(world:BackgroundWorld):
	if world:
		selected_space = world
		emit_signal("selected_space_changed",world)
func select_mesh(mesh:NoteMesh):
	selected_mesh = mesh
	emit_signal("selected_mesh_changed",mesh)
func select_hit_effect(effect:NoteEffect):
	if effect:
		selected_hit_effect = effect
		emit_signal("selected_hit_effect_changed",effect)
func select_miss_effect(effect:NoteEffect):
	if effect:
		selected_miss_effect = effect
		emit_signal("selected_miss_effect_changed",effect)
func select_song(song:Song): # here
	if song.is_online:
		emit_signal("download_start")
		get_tree().paused = true
		
		print("[Online Map] Starting download")
		var id:String = Online.download_map(song)
		
		print("[Online Map] Waiting for download to finish")
		var result:Dictionary = yield(Online,"map_downloaded")
		while result.id != id:
			print("[Online Map] Wrong download: %s != %s" % [result.id, id])
			result = yield(Online,"map_downloaded")
		print("[Online Map] Download finished")
		
		get_tree().paused = false
		if result.success:
			emit_signal("download_done")
			selected_song = song
			Socket.send_map_select()
			emit_signal("selected_song_changed",song)
		elif result.error == "010-100":
			emit_signal("download_done")
		else:
			Globals.confirm_prompt.s_alert.play()
			Globals.confirm_prompt.open(
				"Failed to download map.\nError code: %s" % result.error,
				"Error",
				[{text="OK"}]
			)
			yield(Globals.confirm_prompt,"option_selected")
			Globals.confirm_prompt.s_back.play()
			Globals.confirm_prompt.close()
			yield(Globals.confirm_prompt,"done_closing")
			emit_signal("download_done")
	else:
		selected_song = song
		Socket.send_map_select()
		emit_signal("selected_song_changed",song)


# Song ending state data
var just_ended_song:bool = false
var song_end_type:int = Globals.END_FAIL
var song_end_misses:int
var song_end_hits:int
var song_end_total_notes:int
var song_end_position:float
var song_end_pause_count:int
var song_end_accuracy_str:String
var song_end_time_str:String
var song_end_length:float
var song_end_combo:int
# Replay data
var replay:Replay
var replay_path:String = ""
var was_replay:bool = false
var replaying:bool = false

# State/transit data
var load_target_frame_time:float = 1.0/40.0 # Length of time load loops run before letting a frame render
var rainbow_t:float = 0 # Keep rainbow effects in perfect sync
var note_spin_t:float = 0 # Keep note spin settings in perfect sync
var alert:String = "" # Used for startup
var should_ask_about_replays:bool = true # Replay setting was not found, ask
var do_archive_convert:bool = false # Has "Convert SS Archive" been pressed?
var conmgr_transit = null # Content manager transit data, can vary widely
var errornum:int = 0 # Used by settings file errors
var errorstr:String = "" # Used by loading errors (ie. errors/songload and errors/menuload)
var first_init_done = false # Don't reload mods as that can cause problems
var loaded_world = null # Holds the bg world for transit between songload and song player
var was_map_screen_centered:bool = true
var menu_target:String = ProjectSettings.get_setting("application/config/default_menu_target")
var is_init:bool = true # Used to check if Onboarding is being used for game startup

# Song list position/search persistence
var was_auto_play_switch:bool = true
var last_search_str:String = ""
var last_author_search_str:String = ""
var last_search_incl_broken:bool = false
var last_search_incl_online:bool = true
var last_search_flip_sort:bool = false
var last_search_flip_name_sort:bool = false
var last_page_num:int = 0
var last_difficulty_filter:Array = [
	Globals.DIFF_UNKNOWN,
	Globals.DIFF_EASY,
	Globals.DIFF_MEDIUM,
	Globals.DIFF_HARD,
	Globals.DIFF_LOGIC,
	Globals.DIFF_AMOGUS
]

# VR
var vr:bool = false
var fake_vr:bool = false
var vr_available:bool = false
var vr_interface:ARVRInterface
var vr_player:VRPlayer
var vr_left_handed:bool = false
var vr_controller_type:int = Globals.VR_GENERIC

# Song queue
var queue_active:bool = false
var queue_pos:int = 0
var song_queue:Array = []
var just_ended_queue:bool = false
var queue_end_type:int = Globals.END_FAIL
var queue_end_misses:int
var queue_end_hits:int
var queue_end_total_notes:int
var queue_end_position:float
var queue_end_pause_count:int
var queue_end_accuracy_str:String
var queue_end_time_str:String
var queue_end_length:float
var queue_end_combo:int


# Loaded sounds
var miss_snd:AudioStream
var hit_snd:AudioStream
var fail_snd:AudioStream
var pb_snd:AudioStream
var menu_bgm:AudioStream
# Default sounds - allows for removing custom sounds w/o restarting the game
var normal_pb_sound
var def_miss_snd:AudioStream
var def_hit_snd:AudioStream
var def_fail_snd:AudioStream
var def_pb_snd:AudioStream
var def_menu_bgm:AudioStream

# Keep fail sounds playing on scene switch
var fail_asp:AudioStreamPlayer = AudioStreamPlayer.new()

# Controller ignore settings
var ignore_controller_detection:bool = false

# HUD with HR
var expand_hud_onhr:bool = false

# VR startup
func start_vr():
	if vr:
		print("VR already active")
		return
	print("VR START")
	vr = true
	
	get_viewport().hdr = false
	OS.vsync_enabled = false
	Engine.target_fps = 90
	
	if Input.is_key_pressed(KEY_SHIFT):
		print("enabling fake vr")
		OS.window_maximized = true
		fake_vr = true
		
		var ev = InputEventKey.new()
		ev.scancode = KEY_F
		InputMap.action_add_event("vr_switch_hands",ev)
		
		ev = InputEventMouseButton.new()
		ev.button_index = BUTTON_LEFT
		InputMap.action_add_event("vr_click",ev)
	else:
		vr_interface.initialize()
		get_viewport().arvr = true
		
		# Hand switch binds
		var ev = InputEventJoypadButton.new()
		ev.button_index = JOY_OCULUS_MENU
		InputMap.action_add_event("vr_switch_hands",ev)
		
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_OPENVR_MENU
		InputMap.action_add_event("vr_switch_hands",ev)
		
		# Give up binds
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_VR_GRIP
		InputMap.action_add_event("give_up",ev)
		
		ev = InputEventJoypadMotion.new()
		ev.axis = JOY_VR_ANALOG_GRIP
		InputMap.action_add_event("give_up",ev)
		
		# Pause binds
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_VR_TRIGGER
		InputMap.action_add_event("pause",ev)
		
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_OCULUS_BY
		InputMap.action_add_event("pause",ev)
		
		ev = InputEventJoypadMotion.new()
		ev.axis = JOY_VR_ANALOG_TRIGGER
		InputMap.action_add_event("pause",ev)
		
		# Click binds
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_VR_TRIGGER
		InputMap.action_add_event("vr_click",ev)
		
		ev = InputEventJoypadButton.new()
		ev.button_index = JOY_OCULUS_AX
		InputMap.action_add_event("vr_click",ev)
		
		ev = InputEventJoypadMotion.new()
		ev.axis = JOY_VR_ANALOG_TRIGGER
		InputMap.action_add_event("vr_click",ev)
	
	var vr_av:VRPlayer = load("res://vr/VRPlayer.tscn").instance()
	rootg.add_child(vr_av)
	vr_av.name = "VRPlayer"
	vr_player = vr_av
	
	menu_target = "res://vr/vrmenu.tscn"
	get_tree().change_scene("res://scenes/loaders/menuload.tscn")

# Song queue
func prepare_queue():
	record_replays = false
	queue_active = true
	just_ended_queue = false
	queue_pos = 0
	
	queue_end_type = Globals.END_FAIL
	queue_end_misses = 0
	queue_end_hits = 0
	queue_end_total_notes = 0
	queue_end_position = 0
	queue_end_pause_count = 0
	queue_end_length = 0
	queue_end_combo = 0
	for s in song_queue:
		queue_end_length += s.last_ms

func get_next():
	queue_pos += 1
	print(queue_pos)
	
	queue_end_type = song_end_type
	queue_end_misses += song_end_misses
	queue_end_hits += song_end_hits
	queue_end_total_notes += song_end_total_notes
	queue_end_position += clamp(song_end_position,0,selected_song.last_ms)
	queue_end_pause_count += song_end_pause_count
	
	queue_end_combo += song_end_combo
	
	if song_end_type == Globals.END_GIVEUP or queue_pos == song_queue.size():
		print("all done!")
		just_ended_queue = true
		queue_active = false
		return null
	
	return song_queue[queue_pos]

# Engine node functions + debug command line
func _ready():
	fail_asp.bus = "OtherSound"
	call_deferred("add_child",fail_asp)
	pause_mode = PAUSE_MODE_PROCESS
	Globals.connect("console_sent",self,"_console")
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(0.5))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(0.5))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HitSound"), linear2db(0.3))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MissSound"), linear2db(0.6))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("FailSound"), linear2db(0.6))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("PBSound"), linear2db(0.6))

func _process(delta):
	# Rainbow sync
	rainbow_t = fmod(rainbow_t + (delta*0.5),10)
	# Note Spin Sync
	note_spin_t = fmod(note_spin_t + (delta*0.5),360)
	# Global hotkeys
	if Input.is_action_just_pressed("fullscreen"):
		OS.window_fullscreen = not OS.window_fullscreen

# Debug
var desync_alerts:bool = false
var disable_desync:bool = false
func _console(cmd:String,args:String):
	match cmd:
		"queue":
			var ids = args.split(" ",false)
			if ids.size() == 0:
				if song_queue.size() == 0:
					console_cmd_error("Must specify at least 1 map id")
					return
				else:
					Globals.notify(Globals.NOTIFY_SUCCEED,"reactivated queue")
					prepare_queue()
					return
			else:
				var maps = []
				for id in ids:
					var song = registry_song.get_item(id)
					if song: maps.append(song)
					else: Globals.notify(Globals.NOTIFY_ERROR,"No song found with id %s" % [id],"Error")
				if maps.size() == 0:
					console_cmd_error("No valid maps specified")
					return
				select_song(maps[0])
				song_queue = maps
				prepare_queue()
				Globals.notify(Globals.NOTIFY_SUCCEED,"queue OK")
		"play":
			get_tree().change_scene("res://scenes/loaders/songload.tscn")
		"desyncalerts":
			Globals.notify(Globals.NOTIFY_SUCCEED,"Enabled desync alerts","Success")
			desync_alerts = true
		"disablesync":
			Globals.notify(Globals.NOTIFY_SUCCEED,"Disabled desync checks","Success")
			disable_desync = true

# Utility functions
func console_cmd_error(body:String):
	Globals.confirm_prompt.s_alert.play()
	Globals.confirm_prompt.open(body,"Error",[{text="OK"}])
	yield(Globals.confirm_prompt,"option_selected")
	Globals.confirm_prompt.s_back.play()
	Globals.confirm_prompt.close()
func update_rpc_song(): # Discord RPC
	if !ProjectSettings.get_setting("application/config/discord_rpc") or selected_song == null: return
	var txt = ""
	var mods = []
	if mod_nofail: mods.append("Nofail")
	if mod_speed_level != Globals.SPEED_NORMAL:
		match mod_speed_level:
			Globals.SPEED_MMM: mods.append("Speed---")
			Globals.SPEED_MM: mods.append("Speed--")
			Globals.SPEED_M: mods.append("Speed-")
			Globals.SPEED_P: mods.append("Speed+")
			Globals.SPEED_PP: mods.append("Speed++")
			Globals.SPEED_PPP: mods.append("Speed+++")
			Globals.SPEED_PPPP: mods.append("Speed++++")
			Globals.SPEED_CUSTOM: mods.append("Speed %s%%" % [Globals.speed_multi[Globals.SPEED_CUSTOM] * 100])
	if mod_sudden_death: mods.append("SuddenDeath")
	if mod_extra_energy: mods.append("Energy+")
	if mod_no_regen: mods.append("NoRegen")
	if mod_mirror_x or mod_mirror_y:
		var mirrorst = "Mirror"
		if Rhythia.mod_mirror_x: mirrorst += "X"
		if Rhythia.mod_mirror_y: mirrorst += "Y"
		mods.append(mirrorst)
	if mod_ghost: mods.append("Ghost")
	if mod_flashlight: mods.append("Flashlight")
	if mod_nearsighted: mods.append("Nearsight")
	if mod_hardrock: mods.append("Hard Rock")
	
	if mods.size() == 0: txt = "No modifiers"
	else:
		for i in range(mods.size()):
			if i != 0: txt += ", "
			txt += mods[i]
	
	var activity = Discord.Activity.new()
	activity.set_type(Discord.ActivityType.Playing)
	activity.set_state(txt)
	activity.set_details(selected_song.name)

	var assets = activity.get_assets()
	assets.set_large_image("icon-bg")

	Discord.activity_manager.update_activity(activity)
func get_stream_with_default(path:String,default:AudioStream) -> AudioStream:
	path = Globals.p(path)
	var file:File = File.new()
	if file.file_exists(path + ".ogg"): path += ".ogg"
	elif file.file_exists(path + ".mp3"): path += ".mp3"
	elif file.file_exists(path + ".wav"): path += ".wav"
	if file.file_exists(path):
		if !path.begins_with("res://"):
			var stream = Globals.audioLoader.load_file(path)
			if stream and stream is AudioStream: return stream
		else: 
			var mf:AudioStream = load(path) as AudioStream
			if mf is AudioStream:
				if mf is AudioStreamOGGVorbis or mf is AudioStreamMP3: mf.loop = false
				elif mf is AudioStreamSample: mf.loop_mode = AudioStreamSample.LOOP_DISABLED
				return mf
	return default




# Modifiers - Normal
var mod_extra_energy:bool = false setget set_mod_extra_energy # Easy Mode
var mod_no_regen:bool = false setget set_mod_no_regen # Hard Mode
var mod_speed_level:int = Globals.SPEED_NORMAL setget set_mod_speed_level
var mod_nofail:bool = false setget set_mod_nofail
var mod_mirror_x:bool = false setget set_mod_mirror_x
var mod_mirror_y:bool = false setget set_mod_mirror_y
var mod_nearsighted:bool = false setget set_mod_nearsighted
var mod_ghost:bool = false setget set_mod_ghost
var mod_sudden_death:bool = false setget set_mod_sudden_death
var mod_chaos:bool = false setget set_mod_chaos
var mod_earthquake:bool = false setget set_mod_earthquake
var mod_flashlight:bool = false setget set_mod_flashlight
var mod_hardrock:bool = false setget set_mod_hardrock
# Modifiers - Custom values
var start_offset:float = 0 setget _set_start_offset
var note_hitbox_size:float = 1.140 setget _set_hitbox_size
var hitwindow_ms:float = 55 setget _set_hitwindow
var custom_speed:float = 1 setget _set_custom_speed
# Modifiers - Special
var health_model:int = Globals.HP_SOUNDSPACE setget _set_health_model
var grade_system:int = Globals.GRADE_SSP setget _set_grade_system
var visual_mode:bool = false setget set_visual_mode
var invert_mouse:bool = false setget set_invert_mouse
var disable_pausing:bool = false
var speed_hitwindow:bool = true
var restart_on_death:bool = false

# Mod setters - Normal
func set_mod_extra_energy(v:bool):
	if v:
		mod_sudden_death = false
		mod_nofail = false
	mod_extra_energy = v; emit_signal("mods_changed")
func set_mod_no_regen(v:bool):
	if v:
		mod_sudden_death = false
		mod_nofail = false
	mod_no_regen = v; emit_signal("mods_changed")
func set_mod_speed_level(v:int):
	mod_speed_level = v; emit_signal("mods_changed"); emit_signal("speed_mod_changed")
func set_mod_nofail(v:bool):
	if v:
		mod_extra_energy = false
		mod_no_regen = false
		mod_sudden_death = false
	else:
		visual_mode = false
	mod_nofail = v; emit_signal("mods_changed")
func set_mod_mirror_x(v:bool):
	mod_mirror_x = v; emit_signal("mods_changed")
func set_mod_mirror_y(v:bool):
	mod_mirror_y = v; emit_signal("mods_changed")
func set_mod_nearsighted(v:bool):
	mod_nearsighted = v; emit_signal("mods_changed")
func set_mod_ghost(v:bool):
	mod_ghost = v; emit_signal("mods_changed")
func set_mod_sudden_death(v:bool):
	if v:
		mod_extra_energy = false
		mod_no_regen = false
		mod_nofail = false
	mod_sudden_death = v; emit_signal("mods_changed")
func set_mod_chaos(v:bool):
	mod_chaos = v; emit_signal("mods_changed")
func set_mod_earthquake(v:bool):
	mod_earthquake = v; emit_signal("mods_changed")
func set_mod_flashlight(v:bool):
	mod_flashlight = v; emit_signal("mods_changed")
func set_mod_hardrock(v:bool):
	mod_hardrock = v; emit_signal("mods_changed")
# Mod setters - Custom values
func _set_start_offset(v:float):
	start_offset = v; emit_signal("mods_changed")
func _set_hitbox_size(v:float):
	note_hitbox_size = v; emit_signal("mods_changed")
func _set_hitwindow(v:float):
	hitwindow_ms = v; emit_signal("mods_changed")
func _set_custom_speed(v:float):
	print("custom speed changed")
	custom_speed = v
	Globals.speed_multi[Globals.SPEED_CUSTOM] = v
	emit_signal("mods_changed")
	emit_signal("speed_mod_changed")
# Mod setters - Special
func set_visual_mode(v:bool):
	if v:
		set_mod_nofail(true)
	visual_mode = v; emit_signal("mods_changed")
func set_invert_mouse(v:bool):
	invert_mouse = v; emit_signal("mods_changed")
func _set_health_model(v:int):
	health_model = v; emit_signal("mods_changed")
func _set_grade_system(v:int):
	grade_system = v; emit_signal("mods_changed")


# Settings - Notes
var approach_rate:float = 40 setget ,get_approach_rate
func get_approach_rate():
	if replaying and replay.settings.has("approach_rate"): return replay.settings.get("approach_rate")
	return approach_rate
var spawn_distance:float = 40 setget ,get_spawn_distance
func get_spawn_distance():
	if replaying and replay.settings.has("spawn_distance"): return replay.settings.get("spawn_distance")
	return spawn_distance
var do_note_pushback:bool = true # true; notes go past grid on miss, false; notes always vanish at grid
var half_ghost:bool = false
var note_spawn_effect:bool = false
var note_size:float = 1
var note_spin_x:float = 0
var note_spin_y:float = 0
var note_spin_z:float = 0
# actually nah llol !!!!! (vector is not needed i can just do it in another script)
# var note_spin_vector:Vector3 = Vector3(note_spin_x,note_spin_y,note_spin_z)
var note_opacity:float = 1
var fade_length:float = 0.5 setget ,get_fade_length
func get_fade_length():
	if replaying and replay.settings.has("fade_length"): return replay.settings.get("fade_length")
	return fade_length

var show_hit_effect:bool = true
var hit_effect_at_cursor:bool = true

var show_miss_effect:bool = true

# Settings - Camera/Controls
var hlm_converted:bool = false
var sensitivity:float = 0.5
var parallax:float = 6.5 setget ,get_parallax
func get_parallax():
	if replaying and replay.settings.has("parallax"): return replay.settings.get("parallax")
	return parallax
var ui_parallax:float = 1.63 setget ,get_ui_parallax
func get_ui_parallax():
	if replaying and replay.settings.has("ui_parallax"): return replay.settings.get("ui_parallax")
	return ui_parallax
var grid_parallax:float = 0 setget ,get_grid_parallax
func get_grid_parallax():
	if replaying and replay.settings.has("grid_parallax"): return replay.settings.get("grid_parallax")
	return grid_parallax
var fov:float = 70  setget ,get_fov
func get_fov():
	if replaying and replay.settings.has("fov"): return replay.settings.get("fov")
	return fov
var hit_fov:bool = false
var hit_fov_additive:bool = true
var hit_fov_exponential:bool = false
var hit_fov_amplifier:float = 2
var hit_fov_decay:float = 20
var camera_mode:int = Globals.CAMERA_HALF_LOCK
var cam_unlock:bool = false setget ,get_cam_unlock
func get_cam_unlock():
	if replaying and replay.settings.has("cam_unlock"): return replay.settings.get("cam_unlock")
	return cam_unlock
var lock_mouse:bool = true
var absolute_mode:bool = false
var absolute_scale:float = 1
var edge_drift:float = 0
var disable_intro:bool = false

# Settings - Replays
var record_replays:bool = false
var alt_cam:bool = false
var record_limit:int = 0
var record_mode:int = 1

# Settings - Cursor
var cursor_color_type:int = Globals.CURSOR_CUSTOM_COLOR
var cursor_color:Color = Color(1,1,1)

var cursor_trail:bool = false
var trail_mode_scale:bool = true
var trail_mode_opacity:bool = true
var smart_trail:bool = false
var trail_detail:int = 10
var trail_time:float = 0.15
var cursor_scale:float = 1
var enable_drift_cursor:bool = true
var follow_drift_cursor:bool = false
var cursor_spin:float = 0
var cursor_face_velocity:bool = false # Disabled

# Settings - HUD
var display_true_combo:bool = true
var show_config:bool = true
var enable_grid:bool = false
var enable_border:bool = true
var show_hp_bar:bool = true
var show_timer:bool = true
var show_left_panel:bool = true
var show_right_panel:bool = true
var show_cursor:bool = true
var show_accuracy_bar:bool = true
var show_letter_grade:bool = true
var attach_hp_to_grid:bool = false
var attach_timer_to_grid:bool = false
var simple_hud:bool = false
var faraway_hud:bool = true
var rainbow_grid:bool = false
var rainbow_hud:bool = false
var friend_position:int = Globals.FRIEND_BEHIND_GRID # Hidden
var note_visual_approach:bool = false # Experimental
var visual_approach_follow:bool = false
var billboard_score:bool = false
var score_popup:bool = false
var mirror_buttons:bool = false

# Settings - HUD Colors
var panel_bg:Color = Color("#9b000000") #9bcecece
var panel_text:Color = Color("#ffffff") #000000

var unpause_fill_color:Color = Color("#80fff3") #fd00ff
var unpause_empty_color:Color = Color("#68ff00") #8500ff
var how_to_quit:Color = Color("#ffdb00") #be0000

var combo_fill_color:Color = Color("#7bfff3") #ff00c5
var combo_empty_color:Color = Color("#b94b4b4b") #d64b4b4b

var acc_fill_color:Color = Color("#8cff00") #8cff00
var acc_empty_color:Color = Color("#b08f8f8f") #b08f8f8f

var giveup_text:Color = Color("#ffffff") #000000
var giveup_fill_color:Color = Color("#ff8f2c") #ff8f2c
var giveup_fill_color_end_skip:Color = Color("#81ff75") #81ff75

var timer_text:Color = Color("#ffffff") #000000
var timer_text_done:Color = Color("#77ff77") #000000
var timer_text_canskip:Color = Color("#b3ffff") #60005c

var timer_fg:Color = Color("#ffffff") #000000
var timer_bg:Color = Color("#af8f8f8f") #af000000
var timer_fg_done:Color = Color("#25bf00") #25bf00
var timer_bg_done:Color = Color("#af008f00") #af008f00
var timer_fg_canskip:Color = Color("#b3ffff") #760070
var timer_bg_canskip:Color = Color("#b0638f8f") #b02b172a

var miss_flash_color:Color = Color("#ff0000") #ff0000
var pause_used_color:Color = Color("#ff66ff") #2600c2

var miss_text_color:Color = Color("#ffffff") #000000
var pause_text_color:Color = Color("#ffffff") #000000
var score_text_color:Color = Color("#ffffff") #000000

var pause_ui_opacity:float = 0.75 # 0.75

var grade_ss_saturation:float = 0.4 # 0.5
var grade_ss_value:float = 1 # 0.5
var grade_ss_shine:float = 1 # 1

var grade_s_color:Color = Color("#91fffa") #143dff
var grade_s_shine:float = 0.5 # 0.5

var grade_a_color:Color = Color("#91ff92") #20c523
var grade_b_color:Color = Color("#e7ffc0") #8a9530
var grade_c_color:Color = Color("#fcf7b3") #ffb500
var grade_d_color:Color = Color("#fcd0b3") #ff6600
var grade_f_color:Color = Color("#ff8282") #d14747


# Settings - Audio
var auto_preview_song:bool = true
var play_hit_snd:bool = true
var play_miss_snd:bool = true
var sfx_2d:bool = false
var music_offset:float = 0
var play_menu_music:bool = true setget _set_menu_music
var music_volume_db:float = 0 setget _set_music_volume
func _set_menu_music(v:bool):
	play_menu_music = v; emit_signal("menu_music_state_changed")
func _set_music_volume(v:float):
	music_volume_db = v; emit_signal("volume_changed")

# Settings - Misc
var disable_bg_effects:bool = false
var show_warnings:bool = true
var auto_maximize:bool = false

# Settings - Graphics & Advanced

# Settings - Shaders
var glow:float = 0
var bloom:float = 0
var vhs_shader:bool = false

# Settings - Experimental
var render_scale:float = 1
var ensure_hitsync:bool = false
var hitsync_offset:float = 0 # don't save this yet; probably not even a necessary setting
var retain_song_pitch:bool = false # not recommended as this is very heavy to compute, but people want it
var show_stats:bool = false
var hit_pitch:bool = false
var hit_pitch_min:float = 0.9
var hit_pitch_max:float = 1.15

var arcw_mode:bool = false # heheheha
var sex_mode:bool = false
var memory_lane:bool = false # :(

var language:int = 0


# Favorited songs
var favorite_songs:Array = []
func save_favorites():
	if !single_map_mode:
		var file:File = File.new()
		file.open(Globals.p("user://favorites.txt"),File.WRITE)
		var txt:String = ""
		for s in favorite_songs:
			if s != favorite_songs[0]: txt += "\n"
			txt += s
		file.store_line(txt)
		file.close()
func is_favorite(id:String):
	return !single_map_mode and favorite_songs.has(id)
func add_favorite(id:String):
	if !single_map_mode and !favorite_songs.has(id):
		favorite_songs.append(id)
		emit_signal("favorite_songs_changed")
		save_favorites()
func remove_favorite(id:String):
	if !single_map_mode and favorite_songs.has(id):
		favorite_songs.remove(favorite_songs.find(id))
		emit_signal("favorite_songs_changed")
		save_favorites()



# Personal bests
func do_pb_check_and_set() -> bool:
	if mod_nofail or was_replay or start_offset != 0 or just_ended_queue or OS.has_feature("debug"): return false
	var has_passed:bool = song_end_type == Globals.END_PASS
	var pb:Dictionary = {}
	pb.position = song_end_position
	pb.length = song_end_length
	pb.hit_notes = song_end_hits
	pb.total_notes = song_end_total_notes
	pb.pauses = song_end_pause_count
	pb.has_passed = song_end_type == Globals.END_PASS
	pb.max_combo = song_end_combo
	return selected_song.set_pb_if_better(generate_pb_str(true),pb)
func get_best():
	return selected_song.get_pb(generate_pb_str(true))

func generate_pb_str(for_pb:bool=false):
	var pts:Array = []
	match mod_speed_level:
		Globals.SPEED_MMM: pts.append("s:---")
		Globals.SPEED_MM: pts.append("s:--")
		Globals.SPEED_M: pts.append("s:-")
		Globals.SPEED_NORMAL: pts.append("s:=")
		Globals.SPEED_P: pts.append("s:+")
		Globals.SPEED_PP: pts.append("s:++")
		Globals.SPEED_PPP: pts.append("s:+++")
		Globals.SPEED_PPPP: pts.append("s:++++")
		Globals.SPEED_CUSTOM: pts.append("s:c%.2f" % custom_speed)
	match health_model:
		Globals.HP_OLD: pts.append("hp_old")
		Globals.HP_SOUNDSPACE: pass # prevents wiping of old pbs
	pts.append("hitw:%s" % String(floor(hitwindow_ms)))
	var hb = note_hitbox_size
	pts.append("hbox:%.02f" % note_hitbox_size)
	pts.append("ar:%d" % sign(approach_rate))
	if !for_pb and start_offset != 0: pts.append("so:%f" % start_offset)
	if music_volume_db <= -50: pts.append("silent")
	
	if mod_sudden_death: pts.append("m_sd")
	if mod_extra_energy: pts.append("m_morehp")
	if mod_no_regen: pts.append("m_noregen")
	if mod_mirror_x: pts.append("m_mirror_x")
	if mod_mirror_y: pts.append("m_mirror_y")
	if mod_nearsighted: pts.append("m_nsight")
	if mod_ghost: pts.append("m_ghost")
	if mod_sudden_death: pts.append("m_sd")
	if mod_chaos: pts.append("m_chaos")
	if invert_mouse: pts.append("m_im")
	if mod_earthquake: pts.append("m_earthquake")
	if mod_flashlight: pts.append("m_flashlight")
	if mod_hardrock: pts.append("m_hardrock")
	if mod_nofail: pts.append("m_nofail") # for replays
	
	pts.sort()
	
	var s:String = ""
	for i in range(pts.size()):
		if i != 0: s += ";"
		s += pts[i]
	
	return s

# PB string state data (for replays)
func parse_pb_str(txt:String):
	var data:Dictionary = {}
	var pts:Array = txt.split(";",false)
	data.health_model = Globals.HP_SOUNDSPACE
	
	data.start_offset = 0
	data.mod_sudden_death = false
	data.mod_extra_energy = false
	data.mod_no_regen = false
	data.mod_mirror_x = false
	data.mod_mirror_y = false
	data.mod_nearsighted = false
	data.mod_ghost = false
	data.mod_chaos = false
	data.invert_mouse = false
	data.mod_earthquake = false
	data.mod_flashlight = false
	data.mod_hardrock = false
	data.mod_nofail = false
	
	for s in pts:
		if s.begins_with("s:c"):
			data.mod_speed_level = Globals.SPEED_CUSTOM
			data.custom_speed = float(s.substr(3))
		elif s.begins_with("hitw:"):
			data.hitwindow_ms = float(s.substr(5))
		elif s.begins_with("so:"):
			data.start_offset = float(s.substr(3))
		elif s.begins_with("hbox:"):
			data.note_hitbox_size = float(s.substr(5))
		else:
			match s:
				"s:---": data.mod_speed_level = Globals.SPEED_MMM
				"s:--": data.mod_speed_level = Globals.SPEED_MM
				"s:-": data.mod_speed_level = Globals.SPEED_M
				"s:=": data.mod_speed_level = Globals.SPEED_NORMAL
				"s:+": data.mod_speed_level = Globals.SPEED_P
				"s:++": data.mod_speed_level = Globals.SPEED_PP
				"s:+++": data.mod_speed_level = Globals.SPEED_PPP
				"s:++++": data.mod_speed_level = Globals.SPEED_PPPP
				"hp_old": data.health_model = Globals.HP_OLD
				"m_sd": data.mod_sudden_death = true
				"m_morehp": data.mod_extra_energy = true
				"m_noregen": data.mod_no_regen = true
				"m_mirror_x": data.mod_mirror_x = true
				"m_mirror_y": data.mod_mirror_y = true
				"m_nsight": data.mod_nearsighted = true
				"m_ghost": data.mod_ghost = true
				"m_chaos": data.mod_chaos = true
				"m_im": data.invert_mouse = true
				"m_earthquake": data.mod_earthquake = true
				"m_flashlight": data.mod_flashlight = true
				"m_hardrock": data.mod_hardrock = true
				"m_nofail": data.mod_nofail = true
	return data
var prev_state:Dictionary = {}
func save_current_state(): prev_state = parse_pb_str(generate_pb_str())
func restore_prev_state(): for k in prev_state.keys(): set(k,prev_state.get(k))
func apply_state(state:Dictionary): for k in state.keys(): set(k,state.get(k))

# Legacy PB conversion
var personal_bests:Dictionary = {}
func convert_song_pbs(song:Song):
	for pb in personal_bests.get(song.id,[]):
		mod_extra_energy = pb.mod_extra_energy
		mod_no_regen = pb.mod_no_regen
		mod_speed_level = pb.mod_speed_level
		var npb = {
			"position": pb.position,
			"length": pb.length,
			"hit_notes": pb.hit_notes,
			"total_notes": pb.total_notes,
			"pauses": pb.pauses,
			"has_passed": pb.has_passed
		}
		song.set_pb_if_better(generate_pb_str(true),npb)
func load_pbs():
	var file:File = File.new()
	if file.file_exists(Globals.p("user://pb.json")):
		file.open(Globals.p("user://pb.json"),File.READ)
		personal_bests = parse_json(file.get_as_text())
		file.close()
	elif file.file_exists(Globals.p("user://pb")):
		file.open(Globals.p("user://pb"),File.READ)
		var ver:int = file.get_16() # READ 2
		var x:int = file.get_16() # READ 2
		while !file.eof_reached():
			if x == 16384 or file.eof_reached():
				file.close()
				return
			var songid:String
			if ver == 2: songid = file.get_pascal_string()
			else: songid = file.get_line() # READ STRING+1
			personal_bests[songid] = []
			x = file.get_16() # READ 2
			while x == 69:
				var pb = {}
				pb.has_passed = bool(file.get_8()) # READ 1
				pb.mod_extra_energy = bool(file.get_8()) # READ 1
				pb.mod_no_regen = bool(file.get_8()) # READ 1
				pb.mod_speed_level = file.get_8() # READ 1
				pb.position = file.get_64() # READ 8
				pb.length = file.get_64() # READ 8
				pb.hit_notes = file.get_32() # READ 4
				pb.total_notes = file.get_32() # READ 4
				pb.pauses = file.get_16() # READ 2
				personal_bests[songid].append(pb)
				x = file.get_16() # READ 2
		file.close()

# dumb lacunella stuff
func is_lacunella_enabled():
	var cdat = File.new()
	if cdat.file_exists("user://lacunella.dat"):
		cdat.open("user://lacunella.dat",File.READ)
		var ctxt = cdat.get_as_text()
		if ctxt.to_upper() == "MEOW": return true
	return false

# for max
func memory_lacu():
	var cdata = File.new()
	if cdata.file_exists("user://memory.dat"):
		cdata.open("user://memory.dat",File.READ)
		var ctxt = cdata.get_as_text()
		if ctxt.to_upper() == "DYAMO": return true
	return false

# Settings save/load helpers
func scol(c:Color) -> String:
	return c.to_html(c.a != 1)
func lcol(data:Dictionary,target:String) -> void:
	if data.has(target) and Color(data[target]):
		set(target, Color(data[target]))

# Settings file
const current_sf_version = 48 # SV
func load_saved_settings(saveFile:String = Globals.p("user://settings.json")):
	if Input.is_key_pressed(KEY_CONTROL) and Input.is_key_pressed(KEY_L): 
		print("force settings read error")
		return -1
	var file:File = File.new()
	
	if file.file_exists(saveFile):
		var err = file.open(saveFile, File.READ)
		if err != OK:
			print("file.open failed"); return -2
		var decode = JSON.parse(file.get_as_text())
		file.close()
		
		if decode.error:
			print("!!! Error on line " + str(decode.error_line) + ": " + decode.error_string)
			return ((-100) - decode.error)
		
		var data:Dictionary = decode.result
		
		if data.has("hlm_converted"):
			hlm_converted = data.hlm_converted
		if data.has("approach_rate"): 
			approach_rate = data.approach_rate
		if data.has("sensitivity"): 
			sensitivity = data.sensitivity
		if data.has("play_hit_snd"): 
			play_hit_snd = data.play_hit_snd
		if data.has("play_miss_snd"): 
			play_miss_snd = data.play_miss_snd
		if data.has("auto_preview_song"): 
			auto_preview_song = data.auto_preview_song
		if data.has("disable_bg_effects"):
			disable_bg_effects = data.disable_bg_effects
		if data.has("render_scale"):
			render_scale = data.render_scale
		if data.has("vsync_enabled"): 
			OS.vsync_enabled = data.vsync_enabled
#		if data.has("vsync_via_compositor"): 
#			OS.vsync_via_compositor = data.vsync_via_compositor
		OS.vsync_via_compositor = false
		if data.has("window_fullscreen"): 
			OS.window_fullscreen = data.window_fullscreen
		if data.has("selected_colorset"): 
			var cset = registry_colorset.get_item(data.selected_colorset)
			if cset: select_colorset(cset)
		if data.has("cam_unlock"): 
			cam_unlock = data.cam_unlock
		if data.has("show_config"): 
			show_config = data.show_config
		if data.has("enable_grid"): 
			enable_grid = data.enable_grid
		if data.has("cursor_scale"): 
			cursor_scale = data.cursor_scale
		if data.has("note_size"): 
			note_size = data.note_size
		if data.has("note_spin_x"):
			note_spin_x = data.note_spin_x
		if data.has("note_spin_y"):
			note_spin_y = data.note_spin_y
		if data.has("note_spin_z"):
			note_spin_z = data.note_spin_z
		if data.has("note_opacity"):
			note_opacity = data.note_opacity
		if data.has("edge_drift"): 
			edge_drift = dser_float(data.edge_drift)
		if data.has("enable_drift_cursor"): 
			enable_drift_cursor = data.enable_drift_cursor
		if data.has("follow_drift_cursor"): 
			follow_drift_cursor = data.follow_drift_cursor
		if data.has("hitwindow_ms"): 
			hitwindow_ms = data.hitwindow_ms
		if data.has("speed_hitwindow"):
			speed_hitwindow = data.speed_hitwindow
		if data.has("restart_on_death"):
			restart_on_death = data.restart_on_death
		if data.has("cursor_spin"): 
			cursor_spin = data.cursor_spin
		if data.has("selected_space"): 
			var world = registry_world.get_item(data.selected_space)
			if world:
				select_world(world)
		if data.has("enable_border"): 
			enable_border = data.enable_border
		if data.has("selected_mesh"): 
			var mesh = registry_mesh.get_item(data.selected_mesh)
			if mesh:
				select_mesh(mesh)
		if data.has("play_menu_music"): 
			play_menu_music = data.play_menu_music
		if data.has("disable_pausing"): 
			disable_pausing = data.disable_pausing
		if data.has("note_hitbox_size"): 
			note_hitbox_size = data.note_hitbox_size
		if data.has("spawn_distance"): 
			spawn_distance = data.spawn_distance
		if data.has("custom_speed"): 
			set("custom_speed",data.custom_speed)
		if data.has("note_spawn_effect"): 
			note_spawn_effect = data.note_spawn_effect
		if data.has("display_true_combo"): 
			display_true_combo = data.display_true_combo
		
		if data.has("parallax"): 
			parallax = data.parallax
		if data.has("ui_parallax"): 
			ui_parallax = data.ui_parallax
		if data.has("grid_parallax"): 
			grid_parallax = data.grid_parallax
		
		if data.has("fov"):
			fov = data.fov
		if data.has("hit_fov"):
			hit_fov = data.hit_fov
		if data.has("hit_fov_additive"):
			hit_fov_additive = data.hit_fov_additive
		if data.has("hit_fov_exponential"):
			hit_fov_exponential = data.hit_fov_exponential
		if data.has("hit_fov_amplifier"):
			hit_fov_amplifier = data.hit_fov_amplifier
		if data.has("hit_fov_decay"):
			hit_fov_decay = data.hit_fov_decay
		if data.has("fade_length"): 
			fade_length = data.fade_length
		if data.has("show_hit_effect"): 
			show_hit_effect = data.show_hit_effect
		if data.has("lock_mouse"): 
			lock_mouse = data.lock_mouse
		if data.has("absolute_mode"):
			absolute_mode = data.absolute_mode
		if data.has("absolute_scale"):
			absolute_scale = data.absolute_scale
		if data.has("cursor_trail"): 
			cursor_trail = data.cursor_trail
		if data.has("trail_mode_scale"):
			trail_mode_scale = data.trail_mode_scale
		if data.has("trail_mode_opacity"):
			trail_mode_opacity = data.trail_mode_opacity
		if data.has("trail_detail"): 
			trail_detail = data.trail_detail
		if data.has("trail_time"): 
			trail_time = data.trail_time
		if data.has("friend_position"): 
			friend_position = data.friend_position
		if data.has("show_hp_bar"): 
			show_hp_bar = data.show_hp_bar
		if data.has("show_timer"): 
			show_timer = data.show_timer
		if data.has("show_left_panel"): 
			show_left_panel = data.show_left_panel
		if data.has("show_right_panel"): 
			show_right_panel = data.show_right_panel
		if data.has("attach_hp_to_grid"): 
			attach_hp_to_grid = data.attach_hp_to_grid
		if data.has("attach_timer_to_grid"): 
			attach_timer_to_grid = data.attach_timer_to_grid
		if data.has("rainbow_grid"): 
			rainbow_grid = data.rainbow_grid
		if data.has("rainbow_hud"): 
			rainbow_hud = data.rainbow_hud
		if data.has("selected_hit_effect"): 
			var eff = registry_effect.get_item(data.selected_hit_effect)
			if eff:
				select_hit_effect(eff)
			
		if data.has("hit_effect_at_cursor"): 
			hit_effect_at_cursor = data.hit_effect_at_cursor
		if data.has("show_warnings"): 
			show_warnings = data.show_warnings
		if data.has("record_replays"): 
			should_ask_about_replays = false
			record_replays = data.record_replays
		if data.has("alt_cam"): 
			alt_cam = data.alt_cam
		if data.has("record_mode"):
			record_mode = data.record_mode
		if data.has("record_limit"):
			record_limit = data.record_limit
		if data.has("show_accuracy_bar"): 
			show_accuracy_bar = data.show_accuracy_bar
		if data.has("show_letter_grade"): 
			show_letter_grade = data.show_letter_grade
		if data.has("simple_hud"): 
			simple_hud = data.simple_hud
		if data.has("faraway_hud"): 
			faraway_hud = data.faraway_hud
		if data.has("music_offset"): 
			music_offset = data.music_offset
		if data.has("selected_miss_effect"): 
			var eff = registry_effect.get_item(data.selected_miss_effect)
			if eff:
				select_miss_effect(eff)
		if data.has("show_miss_effect"): 
			show_miss_effect = data.show_miss_effect
		if data.has("auto_maximize"): 
			auto_maximize = data.auto_maximize
			if auto_maximize: OS.window_maximized = true
		if data.has("window_fullscreen"): 
			OS.window_fullscreen = data.window_fullscreen
		if data.has("window_borderless"): 
			OS.window_borderless = data.window_borderless
		if data.has("note_visual_approach"): 
			note_visual_approach = data.note_visual_approach
		if data.has("visual_approach_follow"): 
			visual_approach_follow = data.visual_approach_follow
		if data.has("score_popup"): 
			score_popup = data.score_popup
		if data.has("billboard_score"): 
			billboard_score = data.billboard_score
		if data.has("mirror_buttons"): 
			mirror_buttons = data.mirror_buttons
		if data.has("smart_trail"): 
			smart_trail = data.smart_trail
		if data.has("sfx_2d"): 
			sfx_2d = data.sfx_2d
		
		if data.has("pause_ui_opacity"):
			pause_ui_opacity = data.pause_ui_opacity
		if data.has("grade_ss_saturation"):
			grade_ss_saturation = data.grade_ss_saturation
		if data.has("grade_ss_value"):
			grade_ss_value = data.grade_ss_value
		if data.has("grade_ss_shine"):
			grade_ss_shine = data.grade_ss_shine
		if data.has("grade_s_shine"):
			grade_s_shine = data.grade_s_shine
		
		if data.has("cursor_color_type"): 
			cursor_color_type = data.cursor_color_type
		elif data.has("rainbow_cursor"):
			cursor_color_type = Globals.CURSOR_RAINBOW
		
		if data.has("target_fps"):
			Engine.target_fps = data.target_fps
		if data.has("disable_intro"):
			disable_intro = data.disable_intro
		if data.has("ignore_controller_detection"):
			ignore_controller_detection = data.ignore_controller_detection
		if data.has("expand_hud_onhr"):
			expand_hud_onhr = data.expand_hud_onhr
		
		if data.has("master_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), dser_float(data.master_volume))
		if data.has("music_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), dser_float(data.music_volume))
		if data.has("hit_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("HitSound"), dser_float(data.hit_volume))
		if data.has("miss_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MissSound"), dser_float(data.miss_volume))
		if data.has("fail_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("FailSound"), dser_float(data.fail_volume))
		if data.has("pb_volume"):
			AudioServer.set_bus_volume_db(AudioServer.get_bus_index("PBSound"), dser_float(data.pb_volume))
		
		if data.has("ensure_hitsync"):
			ensure_hitsync = data.ensure_hitsync
		if data.has("retain_song_pitch"):
			retain_song_pitch = data.retain_song_pitch
		if data.has("do_note_pushback"):
			do_note_pushback = data.do_note_pushback
		if data.has("show_stats"):
			show_stats = data.show_stats
		if data.has("hit_pitch"):
			hit_pitch = data.hit_pitch
		if data.has("hit_pitch_min"):
			hit_pitch_min = data.hit_pitch_min
		if data.has("hit_pitch_max"):
			hit_pitch_max = data.hit_pitch_max
		if data.has("half_ghost"):
			half_ghost = data.half_ghost

		if data.has("language"):
			language = data.language
			TranslationServer.set_locale(Globals.locale[language])

		# menu2 settings

		if data.has("last_search_incl_online"):
			last_search_incl_online = data.last_search_incl_online
		
		lcol(data,"grade_s_color")
		lcol(data,"panel_bg")
		lcol(data,"panel_text")
		lcol(data,"unpause_fill_color")
		lcol(data,"unpause_empty_color")
		lcol(data,"how_to_quit")
		lcol(data,"combo_fill_color")
		lcol(data,"combo_empty_color")
		lcol(data,"acc_fill_color")
		lcol(data,"acc_empty_color")
		lcol(data,"giveup_text")
		lcol(data,"giveup_fill_color")
		lcol(data,"giveup_fill_color_end_skip")
		lcol(data,"timer_text")
		lcol(data,"timer_text_done")
		lcol(data,"timer_text_canskip")
		lcol(data,"timer_fg")
		lcol(data,"timer_bg")
		lcol(data,"timer_fg_done")
		lcol(data,"timer_bg_done")
		lcol(data,"timer_fg_canskip")
		lcol(data,"timer_bg_canskip")
		lcol(data,"miss_flash_color")
		lcol(data,"pause_used_color")
		lcol(data,"miss_text_color")
		lcol(data,"pause_text_color")
		lcol(data,"score_text_color")
		lcol(data,"grade_a_color")
		lcol(data,"grade_b_color")
		lcol(data,"grade_c_color")
		lcol(data,"grade_d_color")
		lcol(data,"grade_f_color")
		lcol(data,"cursor_color")

		if data.has("glow"):
			glow = data.glow
		if data.has("bloom"):
			bloom = data.bloom
		if data.has("vhs_shader"):
			vhs_shader = data.vhs_shader
		
	
	elif file.file_exists(Globals.p("user://settings")):
		var err = file.open(Globals.p("user://settings"),File.READ)
		if err != OK:
			print("file.open failed"); return 1
		var sv:int = file.get_16()
		if sv <= 3 or sv > current_sf_version:
			print("invalid file version"); return 2
		approach_rate = file.get_float()
		sensitivity = file.get_float()
		play_hit_snd = bool(file.get_8())
		play_miss_snd = bool(file.get_8())
		if sv >= 4: auto_preview_song = bool(file.get_8())
		if file.get_8() != 0:
			print("integ 1"); return 3
		OS.vsync_enabled = bool(file.get_8())
		OS.vsync_via_compositor = bool(file.get_8()) and false
		OS.window_fullscreen = bool(file.get_8())
		
		var cset = registry_colorset.get_item(file.get_line())
		if cset: select_colorset(cset)
		
		if sv >= 5:
			parallax = file.get_float()
		if sv >= 6:
			cam_unlock = bool(file.get_8())
		
		if sv >= 17: # Integrity check (added in sv 17)
			if file.get_8() != 215:
				print("integ 2"); return 4
		
		if sv >= 7: 
			show_config = bool(file.get_8())
			enable_grid = bool(file.get_8())
		if sv >= 8:
			cursor_scale = file.get_float()
		
		if sv >= 17: # Integrity check (added in sv 17)
			if file.get_8() != 43:
				print("integ 3"); return 5
		
		if sv >= 9:
			edge_drift = file.get_float()
			enable_drift_cursor = bool(file.get_8())
		if sv >= 10:
			hitwindow_ms = file.get_float()
		
		if sv >= 17: # Integrity check (added in sv 17)
			if file.get_8() != 117:
				print("integ 4"); return 6
		
		if sv >= 11:
			cursor_spin = file.get_float()
		if sv >= 12:
			music_volume_db = file.get_float()
		if sv >= 13:
			var world = registry_world.get_item(file.get_line())
			if world:
				select_world(world)
		
		if sv >= 17: # Integrity check (added in sv 17)
			if file.get_8() != 89:
				print("integ 5"); return 7
		
		if sv >= 14:
			enable_border = bool(file.get_8())
		if sv >= 15:
			var mesh = registry_mesh.get_item(file.get_line())
			if mesh:
				select_mesh(mesh)
		if sv >= 16:
			play_menu_music = bool(file.get_8())
		
		if sv >= 17: # Integrity check
			if file.get_8() != 12:
				print("integ 6"); return 8
		
		if sv >= 18:
			disable_pausing = bool(file.get_8())
			note_hitbox_size = float(str(file.get_float())) # fix weirdness with 1.14
		if sv >= 19:
			spawn_distance = file.get_float()
		if sv >= 20:
			set("custom_speed",file.get_float())
			note_spawn_effect = bool(file.get_8())
		if sv >= 21:
			display_true_combo = bool(file.get_8())
		if sv >= 22:
			#cursor_face_velocity = bool(
			file.get_8()#)
		if sv >= 23:
			
			if file.get_8() != 147: # Integrity check
				print("integ 7"); return 9
			
			ui_parallax = file.get_float()
		
		if sv >= 24:
			grid_parallax = file.get_float()
		else:
			# Keep old camera parallax for existing save files
			grid_parallax = 0
			ui_parallax = 0
		
		if sv >= 25:
			fade_length = file.get_float()
		
		if sv < 26 and String(note_hitbox_size) == "1.27":
			# Default hitbox change (this is when we solved 0.13)
			print("0.13 :laugh:")
			note_hitbox_size = 1.140
		
		if sv >= 27:
			show_hit_effect = bool(file.get_8())
		if sv >= 28:
			
			if file.get_8() != 6: # Integrity check
				print("integ 8"); return 10
			
			lock_mouse = bool(file.get_8())
			if bool(file.get_8()): # rainbow cursor
				cursor_color_type = Globals.CURSOR_RAINBOW
			cursor_trail = bool(file.get_8())
		if sv >= 29:
			trail_detail = file.get_32() # some people are insane
			trail_time = file.get_real() # 64-bit float bc small numbers
		if sv >= 30:
			friend_position = file.get_8()
			show_hp_bar = bool(file.get_8())
			show_timer = bool(file.get_8())
			show_left_panel = bool(file.get_8())
			show_right_panel = bool(file.get_8())
			attach_hp_to_grid = bool(file.get_8())
			attach_timer_to_grid = bool(file.get_8())
			rainbow_grid = bool(file.get_8())
			rainbow_hud = bool(file.get_8())
			var had_smart_trail = bool(file.get_8())
			if sv >= 32:
				smart_trail = had_smart_trail
			else:
				# New smart trail system
				alert = "The behavior of the Smart Trail setting has been significantly changed, so it has been turned off. See its description in Settings for the new behavior."
				save_settings()
		if sv >= 31:
			var eff = registry_effect.get_item(file.get_line())
			if eff:
				select_hit_effect(eff)
			
			if file.get_8() != 192: # Integrity check
				print("integ 9"); return 11
			
			hit_effect_at_cursor = bool(file.get_8())
		if sv >= 33:
			show_warnings = bool(file.get_8())
		if sv >= 34:
			should_ask_about_replays = false
			record_replays = bool(file.get_8())
		if sv >= 35:
			alt_cam = bool(file.get_8())
		if sv >= 36:
			show_accuracy_bar = bool(file.get_8())
			show_letter_grade = bool(file.get_8())
			simple_hud = bool(file.get_8())
		if sv >= 37:
			faraway_hud = bool(file.get_8())
		if sv >= 38:
			if sv >= 41:
				music_offset = float(file.get_float())
			else:
				music_offset = float(file.get_32())
		if sv >= 39:
			var eff = registry_effect.get_item(file.get_line())
			if eff:
				select_miss_effect(eff)
			show_miss_effect = bool(file.get_8())
		if sv >= 40:
			auto_maximize = bool(file.get_8())
		if sv >= 42:
			note_visual_approach = bool(file.get_8())
		if sv >= 43:
			score_popup = bool(file.get_8())
			billboard_score = bool(file.get_8())
			if (OS.has_feature("Android")): mirror_buttons = bool(file.get_8())
		if sv >= 44:
			fov = float(file.get_32())
			hit_fov = bool(file.get_8())
			hit_fov_additive = bool(file.get_8())
			hit_fov_amplifier = float(file.get_32())
			hit_fov_decay = float(file.get_32())
		if sv >= 45:
			hit_fov_exponential = bool(file.get_8())
		if sv >= 46:
			ensure_hitsync = bool(file.get_8())
		if sv >= 47:
			trail_mode_scale = bool(file.get_8())
			trail_mode_opacity = bool(file.get_8())
		if sv >= 48:
			ignore_controller_detection = bool(file.get_8())
		if sv >= 49:
			expand_hud_onhr = bool(file.get_8())
		if sv >= 50:
			last_search_incl_online = bool(file.get8())
		file.close()
		save_settings()
	return 0
	
func ser_float(n: float):
	if is_nan(n):
		return "nan"
	elif is_inf(n):
		return "+inf" if sign(n) > 0 else "-inf"
	else:
		return n

func dser_float(s):
	if typeof(s) == TYPE_STRING:
		if "inf" in s:
			return INF * (1 if s[0] == "+" else -1)
		else:
			return NAN
	else:
		return s

func save_settings(saveFile:String = Globals.p("user://settings.json")):
	var file:File = File.new()
	var err:int = file.open(Globals.p(saveFile),File.WRITE)
	if err == OK:
		var data = {
			hlm_converted = hlm_converted,
			disable_pausing = disable_pausing,
			approach_rate = approach_rate,
			sensitivity = sensitivity,
			play_hit_snd = play_hit_snd,
			play_miss_snd = play_miss_snd,
			auto_preview_song = auto_preview_song,
			disable_bg_effects = disable_bg_effects,
			render_scale = render_scale,
			vsync_enabled = OS.vsync_enabled,
#			vsync_via_compositor = OS.vsync_via_compositor,
			window_fullscreen = OS.window_fullscreen,
			window_borderless = OS.window_borderless,
			selected_colorset = selected_colorset.id,
			selected_space = selected_space.id,
			selected_mesh = selected_mesh.id,
			selected_hit_effect = selected_hit_effect.id,
			parallax = parallax,
			fov = fov,
			hit_fov = hit_fov,
			hit_fov_additive = hit_fov_additive,
			hit_fov_amplifier = hit_fov_amplifier,
			hit_fov_exponential = hit_fov_exponential,
			hit_fov_decay = hit_fov_decay,
			trail_mode_scale = trail_mode_scale,
			trail_mode_opacity = trail_mode_opacity,
			cam_unlock = cam_unlock,
			show_config = show_config,
			enable_grid = enable_grid,
			cursor_scale = cursor_scale,
			enable_drift_cursor = enable_drift_cursor,
			follow_drift_cursor = follow_drift_cursor,
			hitwindow_ms = hitwindow_ms,
			speed_hitwindow = speed_hitwindow,
			restart_on_death = restart_on_death,
			cursor_spin = cursor_spin,
			note_size = note_size,
			note_opacity = note_opacity,
			note_spin_x = note_spin_x,
			note_spin_y = note_spin_y,
			note_spin_z = note_spin_z,
			enable_border = enable_border,
			play_menu_music = play_menu_music,
			note_hitbox_size = note_hitbox_size,
			spawn_distance = spawn_distance,
			custom_speed = custom_speed,
			display_true_combo = display_true_combo,
			cursor_face_velocity = cursor_face_velocity,
			ui_parallax = ui_parallax,
			grid_parallax = grid_parallax,
			fade_length = fade_length,
			show_hit_effect = show_hit_effect,
			lock_mouse = lock_mouse,
			absolute_mode = absolute_mode,
			absolute_scale = absolute_scale,
			cursor_trail = cursor_trail,
			trail_detail = trail_detail,
			trail_time = trail_time,
			friend_position = friend_position,
			show_hp_bar = show_hp_bar,
			show_timer = show_timer,
			show_left_panel = show_left_panel,
			show_right_panel = show_right_panel,
			attach_hp_to_grid = attach_hp_to_grid,
			attach_timer_to_grid = attach_timer_to_grid,
			rainbow_grid = rainbow_grid,
			rainbow_hud = rainbow_hud,
			smart_trail = smart_trail,
			hit_effect_at_cursor = hit_effect_at_cursor,
			show_warnings = show_warnings,
			record_replays = record_replays,
			alt_cam = alt_cam,
			record_mode = record_mode,
			record_limit = record_limit,
			show_accuracy_bar = show_accuracy_bar,
			show_letter_grade = show_letter_grade,
			simple_hud = simple_hud,
			faraway_hud = faraway_hud,
			music_offset = music_offset,
			selected_miss_effect = selected_miss_effect.id,
			show_miss_effect = show_miss_effect,
			auto_maximize = auto_maximize,
			note_visual_approach = note_visual_approach,
			visual_approach_follow = visual_approach_follow,
			score_popup = score_popup,
			billboard_score = billboard_score,
			mirror_buttons = mirror_buttons,
			sfx_2d = sfx_2d,
			cursor_color_type = cursor_color_type,
			half_ghost = half_ghost,
			note_spawn_effect = note_spawn_effect,
			target_fps = Engine.target_fps,
			disable_intro = disable_intro,
			ignore_controller_detection = ignore_controller_detection,
			expand_hud_onhr = expand_hud_onhr,
			last_search_incl_online = last_search_incl_online,
			
			master_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")),-80,1000000)),
			music_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")),-80,1000000)),
			hit_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("HitSound")),-80,1000000)),
			miss_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MissSound")),-80,1000000)),
			fail_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("FailSound")),-80,1000000)),
			pb_volume = ser_float(clamp(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("PBSound")),-80,1000000)),
			
			cursor_color = scol(cursor_color),
			panel_bg = scol(panel_bg),
			panel_text = scol(panel_text),
			unpause_fill_color = scol(unpause_fill_color),
			unpause_empty_color = scol(unpause_empty_color),
			how_to_quit = scol(how_to_quit),
			combo_fill_color = scol(combo_fill_color),
			combo_empty_color = scol(combo_empty_color),
			acc_fill_color = scol(acc_fill_color),
			acc_empty_color = scol(acc_empty_color),
			giveup_text = scol(giveup_text),
			giveup_fill_color = scol(giveup_fill_color),
			giveup_fill_color_end_skip = scol(giveup_fill_color_end_skip),
			timer_text = scol(timer_text),
			timer_text_done = scol(timer_text_done),
			timer_text_canskip = scol(timer_text_canskip),
			timer_fg = scol(timer_fg),
			timer_bg = scol(timer_bg),
			timer_fg_done = scol(timer_fg_done),
			timer_bg_done = scol(timer_bg_done),
			timer_fg_canskip = scol(timer_fg_canskip),
			timer_bg_canskip = scol(timer_bg_canskip),
			miss_flash_color = scol(miss_flash_color),
			pause_used_color = scol(pause_used_color),
			miss_text_color = scol(miss_text_color),
			pause_text_color = scol(pause_text_color),
			score_text_color = scol(score_text_color),
			pause_ui_opacity = pause_ui_opacity,
			grade_ss_saturation = grade_ss_saturation,
			grade_ss_value = grade_ss_value,
			grade_ss_shine = grade_ss_shine,
			grade_s_color = scol(grade_s_color),
			grade_s_shine = grade_s_shine,
			grade_a_color = scol(grade_a_color),
			grade_b_color = scol(grade_b_color),
			grade_c_color = scol(grade_c_color),
			grade_d_color = scol(grade_d_color),
			grade_f_color = scol(grade_f_color),
	  
			edge_drift = ser_float(edge_drift),
			ensure_hitsync = ensure_hitsync,
			retain_song_pitch = retain_song_pitch,
			do_note_pushback = do_note_pushback,
			show_stats = show_stats,
			hit_pitch = hit_pitch,
			hit_pitch_min = hit_pitch_min,
			hit_pitch_max = hit_pitch_max,
			language = language,
			glow = glow,
			bloom = bloom,
			vhs_shader = vhs_shader,
		}
		
		file.store_string(JSON.print(data, "\t"))
		
		file.close()
		return "OK"
	else:
		print("error code %s" % err)




# Built-in content data
func register_colorsets():
	registry_colorset.add_item(ColorSet.new(
		[ Color("#00ffed"), Color("#ff8ff9") ],
		"ssp_cottoncandy", "Cotton Candy", ""
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#ffcc4d"),Color("#ff7892"),Color("#e5dd80") ],
		"ssp_veggiestraws", "Veggie Straws", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#fc94f2"),Color("#96fc94") ],
		"ssp_everybodyvotes", "Everybody Votes Channel", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#fc4441"), Color("#4151fc") ],
		"ssp_redblue", "Red & Blue", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#5BCEFA"),Color("#F5A9B8"),Color("#FFFFFF") ],
		"ssp_pastel", "Pastel", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[
			Color("#e95f5f"), Color("#e88d5f"), Color("#e8ba5f"), Color("#e8e85f"),
			Color("#bae85f"), Color("#8de85f"), Color("#5fe85f"), Color("#5fe88d"),
			Color("#5fe8ba"), Color("#5fe8e8"), Color("#5fbae8"), Color("#5f8de8"),
			Color("#5f5fe8"), Color("#8d5fe8"), Color("#ba5fe8"), Color("#e85fe8"),
			Color("#e85fa4"), Color("#e85f8d"),
		],
		"ssp_hue", "Hue Wheel", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[
			Color("#e95f5f"), Color("#e8765f"), Color("#e88d5f"), Color("#e8a45f"),
			Color("#e8ba5f"), Color("#e8d15f"), Color("#e8e85f"), Color("#d1e85f"),
			Color("#bae85f"), Color("#a4e85f"), Color("#8de85f"), Color("#76e85f"),
			Color("#5fe85f"), Color("#5fe876"), Color("#5fe88d"), Color("#5fe8a4"),
			Color("#5fe8ba"), Color("#5fe8d1"), Color("#5fe8e8"), Color("#5fd1e8"),
			Color("#5fbae8"), Color("#5fa4e8"), Color("#5f8de8"), Color("#5f76e8"),
			Color("#5f5fe8"), Color("#765fe8"), Color("#8d5fe8"), Color("#a45fe8"),
			Color("#ba5fe8"), Color("#d15fe8"), Color("#e85fe8"), Color("#e85fd1"),
			Color("#e85fa4"), Color("#e85f8d"), Color("#e85f8d"), Color("#e85f76"),
		],
		"ssp_hue_ultra", "Hue Wheel Ultra", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#ffffff") ],
		"ssp_soul", "SOUL", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#9a5ef9") ],
		"ssp_purple", "purple!!!", "Chedski"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#000000"), Color("#381e42") ],
		"ssp_vortex", "Vortex", "pyrule"
	))
	registry_colorset.add_item(ColorSet.new(
		[ Color("#008cff"), Color("#ed3434"), Color("#10bd0d"), Color("#ffb300") ],
		"ssp_wii", "Wii Players", "balt"
	))
	
func register_worlds():
	# idI:String,nameI:String,pathI:String,creatorI:String="Unknown"
	registry_world.add_item(BackgroundWorld.new(
		"ssp_space_tunnel", "Neon Corners",
		"res://assets/worlds/neon_tunnel/space_tunnel.tscn", "Chedski",
		"res://assets/worlds/neon_tunnel/space_tunnel.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_neon_tunnel", "Neon Rings",
		"res://assets/worlds/neon_tunnel/neon_tunnel.tscn", "Chedski",
		"res://assets/worlds/neon_tunnel/neon_tunnel.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_deep_space", "Deep Space",
		"res://assets/worlds/deep_space/deep_space.tscn", "Chedski",
		"res://assets/worlds/deep_space/deep_space.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_void", "VOID",
		"res://assets/worlds/void/void.tscn", "Chedski",
		"res://assets/worlds/void/void.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_rainbow_road", "Rainbow Road",
		"res://assets/worlds/space/rainbow_road.tscn", "Chedski",
		"res://assets/worlds/space/rainbow_road.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_cubic", "Cubic",
		"res://assets/worlds/cubic/cubic.tscn", "Chedski",
		"res://assets/worlds/cubic/cubic.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_classic", "Beyond",
		"res://assets/worlds/classic/classic.tscn", "Chedski",
		"res://assets/worlds/classic/classic.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_reality_dismissed", "Reality Dismissed",
		"res://assets/worlds/reality_dismissed/reality_dismissed.tscn", "pyrule",
		"res://assets/worlds/custom/custom.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_reality_dismissed_dark", "Reality Dismissed (Dark)",
		"res://assets/worlds/reality_dismissed/reality_dismissed_dark.tscn", "pyrule",
		"res://assets/worlds/custom/custom.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_baseplate", "Baseplate (Day)",
		"res://assets/worlds/baseplate/baseplate.tscn", "pyrule",
		"res://assets/worlds/baseplate/baseplate.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_baseplate_night", "Baseplate (Night)",
		"res://assets/worlds/baseplate/baseplate_night.tscn", "pyrule",
		"res://assets/worlds/baseplate/baseplate.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_event_horizon", "Event Horizon",
		"res://assets/worlds/event_horizon/event_horizon.tscn", "Chedski",
		"res://assets/worlds/custom/custom.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_vaporwave", "v a p o r w a v e",
		"res://assets/worlds/vaporwave/vaporwave.tscn", "balt",
		"res://assets/worlds/vaporwave/vaporwave.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_tri_tunnel", "Tri-Tunnel",
		"res://assets/worlds/tri_tunnel/tri_tunnel.tscn", "Lexus, pyrule",
		"res://assets/worlds/tri_tunnel/cover.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_grid", "The Grid",
		"res://assets/worlds/grid/grid.tscn", "hi",
		"res://assets/worlds/tri_tunnel/cover.png"
	))
#	registry_world.add_item(BackgroundWorld.new(
#		"ssp_seethrough", "Seethrough",
#		"res://assets/worlds/seethrough.tscn", "pyrule",
#		"res://assets/worlds/covers/void.png"
#	))
	# doesn't work :(
	# registry_world.add_item(BackgroundWorld.new(
	# 	"ssp_security_room", "Security Room",
	# 	"res://assets/worlds/security_room.tscn", "balt",
	# 	"res://assets/worlds/covers/vaporwave.png"
	# ))
	# ----------------------------------------------------
	# Custom content
	registry_world.add_item(BackgroundWorld.new(
		"ssp_custombg", "Custom Background",
		"res://assets/worlds/custom/custombg.tscn", "Someone",
		"res://assets/worlds/custom/custom.png"
	))
	registry_world.add_item(BackgroundWorld.new(
		"ssp_custom", "Modworld",
		"res://assets/worlds/custom/custom.tscn", "Someone",
		"res://assets/worlds/custom/custom.png"
	))

func register_meshes():
	registry_mesh.add_item(NoteMesh.new(
		"ssp_rounded", "Rounded",
		"res://assets/blocks/rounded.obj", "Chedski"
	))
	registry_mesh.add_item(NoteMesh.new(
		"ssp_square", "Square",
		"res://assets/blocks/default.obj", "Chedski"
	))
	registry_mesh.add_item(NoteMesh.new(
		"ssp_circle", "Circle",
		"res://assets/blocks/circle.obj", "Chedski"
	))
	registry_mesh.add_item(NoteMesh.new(
		"ssp_block", "Block",
		"res://assets/blocks/cube.obj", "Chedski"
	))
	registry_mesh.add_item(NoteMesh.new(
		"ssp_plane", "Front of Block",
		"res://assets/blocks/plane.obj", "Chedski"
	))
	registry_mesh.add_item(NoteMesh.new(
		"ssp_realplane", "Plane",
		"res://assets/blocks/quad.tres", "Chedski"
	))
	var dir = Directory.new()
	if dir.open(user_mesh_dir) == OK:
		dir.list_dir_begin(true, false)
		var mesh_name: String = dir.get_next()
		while mesh_name != "":
			if not dir.current_is_dir() and mesh_name.get_extension() == "obj":
				registry_mesh.add_item(NoteMesh.new(
					"ugc_" + mesh_name.get_file().to_lower().replace(" ","_"), 
					mesh_name.get_basename() + " (custom)",
					user_mesh_dir.plus_file(mesh_name), "???"
				))
			mesh_name = dir.get_next()
func register_effects():
	registry_effect.add_item(NoteEffect.new(
		"ssp_ripple", "Ripple* (no color)", "res://assets/notefx/ripple/ripple.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_ripple_n", "Ripple* (note color)", "res://assets/notefx/ripple/ripple.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_ripple_r", "Ripple* (rainbow)", "res://assets/notefx/ripple/ripple.tscn", "Chedski"
	))
	
	registry_effect.add_item(NoteEffect.new(
		"ssp_shards", "Shards (note color)", "res://assets/notefx/shards/shards.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_shards_r", "Shards (rainbow)", "res://assets/notefx/shards/shards.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_shards_w", "Shards (no color)", "res://assets/notefx/shards/shards.tscn", "Chedski"
	))
	
	registry_effect.add_item(NoteEffect.new(
		"ssp_miss", "Miss* (red)", "res://assets/notefx/miss/miss.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_miss_n", "Miss* (note color)", "res://assets/notefx/miss/miss.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_miss_r", "Miss* (rainbow)", "res://assets/notefx/miss/miss.tscn", "Chedski"
	))
	registry_effect.add_item(NoteEffect.new(
		"ssp_miss_w", "Miss* (no color)", "res://assets/notefx/miss/miss.tscn", "Chedski"
	))




# User colorsets
signal colors_done
func load_color_txt(path:String="",id:String=""):
	if path == "" and id == "":
		yield(get_tree(),"idle_frame")
		load_color_folder()
		return
	
	var regex:RegEx = RegEx.new()
	regex.compile("#?([a-zA-Z\\d]{2})([a-zA-Z\\d]{2})([a-zA-Z\\d]{2})([a-zA-Z\\d]{2})?")
	
	var cfname:String = "colors.txt (1 per line)"
	if id != "colorsfile":
		cfname = path.get_file().get_basename()
	var cf:ColorSet 
	
	if registry_colorset.idx_id.has(id):
		cf = registry_colorset.get_item(id)
	else:
		cf = ColorSet.new([],id,cfname," ")
		registry_colorset.add_item(cf)
	
	var file:File = File.new()
	if file.file_exists(Globals.p(path)):
		var err:int = file.open(Globals.p(path),File.READ)
		if err == OK:
			var ctxt:String = file.get_as_text()
			file.close()
			var split:Array = ctxt.split("\n",false)
			var colarr:Array = []
			var mirror = false
			for st in split:
				if st.strip_edges().is_valid_html_color():
					colarr.append(Color(st.strip_edges()))
				elif st.to_lower() == "m":
					mirror = true
			cf.mirror = mirror
			
			if colarr.size() == 0:
				print("no valid colors found")
				colarr = [ Color("#ffffff") ]
			
			cf.colors = colarr
			return
		else: print("couldnt open %s because error %s" % [path,err])
	else: print("no colors.txt")
	cf.colors = [ Color("#ffffff") ]
func load_color_folder():
	var a = OS.get_ticks_usec()
	print("(re)load custom colorsets")
	#load_color_txt("user://colors.txt","colorsfile")
	var dir:Directory = Directory.new()
	if dir.dir_exists(user_colorset_dir):
		var files = Globals.get_files_recursive([user_colorset_dir],5)
		var i = 0
		for n in files.files:
			var b = OS.get_ticks_usec()
			load_color_txt(n,"custom_" + n.get_file().to_lower().md5_text())
			i += 1
			if fmod(i,4) == 0: yield(get_tree(),"idle_frame")
			n = dir.get_next()
			print("set %s took %s usec" % [i,Globals.comma_sep(OS.get_ticks_usec() - b)])
	print("colorsets took %s usec" % [Globals.comma_sep(OS.get_ticks_usec() - a)])
	emit_signal("colors_done")

var single_map_mode:bool = false
var single_map_mode_sspm:bool = false
var single_map_mode_txt:bool = false
var single_map_mode_path:String
var single_map_mode_audio_path:String

# Initialization
func do_init(_ud=null):
	installed_packs = []
	yield(get_tree().create_timer(0.05),"timeout") # haha thread safety go brrrr
	var lp:bool = false # load pause
	var file:File = File.new()
	var dir:Directory = Directory.new()
	
	emit_signal("init_stage_reached","Check arguments")
	yield(get_tree(),"idle_frame")
	
	if Globals.cmdline.has("m"): Globals.cmdline.map = Globals.cmdline.m
	if Globals.cmdline.has("t"): Globals.cmdline.txt = Globals.cmdline.t
	if Globals.cmdline.has("a"): Globals.cmdline.audio = Globals.cmdline.a
	
	if Globals.cmdline.has("map"):
		if Globals.cmdline.has("txt"):
			errorstr = "--txt cannot be used with --map"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		elif Globals.cmdline.has("audio"):
			errorstr = "--audio cannot be used with --map"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		elif Globals.cmdline.map == "" || Globals.cmdline.map.is_valid_filename():
			errorstr = "--map must be a valid path (ie. --map=~/Desktop/map.sspm)"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		else:
			single_map_mode = true
			single_map_mode_sspm = true
			single_map_mode_path = Globals.cmdline.map
			if !file.file_exists(single_map_mode_path):
				errorstr = "--map: file '%s' does not exist" % single_map_mode_path
				get_tree().change_scene("res://scenes/errors/cmdline.tscn")
				return
			
	elif Globals.cmdline.has("txt") || Globals.cmdline.has("audio"):
		if !(Globals.cmdline.has("txt") && Globals.cmdline.has("audio")):
			if Globals.cmdline.has("txt"):
				errorstr = "--txt must be used with --audio"
			else:
				errorstr = "--audio must be used with --txt"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		elif Globals.cmdline.txt == "" || Globals.cmdline.txt.is_valid_filename():
			errorstr = "--txt must be a valid path (ie. --txt=~/Desktop/map.txt)"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		elif Globals.cmdline.audio == "" || Globals.cmdline.txt.is_valid_filename():
			errorstr = "--audio must be a valid path (ie. --txt=~/Desktop/audio.txt)"
			get_tree().change_scene("res://scenes/errors/cmdline.tscn")
			return
		else:
			single_map_mode = true
			single_map_mode_txt = true
			single_map_mode_path = Globals.cmdline.txt
			single_map_mode_audio_path = Globals.cmdline.audio
			
	# Check for updates
	if (OS.has_feature("Windows") or OS.has_feature("X11")) and !OS.has_feature("editor"):
		emit_signal("init_stage_reached","Check for updates")
		emit_signal("init_stage_num",-1)
		yield(get_tree(),"idle_frame")
		Online.check_latest_version()
		var latest_version = yield(Online,"latest_version")
		if ProjectSettings.get_setting("application/config/version") != latest_version:
			var sel = 1
			Globals.confirm_prompt.s_alert.play()
			Globals.confirm_prompt.open("A new version of the game was detected.\n Would you like to automatically update?","Outdated",[{text="Ignore",wait=2},{text="Update",wait=1}])
			sel = yield(Globals.confirm_prompt,"option_selected")
			Globals.confirm_prompt.s_next.play()
			Globals.confirm_prompt.close()
			yield(Globals.confirm_prompt,"done_closing")
			if bool(sel):
				emit_signal("init_stage_reached","Updating the game")
				Online.attempt_update()
				yield(Online,"update_finished")
				get_tree().call_deferred("quit",1)
				OS.execute(OS.get_executable_path(),["--updated"],false)
				return
		elif Globals.cmdline.keys().has("updated"):
			var rdir = Directory.new()
			rdir.open(OS.get_executable_path().get_base_dir())
			if rdir.file_exists("SoundSpacePlus.pck.old"):
				rdir.remove("SoundSpacePlus.pck.old")
			if rdir.file_exists("update.zip"):
				rdir.remove("update.zip")
	
	emit_signal("init_stage_reached","Init filesystem")
	emit_signal("init_stage_num",-1)
	yield(get_tree(),"idle_frame")
	if OS.has_feature("Android"): OS.request_permissions()
	var user_dir = Globals.p("user://")
	if user_dir == "RETRY":
		yield(get_tree().create_timer(7),"timeout")
		user_dir = Globals.p("user://")
	var err:int = dir.open(user_dir)
	#if OS.has_feature("editor"):
	#	yield(get_tree().create_timer(0.35),"timeout")
	if Input.is_key_pressed(KEY_CONTROL) and Input.is_key_pressed(KEY_U):
		err = -1
	
	if err != OK:
		Globals.errornum = err
		get_tree().change_scene("res://scenes/errors/userfolder.tscn")
		return
	
	# Setup directories if they don't already exist
	var convert_pb_format:bool = false
	if !first_init_done:
		if !dir.dir_exists(user_mod_dir): dir.make_dir(user_mod_dir)
		if !dir.dir_exists(user_pack_dir): dir.make_dir(user_pack_dir)
		if !dir.dir_exists(user_vmap_dir): dir.make_dir(user_vmap_dir)
		if !dir.dir_exists(user_map_dir): dir.make_dir(user_map_dir)
		if !dir.dir_exists(user_colorset_dir): dir.make_dir(user_colorset_dir)
		if !dir.dir_exists(user_friend_dir): dir.make_dir(user_friend_dir)
		if !dir.dir_exists(user_mesh_dir): dir.make_dir(user_mesh_dir)
		if !dir.file_exists(user_mesh_dir.plus_file("readme.txt")):
			file.open(user_mesh_dir.plus_file("readme.txt"), File.WRITE)
			file.store_line("The second material is transparent, everything else is opaque.")
			file.store_line("The default blender cube is about the right size for a mesh.")
			file.store_line("In blender, the mesh should face towards the positive Y direction.")
			file.close()
		if !dir.dir_exists(Globals.p("user://replays")): dir.make_dir(Globals.p("user://replays"))
		if !dir.dir_exists(user_best_dir):
			convert_pb_format = true
			dir.make_dir(user_best_dir)
		err = file.open(Globals.p("user://install_path.txt"),File.WRITE)
		if err == OK:
			file.store_string(OS.get_executable_path())
	
	
	
	# set up registries
	emit_signal("init_stage_reached","Init registries")
	if lp: yield(get_tree(),"idle_frame")
	registry_colorset = Registry.new()
	registry_song = Registry.new()
	registry_world = Registry.new()
	registry_mesh = Registry.new()
	registry_effect = Registry.new()
	
	Online.map_registry = registry_song
	
	register_colorsets()
	register_effects()
	register_meshes()
	register_worlds()
	
	# init colors.txt
	emit_signal("init_stage_reached","Load user colorsets")
	emit_signal("init_stage_num",0)
	load_color_txt()
	yield(self,"colors_done")
	
	# Load content
	var mapreg:Array = []
	emit_signal("init_stage_reached","Loading content 1/3\nBuilt-in & DLC")
	yield(get_tree(),"idle_frame")
	if first_init_done:
		mapreg.append(["built-in","res://assets/songs/built_in_maps.sspmr"])
		if installed_dlc.has("ssp_testcontent"): mapreg.append(["test maps","res://test_assets/test_maps.sspmr"])
	else:
		print("loaded ssp_content DLC")
		mapreg.append(["built-in","res://assets/songs/built_in_maps.sspmr"])
		installed_dlc.append("ssp_content")
		if OS.has_feature("editor") or ProjectSettings.load_resource_pack("res://testcontent.pck"):
			print("loaded ssp_testcontent DLC")
			mapreg.append(["test maps","res://test_assets/test_maps.sspmr"])
			installed_dlc.append("ssp_testcontent")
	
	var n
	if !first_init_done: # mods can't be reloaded
		if !OS.has_feature("debug"):
			emit_signal("init_stage_reached","Loading content 2/3\nMods")
			yield(get_tree(),"idle_frame")
			dir.change_dir(user_mod_dir)
			dir.list_dir_begin(true)
			n = dir.get_next()
			while n:
				if ProjectSettings.load_resource_pack(user_mod_dir + "/" + n):
					installed_mods.append(n.get_file().replace(n.get_extension(),""))
				n = dir.get_next()
			dir.list_dir_end()
		else:
			Globals.notify(
				Globals.NOTIFY_INFO,
				"This is a development environment, mods will not be loaded.",
				"Not loading mods"
			)
	emit_signal("init_stage_num",1)
	
	emit_signal("init_stage_reached","Loading content 3/3\nContent packs")
	yield(get_tree(),"idle_frame")
	dir.change_dir(user_pack_dir)
	dir.list_dir_begin(true)
	n = dir.get_next()
	while n:
		installed_packs.append([n.get_file(),user_pack_dir + "/" + n])
		if dir.file_exists(n + "/pack.sspmr"): mapreg.append([n.get_file(),user_pack_dir + "/" + n + "/pack.sspmr"])
		n = dir.get_next()
	dir.list_dir_end()
	
	
	emit_signal("init_stage_reached","Register content")
	yield(get_tree(),"idle_frame")
	var lt:float = OS.get_ticks_msec()
	
	if single_map_mode:
		emit_signal("init_stage_num",2)
		var song:Song = Song.new()
		if single_map_mode_sspm:
			var result = song.load_from_sspm(single_map_mode_path)
			if result != song:
				errorstr = "song load failed with message '%s'" % result
				get_tree().change_scene("res://scenes/errors/cmdline.tscn")
				return
		elif single_map_mode_txt:
			song.id = "__smm"
			song.name = single_map_mode_path.get_file()
			song.song = single_map_mode_audio_path.get_file()
			var result = song.setup_from_file(single_map_mode_path,single_map_mode_audio_path)
			if result != song:
				errorstr = "song load failed with message '%s'" % result
				get_tree().change_scene("res://scenes/errors/cmdline.tscn")
				return
		Rhythia.selected_song = song
	else:
		var cache_version:int = 2
		var caches:Dictionary = {}
		err = file.open(Globals.p("user://map_cache.json"), File.READ)
		if err == OK:
			var res = JSON.parse(file.get_as_text())
			if (res.error != OK):
				print("Error reading cache: %s" % res.error_string)
			elif typeof(res.result) == TYPE_DICTIONARY:
				caches = res.result
				if caches.get("_v", 1) != cache_version:
					caches = {}
					print("Cache version mismatch (got %s expected %s)" % [caches.get("_v",1), cache_version])
			else:
				print("Invalid cache")
		
		var smaps:Array = []
		emit_signal("init_stage_reached","Register content 1/4\nImport Rhythia maps\nLocating files")
		yield(get_tree(),"idle_frame")
		var sd:Array = []
		dir.change_dir(user_map_dir)
		var li = 0
		
		var map_search_folders = [user_map_dir]
		err = file.open(Globals.p("user://map_folders.txt"),File.READ)
		if err == OK:
			var txt = file.get_as_text()
			var list = txt.split("\n",false)
			map_search_folders.append_array(list)
		
		Globals.get_files_recursive(map_search_folders,5,"sspm","",90)
		smaps = yield(Globals,"recurse_result").files
		emit_signal("init_stage_num",2)
		
		var load_start = OS.get_ticks_usec()
		var from_file = 0
		var from_cache = 0
		for i in range(smaps.size()):
			emit_signal("init_stage_reached","Register content 1/5\nImport Rhythia maps\n%.0f%%" % (
				100*(float(i)/float(smaps.size()))
			))
			if (OS.get_ticks_msec() - lt) >= load_target_frame_time * 1000:
				lt = OS.get_ticks_msec()
				yield(get_tree(),"idle_frame")
			#if fmod(i,max(min(floor(float(smaps.size())/200),40),5)) == 0: yield(get_tree(),"idle_frame")
			if caches.has(smaps[i]):
				if registry_song.add_sspm_cached_map(smaps[i], caches.get(smaps[i])):
					from_cache += 1
				else:
					print("Failed loading a map from cache")
					from_file += 1
					registry_song.add_sspm_map(smaps[i])
			else:
				from_file += 1
				registry_song.add_sspm_map(smaps[i])
		var load_end = OS.get_ticks_usec()
		var load_time = load_end - load_start
		print("Loaded %s/%s maps from cache of %s" % [from_cache, from_cache + from_file, caches.size()])
		print("Took %s usec" % Globals.comma_sep(load_time))
	#	dir.list_dir_end()
			
		emit_signal("init_stage_reached","Register content 2/5\nCache Rhythia maps")
		err = file.open(Globals.p("user://map_cache.json"), File.WRITE)
		if err == OK:
			file.store_string(JSON.print(registry_song.make_sspm_cache(cache_version)))
			file.flush()
		
		for i in range(mapreg.size()):
			var amr:Array = mapreg[i]
			emit_signal("init_stage_reached","Register content 3/5\nLoad map registry %d/%d\n%s" % [i,mapreg.size(),amr[0]])
			yield(get_tree(),"idle_frame")
			registry_song.load_registry_file(amr[1],Globals.REGISTRY_MAP,amr[0])
			yield(registry_song,"done_loading_reg")
		
		emit_signal("init_stage_num",3)
		
		var vmaps:Array = []
		
		var vmap_search_folders = [user_vmap_dir]
		err = file.open(Globals.p("user://vmap_folders.txt"),File.READ)
		if err == OK:
			var txt = file.get_as_text()
			var list = txt.split("\n",false)
			vmap_search_folders.append_array(list)
		
		emit_signal("init_stage_reached","Register content 4/5\nImport Vulnus maps\nLocating files")
		yield(get_tree(),"idle_frame")
		
		Globals.get_files_recursive(vmap_search_folders,6,"","meta.json",70)
		vmaps = yield(Globals,"recurse_result").folders
		
		for i in range(vmaps.size()):
			emit_signal("init_stage_reached","Register content 4/5\nImport Vulnus maps\n%.0f%%" % (
				100*(float(i)/float(vmaps.size()))
			))
			if (OS.get_ticks_msec() - lt) >= load_target_frame_time * 1000:
				lt = OS.get_ticks_msec()
				yield(get_tree(),"idle_frame")
			#if fmod(i,floor(float(vmaps.size())/100)) == 0: yield(get_tree(),"idle_frame")
			registry_song.add_vulnus_map(vmaps[i])
		
		
		emit_signal("init_stage_reached","Register content 5/5\nLoad online maps")
		yield(get_tree(),"idle_frame")
		
		Online.load_db_maps()
		yield(Online,"db_maps_done")
	
	emit_signal("init_stage_num",4)
	
	# Default 
	emit_signal("init_stage_reached","Init default assets")
	yield(get_tree(),"idle_frame")
	
	emit_signal("init_stage_reached","Init default assets 1/6")
	if lp: yield(get_tree(),"idle_frame")
	selected_hit_effect = registry_effect.get_item("ssp_ripple")
	selected_miss_effect = registry_effect.get_item("ssp_miss")
	selected_colorset = registry_colorset.get_item("ssp_cottoncandy")
	selected_space = registry_world.get_item("ssp_space_tunnel")
	selected_mesh = registry_mesh.get_item("ssp_rounded")
	
	assert(selected_hit_effect)
	assert(selected_miss_effect)
	assert(selected_colorset)
	assert(selected_space)
	assert(selected_mesh)
	
	emit_signal("init_stage_reached","Init default assets 2/6")
	if lp: yield(get_tree(),"idle_frame")
	def_miss_snd = load("res://assets/sfx/miss.wav")
	
	emit_signal("init_stage_reached","Init default assets 3/6")
	if lp: yield(get_tree(),"idle_frame")
	def_hit_snd = load("res://assets/sfx/hit.wav")
	
	emit_signal("init_stage_reached","Init default assets 4/6")
	if lp: yield(get_tree(),"idle_frame")
	def_fail_snd = load("res://assets/sfx/fail.wav")
	
	emit_signal("init_stage_reached","Init default assets 5/6")
	if lp: yield(get_tree(),"idle_frame")
	def_pb_snd = load("res://assets/sfx/new_best.wav")
	normal_pb_sound = def_pb_snd
	
	emit_signal("init_stage_reached","Init default assets 6/6")
	if lp: yield(get_tree(),"idle_frame")
	def_menu_bgm = load("res://assets/sfx/music/menu_loop.ogg")
	
	# Read settings
	emit_signal("init_stage_reached","Read user settings")
	yield(get_tree(),"idle_frame")
	var result = load_saved_settings()
	if result != 0:
		errornum = result
		# errors are returned when settings are invalid
		get_tree().change_scene("res://scenes/errors/settings.tscn")
		return
	print('settings done')
	if !hlm_converted:
		parallax *= (0.35/0.25)
		ui_parallax *= (0.35/0.25)
		grid_parallax *= (0.35/0.25)
		hlm_converted = true
		save_settings()
	
	# Get custom sounds
	emit_signal("init_stage_reached","Load custom assets")
	yield(get_tree(),"idle_frame")
	
	emit_signal("init_stage_reached","Load asset replacement 1/5\nmiss")
	if lp: yield(get_tree(),"idle_frame")
	miss_snd = get_stream_with_default("user://miss",def_miss_snd)
	
	emit_signal("init_stage_reached","Load asset replacement 2/5\nhit")
	if lp: yield(get_tree(),"idle_frame")
	hit_snd = get_stream_with_default("user://hit",def_hit_snd)
	
	emit_signal("init_stage_reached","Load asset replacement 3/5\nfail")
	if lp: yield(get_tree(),"idle_frame")
	fail_snd = get_stream_with_default("user://fail",def_fail_snd)
	
	emit_signal("init_stage_reached","Load asset replacement 4/5\nnew_best")
	if lp: yield(get_tree(),"idle_frame")
	pb_snd = get_stream_with_default("user://new_best",def_pb_snd)
	
	emit_signal("init_stage_reached","Load asset replacement 5/5\nmenu")
	if lp: yield(get_tree(),"idle_frame")
	menu_bgm = get_stream_with_default("user://menu",def_menu_bgm)
	
	fail_asp.stream = fail_snd
	Globals.error_sound = miss_snd
	
	# Read PB data
	if convert_pb_format:
		hitwindow_ms = 55
		note_hitbox_size = 1.14
		
		emit_signal("init_stage_reached","Upgrading personal best data\nReading legacy data")
		yield(get_tree(),"idle_frame")
		load_pbs()
		
		emit_signal("init_stage_reached","Upgrading personal best data\nPreparing")
		yield(get_tree(),"idle_frame")
		var allmaps:Array = registry_song.get_items()
		
		emit_signal("init_stage_reached","Upgrading personal best data\nConverting data\n0%")
		yield(get_tree(),"idle_frame")
		for i in range(allmaps.size()):
			emit_signal("init_stage_reached","Upgrading personal best data\nConverting data\n%.0f%%" % (
				100*(float(i)/float(allmaps.size()))
			))
			if (OS.get_ticks_msec() - lt) >= load_target_frame_time * 1000:
				lt = OS.get_ticks_msec()
				yield(get_tree(),"idle_frame")
			#if fmod(i,max(min(floor(float(allmaps.size())/200),40),5)) == 0: yield(get_tree(),"idle_frame")
			convert_song_pbs(allmaps[i])
	
	# Load favorite songs
	# Check if VR is available
	if !first_init_done:
		
		# Favorite songs
		emit_signal("init_stage_reached","Read favorite songs")
		yield(get_tree(),"idle_frame")
		if file.file_exists(Globals.p("user://favorites.txt")):
			file.open(Globals.p("user://favorites.txt"),File.READ)
			var txt = file.get_as_text()
			file.close()
			favorite_songs = txt.split("\n",false)
		
		# VR
		emit_signal("init_stage_reached","Check VR status")
		yield(get_tree(),"idle_frame")
		
		var interface = ARVRServer.find_interface("OpenVR")
		if interface:
			vr_interface = interface
			vr_available = true

	dir.change_dir("res://")
	first_init_done = true
	do_archive_convert = false
	
	if Input.is_key_pressed(KEY_A) and Input.is_key_pressed(KEY_R) and Input.is_key_pressed(KEY_C) and Input.is_key_pressed(KEY_W):
		arcw_mode = true
		alert = "ARCW mode enabled successfully."
	if Input.is_key_pressed(KEY_S) and Input.is_key_pressed(KEY_E) and Input.is_key_pressed(KEY_X):
		sex_mode = true
		alert = "Sex mode enabled successfully."
	if Input.is_key_pressed(KEY_D) and Input.is_key_pressed(KEY_Y) and Input.is_key_pressed(KEY_A):
		memory_lane = true
		alert = "Memory Lane enabled successfully."

	var alert_snd_played:bool = false
	if alert != "":
		emit_signal("init_stage_reached","Alert prompt")
		if !alert_snd_played: Globals.confirm_prompt.s_alert.play()
		alert_snd_played = true
		Globals.confirm_prompt.open(alert,"Alert",[{text="OK",wait=2}])
		yield(Globals.confirm_prompt,"option_selected")
		Globals.confirm_prompt.s_next.play()
		Globals.confirm_prompt.close()
		yield(Globals.confirm_prompt,"done_closing")
	if should_ask_about_replays and not OS.has_feature("Android"):
		emit_signal("init_stage_reached","Setup")
		if !alert_snd_played: Globals.confirm_prompt.s_alert.play()
		alert_snd_played = true
		Globals.confirm_prompt.open("Would you like to record replays? This can be changed in settings later.","Replays",[{text="No"},{text="Yes"}])
		var sel = yield(Globals.confirm_prompt,"option_selected")
		record_replays = bool(sel)
		Globals.confirm_prompt.open("Do you favor high quality or low file size replays? This can be changed in settings later.","Replays",[{text="File Size"},{text="Quality"}])
		sel = yield(Globals.confirm_prompt,"option_selected")
		record_limit = sel
		save_settings()
		Globals.confirm_prompt.s_next.play()
		Globals.confirm_prompt.close()
		yield(Globals.confirm_prompt,"done_closing")
	is_init = false
	emit_signal("init_stage_reached","Waiting for menu",true)

extends Node

func idle_status():
	# after 5 min on the menu switch to "listening to music"
	var activity = Discord.Activity.new()
	activity.set_type(Discord.ActivityType.Playing)
	activity.set_details("Main Menu")
	activity.set_state("Listening to music")

	var assets = activity.get_assets()
	assets.set_large_image("icon-bg")
	
	Discord.activity_manager.update_activity(activity)

func _ready():
	get_tree().paused = false
	if Rhythia.arcw_mode:
		get_tree().change_scene("res://w.tscn")
	if Rhythia.sex_mode:
		get_tree().change_scene("res://sex.tscn")
	if Rhythia.memory_lane:
		get_tree().change_scene("res://dya.tscn")
	
	# fix audio pitchshifts
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music")) > 0:
		AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"), 0)
	
	$BlackFade.visible = true
	$BlackFade.color = Color(0, 0, 0, black_fade)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if ProjectSettings.get_setting("application/config/discord_rpc"):
		var activity = Discord.Activity.new()
		activity.set_type(Discord.ActivityType.Playing)
		activity.set_details("Main Menu")
		activity.set_state("Selecting a song")

		var assets = activity.get_assets()
		assets.set_large_image("icon-bg")

		Discord.activity_manager.update_activity(activity)
		
		get_tree().create_timer(300).connect("timeout", self, "idle_status")

var black_fade_target: bool = false
var black_fade: float = 1

func _process(delta):
	if Input.is_action_just_pressed("ui_end") and Input.is_key_pressed(KEY_SHIFT):
		get_tree().change_scene("res://scenes/loaders/menuload.tscn")

	if black_fade_target && black_fade != 1:
		black_fade = min(black_fade + (delta / 0.3), 1)
		$BlackFade.color = Color(0, 0, 0, black_fade)
	elif !black_fade_target && black_fade != 0:
		black_fade = max(black_fade - (delta / 0.5), 0)
		$BlackFade.color = Color(0, 0, 0, black_fade)
	$BlackFade.visible = (black_fade != 0)

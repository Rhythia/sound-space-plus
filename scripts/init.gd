extends Node

var thread:Thread = Thread.new()
var target:String = Rhythia.menu_target
var leaving:bool = false

func stage(text:String,done:bool=false):
	$Label2.text = text
	if done:
#		black_fade_target = true
		$Label2.text = "Loading menu"
		var res = RQueue.queue_resource(target)
		if res != OK:
			Rhythia.errorstr = "queue_resource returned %s" % res
			get_tree().change_scene("res://scenes/errors/menuload.tscn")
#		leaving = true

var black_fade_target:bool = false
var black_fade:float = 0

func _ready():
#	init vr (disabled currently)
#	var VR = ARVRServer.find_interface("OpenVR")
#	if VR and VR.initialize():
#		target = "res://vrmenudemo.tscn"
	
#	VisualServer.set_debug_generate_wireframes(true)
#	get_viewport().debug_draw = get_viewport().DEBUG_DRAW_OVERDRAW
	get_tree().paused = false
	$BlackFade.visible = true
	black_fade = 1
	$BlackFade.color = Color(0,0,0,black_fade)
	Rhythia.connect("init_stage_reached",self,"stage")
	var s = Globals.error_sound
#	var st = Rhythia.get_stream_with_default("user://loadingmusic",s)
#	if st != s:
#		$Music.stream = st
#		$Music.play()
	OS.request_permissions()
	yield(get_tree().create_timer(0.5),"timeout")
	if ProjectSettings.get_setting("application/config/auto_maximize") and Rhythia.auto_maximize: OS.window_maximized = true
	yield(get_tree().create_timer(0.5),"timeout")
#	$AudioStreamPlayer.play()
	
	if(!Socket.connected):
		get_tree().quit()
	
	if not Rhythia.is_init:
		stage("",true)
		return
	elif Rhythia.first_init_done:
		thread.start(Rhythia,"do_init")
	
	Rhythia.is_init = false
	
	if ProjectSettings.get_setting("application/config/discord_rpc"):
		var activity = Discord.Activity.new()
		activity.set_type(Discord.ActivityType.Playing)
		activity.set_details("Initialization")
		
		if Rhythia.do_archive_convert: activity.set_state("Mass-converting songs")
		elif Rhythia.first_init_done: activity.set_state("Reloading content")
		else: activity.set_state("Starting the game")

		var assets = activity.get_assets()
		assets.set_large_image("icon-bg")
		
		Discord.activity_manager.update_activity(activity)

func _exit_tree():
	if thread.is_active():
		thread.wait_to_finish()

var result

func _process(delta):
#	$AudioStreamPlayer.volume_db = -3 - (40*black_fade)
	$Music.volume_db = -8 - (40*black_fade)
	if black_fade_target && black_fade != 1:
		black_fade = min(black_fade + (delta/0.3),1)
		$BlackFade.color = Color(0,0,0,black_fade)
	elif !black_fade_target && black_fade != 0:
		black_fade = max(black_fade - (delta/0.3),0)
		$BlackFade.color = Color(0,0,0,black_fade)
	
	if !leaving:
		if RQueue.is_ready(target):
			result = RQueue.get_resource(target)
			leaving = true
			black_fade_target = true
			if !(result is Object):
				Rhythia.errorstr = "get_resource returned non-object (probably null)"
				get_tree().change_scene("res://scenes/errors/menuload.tscn")
	
	if leaving and result and black_fade == 1:
		get_tree().change_scene_to(result)
	

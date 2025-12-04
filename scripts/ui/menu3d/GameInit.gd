extends Spatial

var active:bool = false

var thread:Thread
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

enum {
	MODE_STARTINIT = 0,
	MODE_MIDINIT = 1,
	MODE_MENU = 2,
}

func activate(mode):
	get_node("../Music").change(true,false,false,false)
	
	print("Showing loading screen in mode %s" % mode)
	
	active = true
	
#	init vr (disabled currently)
#	var VR = ARVRServer.find_interface("OpenVR")
#	if VR and VR.initialize():
#		target = "res://vrmenudemo.tscn"
	
#	VisualServer.set_debug_generate_wireframes(true)
#	get_viewport().debug_draw = get_viewport().DEBUG_DRAW_OVERDRAW
	
	if mode == MODE_STARTINIT or mode == MODE_MIDINIT:
		Rhythia.connect("init_stage_reached",self,"stage")
	
	match mode:
		MODE_STARTINIT:
			thread = Thread.new()
			
			OS.request_permissions()
			yield(get_tree().create_timer(0.5),"timeout")
			if ProjectSettings.get_setting("application/config/auto_maximize") and Rhythia.auto_maximize: OS.window_maximized = true
			yield(get_tree().create_timer(0.5),"timeout")
			
			thread.start(Rhythia,"do_init")
			
		MODE_MENU:
			stage("",true)
		
		_:
			pass
	
	if ProjectSettings.get_setting("application/config/discord_rpc"):
		var activity = Discord.Activity.new()
		activity.set_type(Discord.ActivityType.Playing)
		activity.set_details("Initialization")
		
		if mode == MODE_MENU: activity.set_state("Loading menu")
		elif Rhythia.do_archive_convert: activity.set_state("Mass-converting songs")
		elif Rhythia.first_init_done: activity.set_state("Reloading content")
		else: activity.set_state("Starting the game")

		var assets = activity.get_assets()
		assets.set_large_image("icon")
		
		Discord.activity_manager.update_activity(activity)

func _exit_tree():
	if thread: thread.wait_to_finish()

var result

var logo_target = -2

func set_logo_target(i):
	logo_target = i

onready var logo = [
	$Logo/IconOnly,
	$Logo/S0,
	$Logo/S1,
	$Logo/S2,
	$Logo/S3,
	$Logo/S4,
]

var glow_timer = 0

func _process(delta):
	glow_timer += delta * PI
	if glow_timer > PI:
		glow_timer -= PI
	$LogoSpinner/Glow.opacity = 0.25 + (0.75 * sin(glow_timer))
	var total = 0
#	for i in range(logo.size()):
#		var n:Sprite3D = logo[i]
#		i -= 1
#		if i == logo_target:
#			n.opacity = min(n.opacity + (delta / 0.6), 1)
#		else:
#			n.opacity = max(n.opacity - (delta / 0.6), 0)
#		total += n.opacity
	
	if !leaving:
		
		if Rhythia.init_running and OS.has_feature("debug") and Input.is_action_pressed("debug_devmenu"):
			target = "res://scenes/devmenu.tscn"
		if RQueue.is_ready(target):
			result = RQueue.get_resource(target)
			leaving = true
			get_node("../Music").change(false,false,false,false)
			get_parent().black_fade_target = true
			if !(result is Object):
				Rhythia.errorstr = "get_resource returned non-object (probably null)"
				get_tree().change_scene("res://scenes/errors/menuload.tscn")
	
	if leaving and result and get_parent().black_fade == 1 and get_node("../Music").hv == 0:
		get_tree().change_scene_to(result)

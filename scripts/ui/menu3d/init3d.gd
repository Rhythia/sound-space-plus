extends Node

func _ready():
	set_process(false)
	get_tree().paused = false
	
	# fix audio pitchshifts
	if AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Music")) > 0:
		AudioServer.remove_bus_effect(AudioServer.get_bus_index("Music"),0)
	
	$BlackFade.visible = true
	$BlackFade.color = Color(0,0,0,black_fade)
	
	self.call_deferred("_begin")
	# We defer this because, on startup, Globals will invoke the do_init function
	# and we want to make sure we give it a chance to set init_running

func _begin():
#	active = true
	set_process(true)
	$Controls.set_process(true)
	if Rhythia.init_running:
		print("Init is running, listening for init stage events.")
		$GameInit.activate(1) # MODE_MIDINIT
	elif Rhythia.is_init:
		print("Init is requested, calling do_init and listening for stage events.")
		$GameInit.activate(0) # MODE_STARTINIT
	else:
		print("Init is not running or requested, proceeding to the main menu.")
		$GameInit.activate(2) # MODE_MENU

var black_fade_target:bool = false
var black_fade:float = 1

func _process(delta):
	if black_fade_target && black_fade != 1:
		black_fade = min(black_fade + (delta/0.6),1)
		$BlackFade.color = Color(0,0,0,black_fade)
	elif !black_fade_target && black_fade != 0:
		black_fade = max(black_fade - (delta/0.5),0)
		$BlackFade.color = Color(0,0,0,black_fade)
	$BlackFade.visible = (black_fade != 0)

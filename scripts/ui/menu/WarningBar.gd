extends ColorRect

export var is_devmenu = false

var entry:float = 0
var state:bool = false
var scroll:float = 0

var check:float = 0
var switch:float = -1
var last_color:Color = Color("#ffffff")

var current_warning:String = "none"
var bar_enable:bool = true # Used for controller check bar

func display_warning(id:String):
	match id:
		"none":
			state = false
		"test":
			state = true
			$L.text = "You are holding Alt+Shift+W."
			color = Color("#5cb76e")
		"smm":
			state = true
			$L.text = tr("Running in single map mode. Online features, PBs, and most map actions are disabled.")
			color = Color("#ffbb19")
		"online_excluded":
			state = true
			$L.text = tr("Your account has been excluded. Online features, including score submission, are disabled. See rhythia.com/rules for more information.")
			color = Color("#ff7c19")
		"online_restricted":
			state = true
			$L.text = tr("Your account has been restricted. Scores will not be submitted. See rhythia.com/rules for more information.")
			color = Color("#ffbb19")
		"online_silenced":
			state = true
			$L.text = tr("Your account has been silenced. Chat and comments will be read-only. See rhythia.com/rules for more information.")
			color = Color("#ffbb19")
		"online_nointernet":
			state = true
			$L.text = tr("You are not connected to the internet. Score submission and other online features are unavailable.")
			color = Color("#f2e830")
		"online_outage":
			state = true
			$L.text = tr("Rhythia online services are experiencing an outage. Score submission and other online features are unavailable.")
			color = Color("#f29e30")
		"online_maintenance":
			state = true
			$L.text = tr("Rhythia online services are undergoing maintenance. Score submission and other online features are unavailable.")
			color = Color("#f29e30")
		"online_antitamper":
			state = true
			$L.text = tr("Your game has been modified, or you are using an unapproved build. Score submission is disabled. (Press C to dismiss)")
			color = Color("#fc6d35")
		"online_scoremaintenance":
			state = true
			$L.text = tr("Score submission is currently disabled for maintenance.")
			color = Color("#f29e30")
		"online_loggedout":
			state = true
			$L.text = tr("You are not logged into your Rhythia account.")
			color = Color("#f2e6d7")
		"spawn":
			state = true
			$L.text = tr("Note spawn effects may be buggy.")
			color = Color("#fc794e")
		"debug":
			state = true
			$L.text = tr("Development mode is active, game mods will not be used and scores will not be submitted.")
			color = Color("#477d94")
		"controllercheck":
			state = true
			$L.text = tr("Controller checking disabled. Press C to hide this bar.")
			color = Color("#8400ff")
		"experimental":
			state = true
			$L.text = tr("You are currently using experimental settings. Expect bugs.")
			color = Color("#c1c1ac")
#			color = Color("#dbd1a2")
		"experimental_mod":
			state = true
			$L.text = tr("One or more mods you selected are currently experimental. Expect bugs.")
			color = Color("#77c1d1")
		_:
			assert(false)
	$L2.text = $L.text

var experimental_settings = [
	"show_stats",
	"retain_song_pitch",
]

func check_experimental_settings():
	for k in experimental_settings:
		if Rhythia.get(k): return true
	return false

var test_excluded = false
var test_restricted = false
var test_silenced = false
var online_status = "ok"
# antitamper / loggedout / nointernet / scoremaintenance / maintenance / outage / ok

func check_warnings():
	if Input.is_action_pressed("dismiss_bar") and bar_enable:
		bar_enable = false

	if Input.is_action_pressed("warning_test"):
		return "test"
	elif Rhythia.single_map_mode:
		return "smm"
	elif test_excluded:
		return "online_excluded"
	elif test_restricted:
		return "online_restricted"
	elif test_silenced:
		return "online_silenced"
	elif online_status == "nointernet":
		return "online_nointernet"
	elif online_status == "outage":
		return "online_outage"
	elif online_status == "maintenance":
		return "online_maintenance"
	elif bar_enable and online_status == "antitamper" and !OS.has_feature("debug"):
		return "online_antitamper"
	elif online_status == "scoremaintenance":
		return "online_scoremaintenance"
	elif online_status == "loggedout":
		return "online_loggedout"
	elif Rhythia.note_spawn_effect:
		return "spawn"
	# Temp mark HR as a Experimental due to issues :/
	#elif Rhythia.mod_hardrock:
	#	return "experimental_mod"
	elif OS.has_feature("debug"):
		return "debug"
	elif check_experimental_settings():
		return "experimental"
	elif bar_enable and Rhythia.ignore_controller_detection:
		return "controllercheck"
	else:
		return "none"

func _process(delta):
	var width:float = rect_size.x
	var percent_len:float = 0
	
	if switch != -1:
		if entry == 0:
			switch = max(switch - delta, 0)
		if switch == 0:
			switch = -1
			scroll = clamp(scroll, 0.25, 0.75)
			display_warning(current_warning)
	else:
		check += delta
		if check >= 0.5:
			check -= 0.5
			var prev = current_warning
			current_warning = check_warnings()
			if current_warning != prev:
				switch = 0.35
				state = false
	
	var centerdist = width * abs(
		fmod(scroll + ($L.rect_size.x/2.0/width), 1.0) - 0.5
	)
	
	var centerdist_mod = (6.0 * pow(centerdist/((width-$L.rect_size.x)/1.7), 2.0)) # keep text in the middle for longer
	
	scroll = scroll + (delta * (20.0/1200.0)) * (
		1.5 + (3.0 * float(Input.is_key_pressed(KEY_CONTROL)))
		+ centerdist_mod
	)
	if scroll >= 1.0: scroll -= 1.0
	
	$L.rect_position = Vector2(
		(width * scroll),# - $L.rect_size.x,
		0
	)
	$L2.rect_position = Vector2(
		(width * scroll) - width,# - $L.rect_size.x,
		0
	)
	
	if is_devmenu:
		visible = state
	else:
		if state && entry != 1:
			entry = min(entry + (delta/0.8), 1.0)
			modulate = Color(1.0, 1.0, 1.0, entry)
			margin_top = Dance.InOutSine(entry) * -30
			margin_bottom = (1.0 - Dance.InOutSine(entry)) * 30
			get_parent().get_node("VersionNumber").margin_top = -45 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumber").margin_bottom = -15 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumberB").margin_top = -45 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumberB").margin_bottom = -15 - (Dance.InOutSine(entry)*30)
			
		elif !state && entry != 0:
			entry = max(entry - (delta/0.8), 0.0)
			modulate = Color(1.0, 1.0, 1.0, entry)
			margin_top = Dance.InOutSine(entry) * -30
			margin_bottom = (1.0 - Dance.InOutSine(entry)) * 30
			get_parent().get_node("VersionNumber").margin_top = -45 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumber").margin_bottom = -15 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumberB").margin_top = -45 - (Dance.InOutSine(entry)*30)
			get_parent().get_node("VersionNumberB").margin_bottom = -15 - (Dance.InOutSine(entry)*30)
			
		visible = (entry != 0)

func _ready():
	current_warning = check_warnings()
	display_warning(current_warning)
	if state == true: entry = 0.99

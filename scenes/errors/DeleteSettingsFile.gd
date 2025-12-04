extends Button

var confirming = false
func confirm(v:int):
	if !confirming:
		Globals.confirm_prompt.s_next.play()
		Globals.confirm_prompt.close()
	else:
		confirming = false
		if v == 1:
			Globals.confirm_prompt.s_next.play()
			Globals.confirm_prompt.close()
			var dir:Directory = Directory.new()
			var res:int = dir.remove(Globals.p("user://settings.json"))
			yield(Globals.confirm_prompt,"done_closing")
			if res != OK and res != ERR_FILE_NOT_FOUND:
				Globals.confirm_prompt.open(
					"An error occurred while deleting your settings file. "+
					"Try manually deleting it, and if that doesn't work, "+
					"please ask for help in the Discord server.\n"+
					"https://discord.gg/rhythia"+
					"\n(error code %s)" % res,
					"Error",
					[{text="OK"}]
				)
				return
			else:
				Globals.confirm_prompt.open(
					"Your settings have successfully been reset. The game will now restart.",
					"Success",
					[{text="OK"}]
				)
				yield(Globals.confirm_prompt,"done_closing")
				#get_node("../BlackFade").target = true
				#yield(get_node("../BlackFade"),"done_fading")
				Engine.target_fps = 0
				get_tree().change_scene("res://scenes/init3d.tscn")
				return
		else:
			Globals.confirm_prompt.s_back.play()
			Globals.confirm_prompt.close()

func _pressed():
	confirming = true
	Globals.confirm_prompt.open("Are you sure you want to reset your settings?")

func _ready():
	Globals.confirm_prompt.connect("option_selected",self,"confirm")

extends CheckBox

export(String) var target

func upd():
#	print('scb "%s"' % name)
	pressed = Rhythia.get(target)

func _pressed():
	# var a = OS.get_ticks_usec()
#	print('scb "%s" press' % name)
	if pressed != Rhythia.get(target):
		Rhythia.set(target,pressed)

		if target == "enable_oldmenu":
			Globals.confirm_prompt.open(
				"You must restart for the changes to take effect",
				"Notice",
				[{text="Quit"}]
			)
			Globals.confirm_prompt.s_alert.play()
			var option = yield(Globals.confirm_prompt,"option_selected")
			Globals.confirm_prompt.close()
			Globals.confirm_prompt.s_next.play()
			Rhythia.save_settings()
			get_tree().quit()
#	print('scb "%s" press done, took %s usec' % [name,Globals.comma_sep(OS.get_ticks_usec() - a)])

func _ready():
	upd()

extends MenuButton

var profiles
var file:File

var overwrite_submenu = PopupMenu.new()
var delete_submenu = PopupMenu.new()

func save_profile(path:String):
	if path:
		var saveLoc:File = File.new()
		var err:int = saveLoc.open(path,File.WRITE)
		if err != OK: print("file.open errored - code " + String(err))
		saveLoc.store_string(file.get_as_text())
		saveLoc.close()
		file.close()

		# refresh the profile list
		_ready()

func on_pressed(i):
	if i == profiles.size() + 1: # Create New From Current
		var title = "Enter Profile Name"
		var valid = false
		var response:int = 0
		while !valid and response != 1:
			Globals.string_prompt.open(
				"Input a valid file name for the new profile",
				title,
				"Profile Name",
				[
					{ text = "OK" },
					{ text = "Cancel", wait = 0 }
				]
			)
			title = "Invalid Profile Name"
			Globals.string_prompt.s_alert.play()
			response = yield(Globals.string_prompt,"option_selected")
			Globals.string_prompt.close()
			if response == 0:
				# wait a frame for the prompt to close
				yield(get_tree().create_timer(0.6),"timeout")
				valid = Globals.string_prompt.input.get_text().is_valid_filename()
		
		if response == 0:
			Rhythia.save_settings() # ensure the current settings are saved
			Rhythia.save_settings(Globals.p("user://" + Globals.string_prompt.input.get_text() + ".settings.json"))
		_ready()
		return

	# load the selected profile
	var profile = profiles[i]
	print("Loading profile: " + profile)
	# overwrite Globals.p("user://settings.json") with the selected profile
	# Rhythia.is_switch_profile = true
	get_viewport().get_node("Menu").black_fade_target = true
	yield(get_tree().create_timer(0.35),"timeout")
	get_tree().change_scene("res://scenes/init3d.tscn")
	Rhythia.load_saved_settings(profile)
	Rhythia.save_settings()


func _ready():
	get_popup().clear()
	delete_submenu.clear()
	overwrite_submenu.clear()
	# for every file Globals.p("user://<something>.settings.json") add an item with the name of the file
	profiles = Globals.get_files_recursive([Globals.p("user://")], 1, "json").files # just putting .settings.json here doesn't work :(
	# remove ones that are not settings profiles
	for i in range(profiles.size() - 1, -1, -1): # reverse traversal, prevent bad index
		if profiles[i].find(".settings.json") == -1:
			profiles.remove(i)

	#.substr(profiles[i].find_last("/") + 1, profiles[i].find(".settings.json") - profiles[i].find_last("/") - 1)
	for i in range(profiles.size()):
		var profileName = profiles[i].substr(profiles[i].find_last("/") + 1, profiles[i].find(".settings.json") - profiles[i].find_last("/") - 1)
		get_popup().add_item(profileName, i)
		delete_submenu.add_item(profileName, i)
		overwrite_submenu.add_item(profileName, i)
	
	get_popup().add_separator()
	get_popup().add_item("Create New From Current", -1)
	
	overwrite_submenu.name = "Overwrite"
	delete_submenu.name = "Delete"

	get_popup().call_deferred("add_child", overwrite_submenu)
	get_popup().call_deferred("add_child", delete_submenu)

	overwrite_submenu.connect("id_pressed",self,"overwrite_profile")
	delete_submenu.connect("id_pressed",self,"delete_profile")

	get_popup().add_submenu_item("Overwrite Profile", "Overwrite", -1)
	get_popup().add_submenu_item("Delete Profile", "Delete", -1)
	get_popup().connect("id_pressed",self,"on_pressed")

func overwrite_profile(i):
	var profile = profiles[i]
	print("Overwriting profile: " + profile)
	Rhythia.save_settings(profile)

func delete_profile(i):
	var profile = profiles[i]
	print("Deleting profile: " + profile)
	var userDir = Directory.new()
	userDir.open(Globals.p("user://"))
	var res:int = userDir.remove(profile)
	if res != OK:
		Globals.confirm_prompt.open(
			"An error occurred while deleting your settings file. "+
			"Try manually deleting it, and if that doesn't work, "+
			"please ask for help in the Discord server.\n"+
			"https://discord.gg/rhythia"+
			"\n(error code %s)" % res,
			"Error",
			[{text="OK"}]
		)

	_ready()

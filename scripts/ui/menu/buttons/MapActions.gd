extends MenuButton

var sd = false

var options = []
var target
var current_sel:int
var copy_submenu = PopupMenu.new()
var difficulty_submenu = PopupMenu.new()
#
#func on_pressed(i):
#	Rhythia.set(target,i)
#	get_popup().set_item_checked(current_sel,false)
#	get_popup().set_item_checked(i,true)
#	current_sel = i
#	text = options[i]
#
#
#func _ready():
#	current_sel = Rhythia.get(target)
#	for i in range(options.size()):
#		get_popup().add_check_item(options[i],i)
#		if current_sel == i:
#			get_popup().set_item_checked(i,true)
#			text = options[i]
#	get_popup().connect("id_pressed",self,"on_pressed")
var audio_data:PoolByteArray

func save_song_txt(path:String):
	if path:
		Rhythia.selected_song.export_text(path)

func save_song_audio(path:String):
	if path:
		var file:File = File.new()
		var err:int = file.open(path,File.WRITE)
		if err == OK:
			file.store_buffer(audio_data)
			file.close()
			Globals.notify(Globals.NOTIFY_SUCCEED,"Succesfully saved audio data!","Success")
		else:
			Globals.notify(Globals.NOTIFY_ERROR,"Failed to save file (error code %s)" % err,"Error")

func diff_item_selected(idx:int):
	if !sd:
		disabled = true
		var res = Rhythia.selected_song.change_difficulty(idx - 1)
		if res == OK:
			Globals.notify(Globals.NOTIFY_SUCCEED,"Successfully updated difficulty!","Success")
			Rhythia.emit_signal("favorite_songs_changed") # Force a map list reload
		else:
			Globals.notify(Globals.NOTIFY_ERROR,"Could not update difficulty","Error")
		disabled = false

func copy_item_selected(idx:int):
	match idx:
		0:
			OS.clipboard = Rhythia.selected_song.id
			Globals.notify(Globals.NOTIFY_SUCCEED,"Copied map ID to clipboard.","Copied")
		1:
			if Rhythia.selected_song.songType == Globals.MAP_SSPM or Rhythia.selected_song.songType == Globals.MAP_SSPM2:
				OS.clipboard = Rhythia.selected_song.filePath
				Globals.notify(Globals.NOTIFY_SUCCEED,"Copied map path to clipboard.","Copied")
		2:
			OS.clipboard = Rhythia.selected_song.name
			Globals.notify(Globals.NOTIFY_SUCCEED,"Copied map name to clipboard.","Copied")

func item_selected(idx:int):
	match idx:
		0: # Delete map
			if (
				(Rhythia.selected_song.songType == Globals.MAP_SSPM or
				Rhythia.selected_song.songType == Globals.MAP_SSPM2) and
				!Rhythia.single_map_mode
			):
				Globals.confirm_prompt.open(
					tr("Are you sure you want to delete this map? You might not be able to get it back."),
					tr("Delete Map"),
					[
						{ text = "Cancel" },
						{ text = "OK", wait = 1 }
					]
				)
				Globals.confirm_prompt.s_alert.play()
				var response:int = yield(Globals.confirm_prompt,"option_selected")
				Globals.confirm_prompt.close()
				if response == 1:
					Globals.confirm_prompt.s_next.play()
					Rhythia.selected_song.delete()
				else:
					Globals.confirm_prompt.s_back.play()
		1:
			if !(
				Rhythia.selected_song.is_broken or
				#Rhythia.selected_song.is_builtin or
				Rhythia.selected_song.converted or
				Rhythia.selected_song.songType == Globals.MAP_SSPM2 or
				Rhythia.selected_song.is_online or
				Rhythia.single_map_mode
			):
				var res = Rhythia.selected_song.convert_to_sspm(Rhythia.selected_song.songType == Globals.MAP_SSPM)
				if res == "Converted!":
					if fmod(randf(),1) > 0.97:
						Globals.notify(Globals.NOTIFY_SUCCEED,"Map converted successfully! you have earned one lacuna thumbs up emoji","Converted")
					else:
						Globals.notify(Globals.NOTIFY_SUCCEED,"Map converted successfully!","Converted")
				else:
					Globals.notify(Globals.NOTIFY_ERROR,res,"Failed to convert")
		4:
			Globals.file_sel.save_file(
				self,
				"save_song_txt",
				["*.txt ; Text map data"],
				#"~/Downloads/%s.txt" % [Rhythia.selected_song.id]
				OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s.txt" % [Rhythia.selected_song.id]
			)
		5:
			if !(
				Rhythia.selected_song.is_broken or
				#Rhythia.selected_song.is_builtin or
				Rhythia.selected_song.is_online
			):
				audio_data = Rhythia.selected_song.get_music_buffer()
				var format = Globals.audioLoader.get_format(audio_data)
				if format == "mp3":
					Globals.file_sel.save_file(
						self,
						"save_song_audio",
						["*.mp3 ; mp3 audio file"],
						#"~/Downloads/%s.mp3" % [Rhythia.selected_song.id]
						OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s.mp3" % [Rhythia.selected_song.id]
					)
				elif format == "ogg":
					Globals.file_sel.save_file(
						self,
						"save_song_audio",
						["*.ogg ; ogg audio file"],
						#"~/Downloads/%s.ogg" % [Rhythia.selected_song.id]
						OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS) + "/%s.ogg" % [Rhythia.selected_song.id]
					)
				else:
					Globals.notify(Globals.NOTIFY_ERROR,"Unable to determine audio format","Error")



func upd(_s=null):
	visible = true
	get_popup().set_item_disabled(0,(
		Rhythia.single_map_mode or
		#Rhythia.selected_song.is_builtin or
		Rhythia.selected_song.is_online or !(
			Rhythia.selected_song.songType == Globals.MAP_SSPM or
			Rhythia.selected_song.songType == Globals.MAP_SSPM2
		)
	))
	get_popup().set_item_disabled(1,(
		Rhythia.single_map_mode or
		Rhythia.selected_song.is_broken or
		#Rhythia.selected_song.is_builtin or
		Rhythia.selected_song.converted or
		Rhythia.selected_song.songType == Globals.MAP_SSPM2 or
		Rhythia.selected_song.is_online
	))

	get_popup().set_item_disabled(3,(
		Rhythia.single_map_mode or
		#SP.selected_song.is_builtin or
		Rhythia.selected_song.is_online or !(
			Rhythia.selected_song.songType == Globals.MAP_SSPM or
			Rhythia.selected_song.songType == Globals.MAP_SSPM2
		)
	))

	get_popup().set_item_disabled(5,(
		Rhythia.selected_song.is_broken or
		#Rhythia.selected_song.is_builtin or
		Rhythia.selected_song.is_online
	))

	copy_submenu.set_item_disabled(1,(
		#Rhythia.selected_song.is_builtin or
		Rhythia.selected_song.is_online
	))

	for i in range(6):
		difficulty_submenu.set_item_checked(i,Rhythia.selected_song.difficulty == i - 1)


func _ready():
	visible = false
	get_popup().call_deferred("add_child",copy_submenu)
	get_popup().call_deferred("add_child",difficulty_submenu)
	get_popup().connect("id_pressed",self,"item_selected")
	copy_submenu.connect("id_pressed",self,"copy_item_selected")
	difficulty_submenu.connect("id_pressed",self,"diff_item_selected")

	get_popup().add_item(tr("Delete map"),0)
	get_popup().add_item("Convert to sspm v2",1)
	get_popup().add_submenu_item("Copy...","Copy",2)
	get_popup().add_submenu_item("Set difficulty","Difficulty",3)
	get_popup().add_item("Export .txt map data",4)
	get_popup().add_item("Export audio data",5)

	copy_submenu.add_item("ID",0)
	copy_submenu.add_item("Path",1)
	copy_submenu.add_item("Name",2)

	difficulty_submenu.add_radio_check_item("N/A",0)
	difficulty_submenu.add_radio_check_item("Easy",1)
	difficulty_submenu.add_radio_check_item("Medium",2)
	difficulty_submenu.add_radio_check_item("Hard",3)
	difficulty_submenu.add_radio_check_item("Logic?",4)
	difficulty_submenu.add_radio_check_item("助 (Tasukete)",5)

	if Rhythia.selected_song: upd()
	Rhythia.connect("selected_song_changed",self,"upd")
	yield(get_tree(),"idle_frame")
	copy_submenu.name = "Copy"
	difficulty_submenu.name = "Difficulty"


#func _pressed():
#	set_item_text(0,"None")
#
#func _ready():
#	Rhythia.connect("selected_song_changed",self,"upd")
#	add_item("N/A",0)
#	add_item("Easy",1)
#	add_item("Medium",2)
#	add_item("Hard",3)
#	add_item("Logic?",4)
#	add_item("助",5)
#	connect("item_selected",self,"item_selected")
#	text = "Change Difficulty"

extends Button

func _pressed():
	if (OS.has_feature("Windows") or OS.has_feature("X11")) and !OS.has_feature("editor"):
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
				Globals.notify(0, "Updating...")
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
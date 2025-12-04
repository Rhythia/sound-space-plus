extends Button

var dir:Directory = Directory.new()

var confirm:bool = false

func _pressed():
	
	if dir.file_exists(Globals.p("user://maps/ss_archive_3r2_-_star_rider.sspm")): 
		OS.shell_open(ProjectSettings.globalize_path(Globals.p("user://packs")))
	elif confirm:
		Rhythia.do_archive_convert = true
		get_tree().change_scene("res://scenes/init3d.tscn")
	else:
		confirm = true
		text = "8 GB space required. Continue?"
		disabled = true
		yield(get_tree().create_timer(0.5),"timeout")
		disabled = false

func _ready():
	dir.open(Globals.p("user://packs"))
	if !dir.dir_exists(Globals.p("user://packs/ssarchive")): visible = false
	if dir.file_exists(Globals.p("user://maps/ss_archive_3r2_-_star_rider.sspm")): 
		text = "Delete old ssarchive folder (8 GB)"

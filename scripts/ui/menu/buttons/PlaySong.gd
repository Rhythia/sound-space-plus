extends Button

var has_auto_previewed:bool = false

func _pressed():
	if !Rhythia.selected_song: return
	if !$Song.playing:
		$Song.stream = Rhythia.selected_song.stream()
		$Song.volume_db = -55
		$MenuSong.stop()
		$Song.play($Song.stream.get_length()*0.4)
		$Song.pitch_scale = Globals.speed_multi[Rhythia.mod_speed_level]
		text = "Stop Playing"
	else:
		$Song.stop()
		text = "Play Music"
		if Rhythia.play_menu_music and !$MenuSong.playing:
			$MenuSong.volume_db = -45
			$MenuSong.play()

var song = Rhythia.selected_song

func on_path_press():
	has_auto_previewed = false
	$Song.stop()
	text = "Play Music"
	

func _process(delta):
	var trg = Rhythia.music_volume_db
	if $MenuSong.playing and $MenuSong.volume_db != trg:
		$MenuSong.volume_db = min($MenuSong.volume_db + (delta * 75),trg)

func upd_mm():
	if Rhythia.play_menu_music and !$Song.playing:
		$MenuSong.volume_db = -45
		$MenuSong.play()
	else: $MenuSong.stop()

func upd(s=null):
	if s != song:
		if $Song.playing or (Rhythia.auto_preview_song and !has_auto_previewed):
			if Rhythia.auto_preview_song: has_auto_previewed = true
			$Song.stop()
			$MenuSong.stop()
			$Song.volume_db = -55
			$Song.stream = Rhythia.selected_song.stream()
			if $Song.stream == Globals.error_sound:
				has_auto_previewed = false
				return
			if ($Song.stream is AudioStreamMP3 or $Song.stream is AudioStreamOGGVorbis):
				$Song.stream.loop = true
			$Song.pitch_scale = Globals.speed_multi[Rhythia.mod_speed_level]
#			print(Rhythia.mod_speed_level)
			if $Song.stream: $Song.play($Song.stream.get_length()/3)
			text = "Stop Playing"
		else:
			text = "Play Music"
			if Rhythia.play_menu_music and !$MenuSong.playing:
				$MenuSong.volume_db = -45
				$MenuSong.play()
		song = Rhythia.selected_song

func _ready():
	Rhythia.connect("selected_song_changed",self,"upd")
	Rhythia.connect("speed_mod_changed",self,"upd")
	Rhythia.connect("menu_music_state_changed",self,"upd_mm")
	var menu_music: String = "res://assets/sfx/music/menu_loop.ogg"
	if Rhythia.legacy_music:
		menu_music = "res://assets/sfx/music/OLDmenu_loop.ogg"
	$MenuSong.stream = Rhythia.get_stream_with_default("user://menu",load(menu_music))
	if $MenuSong.stream is AudioStreamSample: $MenuSong.stream.loop_mode = 1
	else: $MenuSong.stream.loop = true
	if Rhythia.play_menu_music:
		yield(get_tree().create_timer(0.5),"timeout")
		if !$Song.playing:
#			$MenuSong.volume_db = -45
			$MenuSong.play()

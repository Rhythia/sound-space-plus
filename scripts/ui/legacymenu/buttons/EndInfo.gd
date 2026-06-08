extends Control

func comma_sep(number):
	var string = str(number)
	var mod = string.length() % 3
	var res = ""

	for i in range(0, string.length()):
		if i != 0 && i % 3 == mod:
			res += ","
		res += string[i]

	return res

func hide_info(_s=null):
	visible = false

func get_time_ms(ms:float):
	var s = max(floor(ms / 1000),0)
	var m = floor(s / 60)
	var rs = fmod(s,60)
	return "%d:%02d" % [m,rs]

var rainbow_letter_grade:bool = false
func update_letter_grade(acc:float=0):
	var grade:String = "--"
	var gcol:Color = Color(1,0,1)
	var shine:float = 0
	rainbow_letter_grade = (acc == 1)
	if acc == 1:
		grade = "SS"
		gcol = Color.from_hsv(Rhythia.rainbow_t*0.1,0.5,1)
	elif acc >= 0.98:
		grade = "S"
		gcol = Color("#91fffa")
	elif acc >= 0.95:
		grade = "A"
		gcol = Color("#91ff92")
	elif acc >= 0.90:
		grade = "B"
		gcol = Color("#e7ffc0")
	elif acc >= 0.85:
		grade = "C"
		gcol = Color("#fcf7b3")
	elif acc >= 0.80:
		grade = "D"
		gcol = Color("#fcd0b3")
	else:
		grade = "F"
		gcol = Color("#ff8282")

	$LetterGrade.text = grade
	$LetterGrade.material.set_shader_param("shine",shine)
	$LetterGrade.set("custom_colors/font_color",gcol)

func _process(delta):
	if rainbow_letter_grade:
		$LetterGrade.set("custom_colors/font_color",Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1))

func show_pb(_s=null):
	if Rhythia.selected_song != null:
		var pb = Rhythia.get_best()
		if pb:
			visible = true
			var misses = pb.total_notes - pb.hit_notes
			if pb.has_passed:
				$Result.text = "Personal Best"
				$Result.set("custom_colors/font_color",Color("#6ff1ff"))
			else:
				$Result.text = "Best Attempt"
				$Result.set("custom_colors/font_color",Color("#ea4aca"))

			$FullCombo.visible = misses == 0 && pb.has_passed
			$Misses.visible = !misses == 0 || !pb.has_passed
			$Misses.text = comma_sep(misses)

			$NoPauses.visible = pb.pauses == 0
			$Pauses.visible = !pb.pauses == 0
			$Pauses.text = comma_sep(pb.pauses)

			$Accuracy.text = "%s/%s\n%.03f%%" % [
				comma_sep(pb.hit_notes),
				comma_sep(pb.total_notes),
				(float(pb.hit_notes)/float(pb.total_notes))*100
			]

			if pb.max_combo < 0:
				$MaxCombo.text = "?"
			else:
				$MaxCombo.text = comma_sep(pb.max_combo)
			$MaxCombo.text += "\n"

			update_letter_grade(float(pb.hit_notes)/float(pb.total_notes))
			$Progress.text = "%s\n%.2f%%" % [get_time_ms(pb.position),clamp(pb.position/Rhythia.selected_song.last_ms,0,1)*100]
		else:
			visible = true
			$Result.text = "No PB"
			$LetterGrade.text = "-"
			rainbow_letter_grade = false
			$LetterGrade.set("custom_colors/font_color",Color(1,1,1))
			$LetterGrade.material.set_shader_param("shine",0)
			$Result.set("custom_colors/font_color",Color("#ffdd99"))
			$FullCombo.visible = false
			$Misses.visible = true
			$Misses.text = "-"
			$NoPauses.visible = false
			$Pauses.visible = true
			$Pauses.text = "-"
			$Accuracy.text = "-\n"
			$Progress.text = "-\n"
			$MaxCombo.text = "-\n"

func _ready():
	Rhythia.connect("selected_song_changed",self,"show_pb")
	Rhythia.connect("mods_changed",self,"show_pb")
	yield(Rhythia,"map_list_ready")
	if !Rhythia.selected_song: return
	$NewBest.stream = Rhythia.pb_snd
	if $NewBest.stream != Rhythia.normal_pb_sound:
		$NewBest.pitch_scale = 1
	visible = Rhythia.just_ended_song
	if Rhythia.just_ended_song:
		var is_best:bool = Rhythia.do_pb_check_and_set()
		if is_best: $NewBest.play()
		if Rhythia.song_end_type == Globals.END_PASS:
			if Rhythia.was_replay: $Result.text = "Replay passed"
			elif is_best: $Result.text = "New best!"
			else: $Result.text = "You passed!"
			$Result.set("custom_colors/font_color",Color("#6ff1ff"))
		elif Rhythia.was_replay: $Result.text = "Replay failed"
		elif is_best:
			$Result.text = "You failed (new best!)"
			$Result.set("custom_colors/font_color",Color("#ea4aca"))
		else: $Result.text = "You failed!"


		$FullCombo.visible = Rhythia.song_end_misses == 0 && Rhythia.song_end_type == Globals.END_PASS
		$Misses.visible = !Rhythia.song_end_misses == 0 || !Rhythia.song_end_type == Globals.END_PASS
		$Misses.text = comma_sep(Rhythia.song_end_misses)

		$NoPauses.visible = Rhythia.song_end_pause_count == 0
		$Pauses.visible = !Rhythia.song_end_pause_count == 0
		$Pauses.text = comma_sep(Rhythia.song_end_pause_count)

		$Accuracy.text = "%s/%s\n%.03f%%" % [
			comma_sep(Rhythia.song_end_hits),
			comma_sep(Rhythia.song_end_total_notes),
			(float(Rhythia.song_end_hits)/float(Rhythia.song_end_total_notes))*100
		]


		if Rhythia.song_end_combo < Rhythia.selected_song.note_count:
			$MaxCombo.text = comma_sep(Rhythia.song_end_combo)
		elif Rhythia.song_end_combo == Rhythia.selected_song.note_count:
			$MaxCombo.text = "FULL COMBO"
		else:
			$MaxCombo.text = "NO COMBO"
		$MaxCombo.text += "\n"

		update_letter_grade(float(Rhythia.song_end_hits)/float(Rhythia.song_end_total_notes))
		$Progress.text = "%s\n%.1f%%" % [Rhythia.song_end_time_str,clamp(Rhythia.song_end_position/Rhythia.song_end_length,0,1)*100]
	else:
		show_pb()
	Rhythia.just_ended_song = false

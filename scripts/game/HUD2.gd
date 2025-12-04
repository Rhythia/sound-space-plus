extends Spatial


onready var Game:SongPlayerManager = get_parent()
onready var Spawn:NoteManager = get_parent().get_node("Spawn")


onready var timebar:ProgressBar = get_node("GridVP/Control/Timer/Time")
onready var timelabel:Label = get_node("GridVP/Control/Timer/Label")
onready var songnametxt:Label = get_node("GridVP/Control/Timer/SongName")
onready var songnametxt2:Label = get_node("Info/C/MapName/L")
onready var mappertxt:Label = get_node("Info/C/Mapper/H/L")
onready var mappertitle:Label = get_node("Info/C/Mapper/H/T")
onready var acclabel:Label = get_node("LeftVP/Control/Accuracy")
onready var accbar:ProgressBar = get_node("LeftVP/Control/AccuracyBar")
onready var pauselabel:Label = get_node("LeftVP/Control/Pauses")
onready var noteslabel:Label = get_node("RightVP/Control/Notes")
onready var misseslabel:Label = get_node("RightVP/Control/Misses")
onready var scorelabel:Label = get_node("RightVP/Control/Score")
onready var energybar:ProgressBar = get_node("GridVP/Control/Energy/Energy")
onready var modicons:HBoxContainer = get_node("GridVP/Control/Energy/Modifiers/Icons/H")
onready var modtxt:Label = get_node("GridVP/Control/Energy/Modifiers/Text")
onready var modholder:VBoxContainer = get_node("GridVP/Control/Energy/Modifiers")
onready var infoholder:HBoxContainer = get_node("Info")

onready var comboring:Control = get_node("LeftVP/Control/Combo")
onready var combotxt:Label = get_node("LeftVP/Control/Combo/Label")
onready var truecombo:Label = get_node("ComboVP/Value")

onready var lettergrade:Label = get_node("LeftVP/Control/LetterGrade")

onready var friend:MeshInstance = Spawn.get_node("Friend")
onready var gridborder:Spatial = get_node("Grid")
onready var gridvp:Viewport = get_node("GridVP")
onready var gridmat:SpatialMaterial = get_node("Grid/Outer").get_surface_material(0)
onready var gridsides:Control = get_node("GridVP/Control/Sides")
onready var gridcorners:Control = get_node("GridVP/Control/Corners")

onready var cur_pos = $"../Spawn/Cursor/Mesh".global_transform.origin
onready var pcur_pos = cur_pos




var panel_bg:Color = Rhythia.panel_bg
var panel_text:Color = Rhythia.panel_text

var unpause_fill_color:Color = Rhythia.unpause_fill_color
var unpause_empty_color:Color = Rhythia.unpause_empty_color
var how_to_quit:Color = Rhythia.how_to_quit

var combo_fill_color:Color = Rhythia.combo_fill_color
var combo_empty_color:Color = Rhythia.combo_empty_color

var acc_fill_color:Color = Rhythia.acc_fill_color
var acc_empty_color:Color = Rhythia.acc_empty_color

var giveup_text:Color = Rhythia.giveup_text
var giveup_fill_color:Color = Rhythia.giveup_fill_color
var giveup_fill_color_end_skip:Color = Rhythia.giveup_fill_color_end_skip

var timer_text:Color = Rhythia.timer_text
var timer_text_done:Color = Rhythia.timer_text_done
var timer_text_canskip:Color = Rhythia.timer_text_canskip

var timer_fg:Color = Rhythia.timer_fg
var timer_bg:Color = Rhythia.timer_bg
var timer_fg_done:Color = Rhythia.timer_fg_done
var timer_bg_done:Color = Rhythia.timer_bg_done
var timer_fg_canskip:Color = Rhythia.timer_fg_canskip
var timer_bg_canskip:Color = Rhythia.timer_bg_canskip

var energy_fg:Color = Rhythia.energy_fg
var energy_bg:Color = Rhythia.energy_bg
var energy_failed:Color = Rhythia.energy_failed
var energy_failed_flash:Color = Rhythia.energy_failed_flash

var miss_flash_color:Color = Rhythia.miss_flash_color
var pause_used_color:Color = Rhythia.pause_used_color

var miss_text_color:Color = Rhythia.miss_text_color
var pause_text_color:Color = Rhythia.pause_text_color
var score_text_color:Color = Rhythia.score_text_color

var pause_ui_opacity:float = Rhythia.pause_ui_opacity

var grade_ss_saturation:float = Rhythia.grade_ss_saturation
var grade_ss_value:float = Rhythia.grade_ss_value
var grade_ss_shine:float = Rhythia.grade_ss_shine

var grade_s_color:Color = Rhythia.grade_s_color
var grade_s_shine:float = Rhythia.grade_s_shine

var grade_a_color:Color = Rhythia.grade_a_color
var grade_b_color:Color = Rhythia.grade_b_color
var grade_c_color:Color = Rhythia.grade_c_color
var grade_d_color:Color = Rhythia.grade_d_color
var grade_f_color:Color = Rhythia.grade_f_color



var last_combo:int = 0
var is_full_combo:bool = false
var full_combo_indicator_t:float = 1.0



var elapsed:float = 0
var gtimer:float = 0 # global delta timer
var s_curspd:float = 0
var s_tcurspd:float = 0
var calculating:bool = false


func set_song_name(name:String=Rhythia.selected_song.name):
	songnametxt.text = name
	songnametxt2.text = name

func song_end(end_type:int):
	if end_type == Globals.END_GIVEUP and Rhythia.record_replays and !Rhythia.replaying:
		Rhythia.replay.store_sig(Spawn.rms,Globals.RS_GIVEUP)
	if end_type != Globals.END_PASS:
		friend.failed = true
		Rhythia.fail_asp.play()
	friend.upd()

var combo_ring_target:float = 0
var combo_ring_value:float = 0

func update_static_values():

	if Game.hits == Game.total_notes: acclabel.text = "100%"
	elif Game.hits == 0: acclabel.text = "0%"
	else: acclabel.text = "%.3f%%" % ((Game.hits/Game.total_notes)*100)
	Rhythia.song_end_accuracy_str = acclabel.text
	if not Game.total_notes == 0:
		accbar.value = Game.hits/Game.total_notes
	noteslabel.text = "%s/%s" % [Globals.comma_sep(Game.hits),Globals.comma_sep(Game.total_notes)]
	misseslabel.text = "%s" % Globals.comma_sep(Game.misses)
	energybar.max_value = Game.max_energy
	energybar.value = Game.energy
	combotxt.text = String(Game.combo_level) + "x"
	combo_ring_target = float(Game.lvl_progress) / 10.0
	
	if Game.combo != last_combo:
		truecombo.text = String(Game.combo)
		truecombo.rect_position.y = 100
		last_combo = Game.combo
	
	pauselabel.text = Globals.comma_sep(Rhythia.song_end_pause_count)
	
	for n in get_tree().get_nodes_in_group("pause_text"):
		paint(
			n,
			pause_text_color if (Rhythia.song_end_pause_count == 0)
			else pause_used_color
		)
	
	scorelabel.text = Globals.comma_sep(Game.score)
	
	
	var grade:String = "--"
	var gcol:Color = Color(1,0,1)
	var shine:float = 0
	var acc = 1
	if not Game.total_notes == 0:
		acc = Game.hits/Game.total_notes
	is_full_combo = (acc == 1)
	if acc == 1:
		grade = "SS"
		gcol = Color.from_hsv(Rhythia.rainbow_t*0.1, grade_ss_saturation, grade_ss_value)
		shine = grade_ss_shine
	elif acc >= 0.98:
		grade = "S"
		gcol = grade_s_color
		shine = grade_s_shine
	elif acc >= 0.95:
		grade = "A"
		gcol = grade_a_color
	elif acc >= 0.90:
		grade = "B"
		gcol = grade_b_color
	elif acc >= 0.85:
		grade = "C"
		gcol = grade_c_color
	elif acc >= 0.80:
		grade = "D"
		gcol = grade_d_color
	else:
		grade = "F"
		gcol = grade_f_color
	
	lettergrade.text = grade
	if shine != lettergrade.material.get_shader_param("amount"):
		lettergrade.material.set_shader_param("amount",shine)
	
	if !Rhythia.rainbow_hud:
		lettergrade.set("custom_colors/font_color",gcol)

var miss_flash:float = 0
var hit_flash:float = 1
var hit_color:Color = Color("#ffffff")
var fail_flash:float = 0


func dry_get_next():
	if Rhythia.song_end_type == Globals.END_GIVEUP or Rhythia.queue_pos + 1 == Rhythia.song_queue.size():
		return null
	
	return Rhythia.song_queue[Rhythia.queue_pos + 1]

var info_fade:float = 1
var info_target:bool = true
func update_timer(ms:float,canSkip:bool=false):
	var qms = ms + Spawn.ms_offset
	var lms = Game.last_ms
	
	if Rhythia.queue_active:
		lms = Rhythia.queue_end_length + (3000 * (Rhythia.song_queue.size() - 1))
	
	var s = clamp(floor(qms/1000),0,lms/1000)
	var m = floor(s / 60)
	var rs = fmod(s,60)
	
	var ls = floor(lms/1000)
	var lm = floor(ls / 60)
	var lrs = fmod(ls,60)
	
	if !Rhythia.rainbow_hud:
		if canSkip:
			timebar.get("custom_styles/fg").bg_color = timer_fg_canskip
			timebar.get("custom_styles/bg").bg_color = timer_bg_canskip
			for n in get_tree().get_nodes_in_group("timer_text"):
				paint(n,timer_text_canskip)
			
		elif !Rhythia.queue_active and Spawn.ms > Game.last_ms:
			timebar.get("custom_styles/fg").bg_color = timer_fg_done
			timebar.get("custom_styles/bg").bg_color = timer_bg_done
			for n in get_tree().get_nodes_in_group("timer_text"):
				paint(n,timer_text_done)
			
		else:
			timebar.get("custom_styles/fg").bg_color = timer_fg
			timebar.get("custom_styles/bg").bg_color = timer_bg
			for n in get_tree().get_nodes_in_group("timer_text"):
				paint(n,timer_text)
	
	timebar.value = clamp(qms/lms,0,1)
	if canSkip: timelabel.text = tr("PRESS SPACE TO SKIP")
	elif canSkip and OS.has_feature("Android"): timelabel.text = tr("TAP TO SKIP")
	else: timelabel.text = "%d:%02d / %d:%02d" % [m,rs,lm,lrs]
	Rhythia.song_end_time_str = "%d:%02d" % [m,rs]

	
	if Rhythia.queue_active:
		if ms >= Game.last_ms + Rhythia.hitwindow_ms:
#			songnametxt.text = "(Intermission)"
			var next = dry_get_next()
			if next:
				info_target = true
				songnametxt.text = next.name
				songnametxt2.text = next.name
				mappertitle.text = "Mapped by "
				mappertxt.text = next.creator
#				mappertitle.text = "Next song:"
#				mappertxt.text = next.name
			else:
				info_target = false#Input.is_key_pressed(KEY_S)
		else:
			songnametxt.text = Rhythia.selected_song.name
			songnametxt2.text = Rhythia.selected_song.name
			mappertitle.text = "Mapped by "
			mappertxt.text = Rhythia.selected_song.creator
			if ms <= Rhythia.start_offset - 1000:
				info_target = true
			else:
				info_target = false#Input.is_key_pressed(KEY_S)
	else:
		if ms <= (Rhythia.start_offset - 1000):
			info_target = true
		else:
			info_target = false#Input.is_key_pressed(KEY_S)



func on_miss(color:Color):
	miss_flash = 1

func on_hit(color:Color):
	hit_flash = 1
	hit_color = color
	if !Rhythia.rainbow_grid:
		paint(gridcorners,hit_color)
		paint(gridsides, hit_color)

func paint(node:Control,color:Color):
	if node is ColorRect:
		node.color = color
	
	elif node is Panel:
		node.get("custom_styles/panel").bg_color = color
	
	elif node is Label:
		if node.has_color_override("font_color"):
			node.set("custom_colors/font_color",color)
		else:
			node.modulate = color
	
	else:
		node.modulate = color

var config_time:float = 2.5

func on_fail():
	fail_flash = 1

func _process(delta:float):
	gtimer += delta
	if Rhythia.show_config:
		config_time = max(config_time-delta,0)
		if config_time <= 0: $ConfigHud.visible = false
		else: $ConfigHud.opacity = min(1,config_time)
	
	if combo_ring_value > combo_ring_target:
		combo_ring_value = max(combo_ring_value + (
			((combo_ring_target - combo_ring_value) * delta * 6)
		), combo_ring_target)
	elif combo_ring_value < combo_ring_target:
		combo_ring_value = min(combo_ring_value + (
			((combo_ring_target - combo_ring_value) * delta * 6)
		), combo_ring_target)
	
	if comboring.percent != combo_ring_value:
		comboring._set_percent(combo_ring_value)
	
	if Input.is_action_pressed("give_up"):
		get_node("GiveUpHud").visible = true
		get_node("GiveUpVP/Control/Label").visible = !$PauseHud.visible
		if Spawn.ms > Game.last_ms:
			get_node("GiveUpVP/Control/Label").text = "Skipping..."
			get_node("GiveUpVP/Control").fill_color = giveup_fill_color_end_skip
			
		get_node("GiveUpVP/Control").percent = Game.giving_up
		get_node("GiveUpHud").opacity = min(Game.giving_up*2,1)
	else:
		get_node("GiveUpHud").visible = false
		get_node("GiveUpHud").opacity = 0
	
	if not is_full_combo:
		full_combo_indicator_t = max(full_combo_indicator_t - (delta / 0.35), 0.0)
	else:
		full_combo_indicator_t = 1.0
	
	if Rhythia.show_full_combo_indicators:# and Game.total_notes != 0:
		var fc_indicator_t_curved = ease(full_combo_indicator_t,0.25)
		var lettergrade_rainbow = Color.from_hsv(Rhythia.rainbow_t*0.1, grade_ss_saturation, grade_ss_value)
		var combo_rainbow = Color.from_hsv(Rhythia.rainbow_t*0.1, 0.75, 1.0, 0.5)
		$ComboVP/Value.material.set_shader_param("amount",fc_indicator_t_curved)
		$ComboVP/Value.set("custom_colors/font_color",lerp(Color(1.0,1.0,1.0,0.19),combo_rainbow,fc_indicator_t_curved))
		lettergrade.get_node("FullComboIndicator").anchor_top = lerp(0.5,0.0,fc_indicator_t_curved)
		lettergrade.get_node("FullComboIndicator").anchor_bottom = lerp(0.5,1.0,fc_indicator_t_curved)
		lettergrade.get_node("FullComboIndicator").visible = fc_indicator_t_curved > 0
		#lettergrade.get_node("FullComboIndicator").material.set_shader_param("amount",fc_indicator_t_curved)
		lettergrade.self_modulate = lerp(Color.white, Color.black, fc_indicator_t_curved)
		$ComboHud.scale = lerp(Vector3.ONE, Vector3(1.25,1.25,1.25), fc_indicator_t_curved)
		if !Rhythia.rainbow_hud:
			lettergrade.get_node("FullComboIndicator").color = lettergrade_rainbow
	elif is_full_combo and !Rhythia.rainbow_hud:
		lettergrade.set("custom_colors/font_color",Color.from_hsv(Rhythia.rainbow_t*0.1, grade_ss_saturation, grade_ss_value))
	
	if miss_flash != 0:
		miss_flash = max(0, miss_flash - (delta * 3))
		var miss_col = lerp(miss_text_color, miss_flash_color, miss_flash)
		for n in get_tree().get_nodes_in_group("miss_text"):
			paint(n, miss_col)
	
	if hit_flash != 0:
		hit_flash = max(0, hit_flash - (delta * 1.5))
		var hit_col = lerp(Color(hit_color.r,hit_color.g,hit_color.b,0), hit_color, min(hit_flash/0.5, 1))
		paint(gridsides, hit_col)
	
	if Game.song_has_failed:
		fail_flash = max(fail_flash - (delta / 0.5), 0.0)
		var fail_flash_curved = ease(fail_flash, 4)
		energybar.get("custom_styles/fg").bg_color = Color(0.0,0.0,0.0,0.0)
		energybar.get("custom_styles/bg").bg_color = lerp(energy_failed, energy_failed_flash, fail_flash_curved)
		energybar.get_node("Failed").visible = true
		energybar.get_node("Failed").modulate = lerp(Color(1.0,0.4,0.4,0.8), Color(1.0,0.0,0.0), fail_flash_curved)
		if Rhythia.attach_hp_to_grid: # unfortunately this gets cut off when using detached HP
			energybar.get_node("Failed").rect_scale = lerp(Vector2.ONE, Vector2(6.0,6.0), fail_flash_curved)
	elif Rhythia.rainbow_hud:
		energybar.get("custom_styles/fg").bg_color = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1)
		energybar.get("custom_styles/bg").bg_color = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,0.2,0.65)
	
	# yes these do need to be separate
	if Rhythia.rainbow_hud:
		$TimerHud.modulate = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1)
		$ComboHud.modulate = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1)
		$LeftHud.modulate = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1)
		$RightHud.modulate = Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1)
	if Rhythia.rainbow_grid:
		paint(gridcorners, Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1))
		paint(gridsides, Color.from_hsv(Rhythia.rainbow_t*0.1,0.4,1,min(hit_flash/0.5, 1)))
	
	if info_target && info_fade != 1:
		info_fade = min(info_fade + (delta),1)
		infoholder.modulate = Color(1,1,1,info_fade)
	elif !info_target && info_fade != 0:
		info_fade = max(info_fade - (delta),0)
		infoholder.modulate = Color(1,1,1,info_fade)
	infoholder.visible = (info_fade != 0)
	
	
	
	if Spawn.pause_state != 0:
		$PauseHud.visible = !Input.is_key_pressed(KEY_C)
		$PauseVP/Control.percent = clamp(
			1 - (Spawn.pause_state),
			0,
			float(Spawn.pause_state != -1)
		)
		$PauseHud.modulate = Color(1,1,1,abs(Spawn.pause_state) * pause_ui_opacity)
	else:
		$PauseHud.visible = false
	
	# stat mod
	elapsed += delta
	if elapsed >= 0.1 and calculating:
		pcur_pos = cur_pos
		cur_pos = $"../Spawn/Cursor/Mesh".global_transform.origin
		var dist = cur_pos.distance_to(pcur_pos)
		s_curspd = dist / elapsed
		if s_curspd > s_tcurspd:
			s_tcurspd = s_curspd
		elapsed = 0
	if gtimer >= 2:
		calculating = true
	
	var fstr = "cursor speed\n{current} m/sec/{frames}fr\n\ntop speed\n{top} m/sec/{frames}fr\n\nrec interval\n{rec}"
	$Stats/Label.text = fstr.format(
		{
			"current": stepify(s_curspd,0.1),
			"frames": Engine.get_frames_per_second(),
			"top": stepify(s_tcurspd,0.1),
			"rec": round(Spawn.rec_interval)
		}
	)
	



func _ready():
	$Grid.translation = Vector3.ZERO
	Game.connect("miss",self,"on_miss")
	Game.connect("hit",self,"on_hit")
	Game.connect("failed",self,"on_fail")
	$Stats/Label.visible = Rhythia.show_stats
	
	$GiveUpVP/Control.fill_color = giveup_fill_color
	
	if !Rhythia.rainbow_hud:
		for n in get_tree().get_nodes_in_group("panel_bg"):
			paint(n,panel_bg)
		
		for n in get_tree().get_nodes_in_group("panel_text"):
			paint(n,panel_text)
		
		for n in get_tree().get_nodes_in_group("score_text"):
			paint(n,score_text_color)
		
		for n in get_tree().get_nodes_in_group("pause_text"):
			paint(n, pause_text_color)
		
		for n in get_tree().get_nodes_in_group("miss_text"):
			paint(n, miss_text_color)
	
	if !Rhythia.enable_border:
		$GridVP/Control/Sides.visible = false
		$GridVP/Control/Corners.visible = false
	
	paint($PauseVP/Control/Paused,unpause_empty_color)
	paint($PauseVP/Control/ProgressBar/Paused,unpause_fill_color)
	paint($PauseVP/Control/HoldR,how_to_quit)
	paint($GiveUpVP/Control/Label,giveup_text)
	
	if Rhythia.rainbow_hud:
		var cf = max(max(combo_fill_color.r,combo_fill_color.g),combo_fill_color.b)
		var ce = max(max(combo_empty_color.r,combo_empty_color.g),combo_empty_color.b)
		var af = max(max(acc_fill_color.r,acc_fill_color.g),acc_fill_color.b)
		var ae = max(max(acc_empty_color.r,acc_empty_color.g),acc_empty_color.b)
		
		comboring.fill_color = Color(cf,cf,cf,combo_fill_color.a)
		comboring.empty_color = Color(ce,ce,ce,combo_empty_color.a)
		accbar.get("custom_styles/fg").bg_color = Color(af,af,af,acc_fill_color.a)
		accbar.get("custom_styles/bg").bg_color = Color(ae,ae,ae,acc_empty_color.a)
		
	else:
		comboring.fill_color = combo_fill_color
		comboring.empty_color = combo_empty_color
		accbar.get("custom_styles/fg").bg_color = acc_fill_color
		accbar.get("custom_styles/bg").bg_color = acc_empty_color
		energybar.get("custom_styles/fg").bg_color = energy_fg
		energybar.get("custom_styles/bg").bg_color = energy_bg
		
	
	
	
	if !Rhythia.show_config:
		$ConfigHud.visible = false
	
	if !Rhythia.enable_grid:
		Spawn.get_node("Inner").visible = false
	
	# --------------------------------------------- making this a setting cuz fog wants to lol

	if Rhythia.mod_hardrock and Rhythia.expand_hud_onhr:
		var HUDScale:Array = [
			$TimerHud,
			$LeftHud,
			$RightHud,
			$EnergyHud,
			$ComboHud,
		]
		Spawn.get_node("Inner").scale *= 1.35
		Spawn.get_node("Outer").scale *= 1.35
		$TimerHud.transform.origin += Vector3(0, 0.385, 0)
		$LeftHud.transform.origin += Vector3(-0.50, 0, 0)
		$RightHud.transform.origin += Vector3(0.50, 0, 0)
		$EnergyHud.transform.origin += Vector3(0, -0.45, 0)
		$ComboHud.transform.origin += Vector3(0, 0.40, 0)

		for l in HUDScale:
			l.scale *= 0.85

	if !Rhythia.enable_border:
		Spawn.get_node("Outer").visible = false

	if Rhythia.visual_mode or !Rhythia.show_left_panel:
		$LeftHud.visible = false
	
	if Rhythia.visual_mode or !Rhythia.show_right_panel:
		$RightHud.visible = false
	
	if !Rhythia.show_letter_grade:
		lettergrade.visible = false
	
	if !Rhythia.show_accuracy_bar:
		accbar.visible = false
	
	if Rhythia.visual_mode or !Rhythia.show_hp_bar:
		energybar.visible = false
		modholder.margin_top = 8
	
	if !Rhythia.show_timer:
		timelabel.visible = false
		timebar.visible = false

	
	# TODO: figure out how to handle these
	if not Rhythia.attach_hp_to_grid:
		var econtrol = $GridVP/Control/Energy
		var ehud = $EnergyHud
		econtrol.get_parent().remove_child(econtrol)
		$EnergyVP.add_child(econtrol)
		econtrol.margin_top = -300
		econtrol.margin_left = 0
		econtrol.margin_right = 900
		econtrol.margin_bottom = 0
#		remove_child(ehud)
#		Spawn.add_child(ehud)
#		ehud.transform.origin += Vector3(1,-1,0)

	if not Rhythia.attach_timer_to_grid:
		var tcontrol = $GridVP/Control/Timer
		var thud = $TimerHud
		tcontrol.get_parent().remove_child(tcontrol)
		$TimerVP.add_child(tcontrol)
		tcontrol.margin_top = 0
		tcontrol.margin_left = 0
		tcontrol.margin_right = 900
		tcontrol.margin_bottom = 300
#		remove_child(thud)
#		Spawn.add_child(thud)
#		thud.transform.origin += Vector3(1,-1,0)
	
	if Rhythia.simple_hud:
		$LeftVP/Control.self_modulate = Color(0,0,0,0)
		$RightVP/Control.self_modulate = Color(0,0,0,0)
		
		for n in $LeftVP/Control.get_children():
			n.visible = n.name == "SimpleBg" or n.name == "Pauses" or n.name == "PausesTitle"
			if n.visible: n.rect_position.y += 100
		
		for n in $RightVP/Control.get_children():
			n.visible = n.name == "SimpleBg" or n.name == "Misses" or n.name == "MissesTitle"
			if n.visible: n.rect_position.y += 100
		
	if Rhythia.faraway_hud:
		transform.origin = Vector3(0,0,-10)
		scale = Vector3(3.7,3.7,3.7)
	
#	if Rhythia.visual_mode:
#		$EnergyVP/Control/Modifiers.visible = false
	
	songnametxt.text = Rhythia.selected_song.name
	songnametxt2.text = Rhythia.selected_song.name
	mappertitle.text = tr("Mapped by ")
	mappertxt.text = Rhythia.selected_song.creator
	
	
	
	
	
	var ms = ""
	
	if Rhythia.replaying:
		if Rhythia.replay.autoplayer: modicons.get_node("Autoplay").visible = true
		else: modicons.get_node("Replaying").visible = true
	
	if Rhythia.mod_nofail: ms += tr("[ NOFAIL ACTIVE ]") + "\n"
	elif Rhythia.health_model == Globals.HP_OLD: ms += tr("Using old hp model (more hp + fast regen)") + "\n"
	
	var mods = []
	if Rhythia.mod_speed_level != Globals.SPEED_NORMAL:
		match Rhythia.mod_speed_level:
			Globals.SPEED_MMM: modicons.get_node("SpeedMMM").visible = true
			Globals.SPEED_MM: modicons.get_node("SpeedMM").visible = true
			Globals.SPEED_M: modicons.get_node("SpeedM").visible = true
			Globals.SPEED_P: modicons.get_node("SpeedP").visible = true
			Globals.SPEED_PP: modicons.get_node("SpeedPP").visible = true
			Globals.SPEED_PPP: modicons.get_node("SpeedPPP").visible = true
			Globals.SPEED_PPPP: modicons.get_node("SpeedPPPP").visible = true
			Globals.SPEED_CUSTOM: mods.append("S%s" % [Globals.speed_multi[Globals.SPEED_CUSTOM] * 100])
	if Rhythia.mod_sudden_death: mods.append("SuddenDeath")
	if Rhythia.mod_extra_energy: mods.append("Energy+")
	if Rhythia.mod_no_regen: mods.append("NoRegen")
	if Rhythia.mod_mirror_x or Rhythia.mod_mirror_y:
		var mirrorst = tr("Mirror")
		if Rhythia.mod_mirror_x: mirrorst += "X"
		if Rhythia.mod_mirror_y: mirrorst += "Y"
		mods.append(mirrorst)
	if Rhythia.mod_ghost: mods.append(tr("Ghost"))
	if Rhythia.mod_nearsighted: mods.append("Nearsight")
	if Rhythia.mod_chaos: mods.append(tr("Chaos"))
	if Rhythia.mod_earthquake: mods.append(tr("Earthquake"))
	if Rhythia.mod_flashlight: mods.append(tr("Flashlight"))
	if Rhythia.mod_hardrock: mods.append(tr("Hard Rock"))
	if Rhythia.invert_mouse: mods.append(tr("Mouse Inverted"))
	for i in range(mods.size()):
		if i != 0: ms += " "
		ms += mods[i]
	if mods.size() != 0 and !Rhythia.mod_nofail: ms += '\n'
	
	if Rhythia.hitwindow_ms != 55 or Rhythia.note_hitbox_size != 1.140:
		ms += "HW: %.0f ms | HB: %.02f m" % [Rhythia.hitwindow_ms,Rhythia.note_hitbox_size]
	
	modtxt.text = ms
	
	Spawn.get_node("Outer").visible = false
	if Rhythia.enable_border:
		yield(get_tree(),"idle_frame")
		remove_child(gridborder)
		yield(get_tree(),"idle_frame")
		Spawn.add_child(gridborder)
#		yield(get_tree(),"idle_frame")
#		var vpt = ViewportTexture.new()
#		gridmat.albedo_texture = vpt
#		vpt.viewport_path = get_tree().root.get_node("Song").get_path_to(gridvp)
	else:
		gridborder.visible = false




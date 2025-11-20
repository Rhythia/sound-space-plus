extends Spatial

var running = false
var panning = false
var ifading = false
var fading = false
var can_skip = false
var can_skip2 = false
var date = OS.get_datetime()

func _ready():
	# fix hands
	$Avatar/ArmL/Pointer.translation = Vector3(0,0,0)
	$Avatar/ArmR/Mesh.translation = Vector3(0,0,0)
	
	# lacunella
	if Rhythia.is_lacunella_enabled() and !((date.month == 6 and date.day == 07) or (date.month == 6 and date.day == 19)):
		$Avatar/Head/CubellaHair.visible = true

	# for max
	if Rhythia.memory_lacu() or ((date.month == 6 and date.day == 07) or (date.month == 6 and date.day == 19)):
		$Avatar/Head/CubellaHair.visible = true
		$Avatar/Head/CubellaHair/Hair.visible = false
		$Avatar/Head/CubellaHair/Ears.visible = false
		$Avatar/Head/CubellaHair/ElfL.visible = false
		$Avatar/Head/CubellaHair/ElfR.visible = false
		$Avatar/Head/CubellaHair/Hair_dya.visible = true
		$Avatar/Head/CubellaHair/Ears_dya.visible = true
	
	if OS.has_feature("Android"):
		$Skip.text = "Tap to skip"
	$ColorRect.modulate.a = 1
	# OS.window_fullscreen = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	yield(get_tree().create_timer(4),"timeout")
	running = true
	$Avatar/Animations.play("Float")
	$Avatar/Animations.playback_speed = 1
	$Camera2.rotation_degrees.y = 0
	yield(get_tree().create_timer(1),"timeout")
	$AudioStreamPlayer.play()
	can_skip = true
	yield(get_tree().create_timer(6.5),"timeout")
	$Camera.current = false
	$Camera2.current = true
	panning = true
	can_skip2 = true
	yield(get_tree().create_timer(14),"timeout")
	fading = true
	yield(get_tree().create_timer(4),"timeout")
	get_tree().change_scene("res://scenes/init.tscn")

func _input(event):
	if Input.is_action_just_pressed("pause") and can_skip:
		get_tree().change_scene("res://scenes/init.tscn")
	elif OS.has_feature("Android") and can_skip:
		get_tree().change_scene("res://scenes/init.tscn")

func _process(delta):
	$Sprite3D.rotation_degrees.z += 16 * delta
	$Sprite3D2.rotation_degrees.z += 8 * delta
	$Sprite3D3.rotation_degrees.z += 4 * delta
	
	if running and not fading:
		$ColorRect.modulate.a += (0 - $ColorRect.modulate.a) * 0.4 * delta
	if panning:
		$Camera2.translation.y += (12 - $Camera2.translation.y) * 0.3 * delta
		$Camera2.rotation_degrees.y += (180 - $Camera2.rotation_degrees.y) * 0.4 * delta
	if fading:
		$ColorRect.modulate.a += (1 - $ColorRect.modulate.a) * 2 * delta
		$Skip.modulate.a += (0 - $Skip.modulate.a) * 2 * delta
	if can_skip2 and not fading:
		$Skip.modulate.a += (0.5 - $Skip.modulate.a) * 1 * delta

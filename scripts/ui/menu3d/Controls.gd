extends Spatial

var controls_allowed:bool = false
var fov_target:float = 65

var yaw = 0
var pitch = 0

var yaw_limit = 75
var pitch_limit = 35

var yaw_pillow = 35
var pitch_pillow = 18

var ellipse_grow = 6

var joy_multi = 120

# $d = \sqrt {(a\cos t + c)^2 + (b\sin t)^2}$

func get_limits():
	return Vector2(yaw_limit, pitch_limit)
#	return Vector2(
#		sqrt( abs( pow(yaw_limit+ellipse_grow,2) * ( -(pow(pitch,2) / pow(pitch_limit+ellipse_grow,2)) + 1 ) ) ),
#		sqrt( abs( pow(pitch_limit+ellipse_grow,2) * ( -(pow(yaw,2) / pow(yaw_limit+ellipse_grow,2)) + 1 ) ) )
#	)

func _input(event:InputEvent):
	if !controls_allowed: return
	if (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED && event is InputEventMouseMotion) || event is InputEventScreenDrag:
		var xc = -(event.relative.x * Rhythia.sensitivity * 0.2)
		var yc = -(event.relative.y * Rhythia.sensitivity * 0.2)

		var l = get_limits()
		$Label.text = String(l)
		
		if sign(xc) == sign(yaw) && (l.x - abs(yaw)) < yaw_pillow:
			xc *= (l.x - abs(yaw)) / yaw_pillow
		
		if sign(yc) == sign(pitch) && (l.y - abs(pitch)) < pitch_pillow:
			yc *= (l.y - abs(pitch)) / pitch_pillow

		yaw = clamp(yaw + xc, -l.x, l.x)
		pitch = clamp(pitch + yc, -l.y, l.y)
		$Camera.rotation = Vector3(deg2rad(pitch), deg2rad(fmod(yaw, 360)), 0)
		$PointerHolder/Pointer.visible = true


var trail_cache:Array = []

var prev_end
var trail_started = false

var ct:float = 0
var segt:float = 0
var segl:float = 0.01

var total_trail_segments = 0

onready var trail_base = $PointerHolder/PointerTrail


func _ready():
	set_process(false) # this will be re-enabled by onboarding.gd when needed
#	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	var img = Globals.imageLoader.load_if_exists("user://cursor")
	if img: $PointerHolder/Pointer.mesh.surface_get_material(0).albedo_texture = img
	
	var mat = trail_base.get("material/0")
	var img2 = Globals.imageLoader.load_if_exists("user://trail")
	if img2: mat.albedo_texture = img2
	elif img: mat.albedo_texture = img
	
	yield(get_tree(),"idle_frame")
	prev_end = global_transform.origin

	for i in range(48):
		var trail = trail_base.duplicate()
		$PointerHolder.add_child(trail)
		trail.connect("cache_me",self,"cache_trail",[trail])
		trail_cache.append(trail)
		trail.init()
	trail_started = true

var t = 0
var ci = 0

var trail_t = 0

func cache_trail(part:Spatial):
	trail_cache.append(part)

var ripple = preload("res://assets/notefx/ripple/ripple.tscn")

func on_click():
	if !Rhythia.selected_colorset: return
	ci = (ci+1) % len(Rhythia.selected_colorset.colors)
	var e = ripple.instance()
	e.spawn_menu(self,Rhythia.selected_colorset.colors[ci],$PointerHolder/Pointer.transform)
	pass # this will do raycast stuff eventually

func _process(delta):
	if $Camera.fov > fov_target:
		$Camera.fov = max(lerp($Camera.fov, fov_target * 0.99, delta * 2), fov_target)
	elif $Camera.fov < fov_target:
		$Camera.fov = min(lerp($Camera.fov, fov_target * 1.01, delta * 2), fov_target)
	# if it's equal we don't need to do anything
	
	if !controls_allowed:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Input.is_action_just_pressed("toggle_mouse_lock"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	if controls_allowed:
		$PointerHolder.visible = true
		var xp = Input.get_action_strength("joy_right") - Input.get_action_strength("joy_left")
		var yp = Input.get_action_strength("joy_up") - Input.get_action_strength("joy_down")
		
		$Label.text = ""
		
	#	$Camera/p.visible = (xp != 0 || yp != 0)
	#	$Camera/p2.visible = (xp != 0 || yp != 0)
		
		if xp != 0 || yp != 0:
			$PointerHolder/Pointer.visible = true
			var l = get_limits()
			
			
			$Camera/p.transform.origin.x = xp
			$Camera/p.transform.origin.y = yp
			
			if sign(xp) == -sign(yaw) && (l.x - abs(yaw)) < yaw_pillow:
				xp *= (l.x - abs(yaw)) / yaw_pillow
			
			if sign(yp) == sign(pitch) && (l.y - abs(pitch)) < pitch_pillow:
				yp *= (l.y - abs(pitch)) / pitch_pillow
			
			var xc = -(xp * Rhythia.sensitivity * delta * joy_multi)
			var yc = (yp * Rhythia.sensitivity * delta * joy_multi)
			
			$Camera/p2.transform.origin.x = xp
			$Camera/p2.transform.origin.y = yp

			yaw = clamp(yaw + xc, -l.x, l.x)
			pitch = clamp(pitch + yc, -l.y, l.y)
			$Camera.rotation = Vector3(deg2rad(pitch), deg2rad(fmod(yaw, 360)), 0)
		
		$Camera/RayCast.force_raycast_update()
		
		if $Camera/RayCast.is_colliding():
			$Label.text += "\nP: " + String($Camera/RayCast.get_collision_point())
			$Label.text += "\nN: " + String($Camera/RayCast.get_collision_normal())
			
			$PointerHolder/Pointer.global_translation = $Camera/RayCast.get_collision_point()
			$PointerHolder/Pointer.look_at($PointerHolder/Pointer.global_translation - $Camera/RayCast.get_collision_normal(),Vector3.UP)
			
			$PointerHolder/Pointer.scale = Vector3(Rhythia.cursor_scale, Rhythia.cursor_scale, Rhythia.cursor_scale)
		
		if Rhythia.cursor_color_type == Globals.CURSOR_RAINBOW:
			$PointerHolder/Pointer.mesh.material.albedo_color = Color.from_hsv(Rhythia.rainbow_t*0.1,0.65,1)
		elif Rhythia.cursor_color_type == Globals.CURSOR_NOTE_COLOR:
			if Rhythia.selected_colorset:
				ci = ci % len(Rhythia.selected_colorset.colors)
				$PointerHolder/Pointer.mesh.material.albedo_color = Rhythia.selected_colorset.colors[ci]
		else:
			$PointerHolder/Pointer.mesh.material.albedo_color = Rhythia.cursor_color
	else:
		$PointerHolder/Pointer.visible = false
	
	if Rhythia.cursor_trail and trail_started:
#		print("doing trail")
		trail_t += delta
		$Label.text += "\n\nT: " + String(trail_t)
		
		if Rhythia.smart_trail:
			$Label.text += "\nsmart"
			trail_t = 0
			var start_p = $PointerHolder/Pointer.global_transform.origin
			var end_p = prev_end
			$Label.text += "\nD: " + String((start_p-end_p).length())
			var amt = min(ceil(Rhythia.trail_detail*((start_p-end_p).length())),120)
			$Label.text += "\nA: " + String(amt)
			
			for i in range(amt):
				var trail:Spatial
				var v = float(i)/float(amt)
				var pos = lerp(start_p,end_p,v)
				if trail_cache.size() != 0:
					trail = trail_cache.pop_front()
				else:
					trail = trail_base.duplicate()
					$PointerHolder.add_child(trail)
					trail.connect("cache_me",self,"cache_trail",[trail])
					total_trail_segments += 1
				
				trail.start_smart(v*delta,pos)
			
		elif trail_t >= 1.0 / Rhythia.trail_detail:
			$Label.text += "\ndumb"
			while trail_t >= 1.0 / Rhythia.trail_detail:
				var trail:Spatial
				var v = clamp(trail_t / (1.0 / Rhythia.trail_detail), 0.0, 1.0)
				
				trail_t -= (1.0 / Rhythia.trail_detail)
				
				if trail_cache.size() != 0:
					trail = trail_cache.pop_front()
				else:
					trail = trail_base.duplicate()
					$PointerHolder.add_child(trail)
					trail.connect("cache_me",self,"cache_trail",[trail])
					total_trail_segments += 1
				trail.start(v)
		
		prev_end = $PointerHolder/Pointer.global_transform.origin
		$Label.text += "\nTotal: " + String(total_trail_segments)
	
	if Input.is_action_just_pressed("menu_click"):
		on_click()

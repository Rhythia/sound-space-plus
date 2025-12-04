extends Spatial

signal cache_me

var started:bool = false
var t:float = 0

onready var cursor = get_node("../Pointer")
onready var cursormesh = get_node("../Pointer")

var last_origin = Vector3(-100,0,0)
var before
var can_reuse:bool = false
var transp_multi = 1

var smart:bool = false

func respawn(t_override=null):
	if t_override:
		visible = true
		global_transform.origin = t_override
	else:
		visible = (cursor.global_transform.origin - Vector3(0,0,0.001)) != last_origin
		global_transform.origin = cursor.global_transform.origin - Vector3(0,0,0.001)
	
	self.get("material/0").albedo_color = cursormesh.mesh.surface_get_material(0).albedo_color
	rotation = cursormesh.rotation

func upd_dumb(delta):
	t += (delta/Rhythia.trail_time)
	
	var a = clamp((t - 0.2),0,1)
	if Rhythia.trail_mode_opacity:
		get("material/0").albedo_color.a = a * 0.6 * transp_multi
	if Rhythia.trail_mode_scale:
		scale = Vector3(a*Rhythia.cursor_scale,a*Rhythia.cursor_scale,a*Rhythia.cursor_scale)
	if t >= 1:
		started = false
		visible = false
		emit_signal("cache_me")

func update(delta):
	t -= (delta/Rhythia.trail_time)
	var a = clamp((t),0,1)
	if Rhythia.trail_mode_opacity:
		self.get("material/0").albedo_color.a = a * 0.6 * transp_multi
	if Rhythia.trail_mode_scale:
		scale = Vector3(a*Rhythia.cursor_scale,a*Rhythia.cursor_scale,a*Rhythia.cursor_scale)
	if t <= 0:
		started = false
		visible = false
		emit_signal("cache_me")

func _process(delta):
	if started:
		if smart: update(delta)
		else: upd_dumb(delta)

var init_done:bool = false
func init():
	smart = false
	scale = Vector3(0,1,0)
	if not Rhythia.trail_mode_scale:
		scale = Vector3(Rhythia.cursor_scale,Rhythia.cursor_scale,Rhythia.cursor_scale)
	
	if init_done: return
	init_done = true
	var mat:SpatialMaterial = self.get("material/0").duplicate()
	self.set("material/0",mat)

func start(v:float):
	init()
	t = v
	started = true


func start_smart(v:float,pos:Vector3):
	init()
	smart = true
	started = true
	t = 1 - v
	respawn(pos)

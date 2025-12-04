extends Spatial

var active:bool = false
var menu:bool = false

func _process(delta):
	if active:
		if $Particles.emitting == false:
			active = false
			queue_free()
			return

func spawn_menu(parent:Node,col:Color,transform:Transform):
	menu = true
#	setup("ssp_explosion",false)
	global_transform = transform
	spawn(parent,transform.origin,col,"ssp_explosion",false)

func spawn(parent:Node,pos:Vector3,col:Color,id:String,miss:bool):
	transform.origin = pos
	parent.add_child(self)
	visible = true
	$Particles.emitting = true
	active = true

func setup(id:String,miss:bool):
	if id == "ssp_explosion_t":
		$Particles.material_override = $Particles.material_override.duplicate()
		$Particles.material_override.albedo_color = Color(1.0,1.0,1.0,0.3)

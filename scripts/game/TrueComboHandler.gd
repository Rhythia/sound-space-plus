extends Label

func _ready():
	if !Rhythia.display_true_combo:
		visible = false
	else:
		visible = true
		
func _process(delta):
	rect_position.y += (150 - rect_position.y) * 0.25 * (delta * 60.0)

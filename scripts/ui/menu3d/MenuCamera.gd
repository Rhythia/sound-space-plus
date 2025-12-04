extends Camera

var yaw = 0
var pitch = 0

func _input(event):
	if Rhythia.cam_unlock and !Rhythia.replaying:
		if (event is InputEventMouseMotion) or (event is InputEventScreenDrag):
			yaw = fmod(yaw - event.relative.x * Rhythia.sensitivity * 0.2, 360)
			pitch = max(min(pitch - event.relative.y * Rhythia.sensitivity * 0.2, 89), -89)
			rotation = Vector3(deg2rad(pitch), deg2rad(yaw), 0)

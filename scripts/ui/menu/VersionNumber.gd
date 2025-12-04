extends Label

export var template:String = "Rhythia [%s]"

func _ready():
	text = template % ProjectSettings.get_setting("application/config/version")

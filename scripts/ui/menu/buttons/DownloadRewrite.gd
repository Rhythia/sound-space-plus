extends Button


# Declare member variables here. Examples:
# var a = 2
# var b = "text"


# Called when the node enters the scene tree for the first time.
func _ready():
	connect("pressed", self, "_button_pressed")

func _button_pressed():
	OS.shell_open("https://www.github.com/Rhythia/Client/releases/latest")


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

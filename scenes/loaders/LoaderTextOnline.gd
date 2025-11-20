extends Label

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	text = "Updating Online Modules\nGame might close/restart few times\n Checking for updates"
	if(OnlineDownloader.downloadProgress>0):
		text = "Updating Online Modules\nGame might close/restart few times\n Prerequisites:"+ str(OnlineDownloader.downloadProgress) + "%"
	
	if(Socket.loadingProgress>0):
		text = "Updating Online Modules\nGame might close/restart few times\n Renderer Modules:"+ str(Socket.loadingProgress) + "%"
	pass

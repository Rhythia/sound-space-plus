extends Control

var online_services_ok:bool = false
var online_maps_ok:bool = false
var online_score_submission_ok:bool = false
var online_silenced:bool = false
var online_banned:bool = false # Restricted / Excluded
var online_anti_tamper:bool = false
var online_server_down:bool = false
var online_no_internet:bool = false
var online_signed_out:bool = false
var online_is_admin:bool = false
var online_is_moderator:bool = false
var online_is_mmt:bool = false
var online_is_rct:bool = false

func check_online_status():
	online_maps_ok = (Online.netmaps_status == Online.STATUS.OK)
	online_server_down = (Online.netmaps_status == Online.STATUS.API_HTTP_FAIL)
	online_no_internet = (Online.netmaps_status == Online.STATUS.CONNECTION_TEST_FAIL)
	online_signed_out = true

func update_status_icons():
	$V/Bar/Debug.visible = OS.has_feature("debug")
	$V/Bar/Release.visible = not OS.has_feature("debug")
	
	check_online_status()
	$V/Bar/OnlineServicesYes.visible = online_services_ok
	$V/Bar/OnlineServicesNo.visible = not online_services_ok
	$V/Bar/OnlineMapsYes.visible = online_maps_ok
	$V/Bar/OnlineMapsNo.visible = not online_maps_ok
	$V/Bar/ScoreSubYes.visible = online_score_submission_ok
	$V/Bar/ScoreSubNo.visible = not online_score_submission_ok
	$V/Bar/Silenced.visible = online_silenced
	$V/Bar/Banned.visible = online_banned
	$V/Bar/AntiTamper.visible = online_anti_tamper
	$V/Bar/ServerDown.visible = online_server_down
	$V/Bar/NoInternet.visible = online_no_internet
	$V/Bar/SignedOut.visible = online_signed_out
	$V/Bar/IsAdmin.visible = online_is_admin
	$V/Bar/IsModerator.visible = online_is_moderator
	$V/Bar/IsMMT.visible = online_is_mmt
	$V/Bar/IsRCT.visible = online_is_rct

var bg_image_fade:float = 0.0
var bg_image_httpreq:HTTPRequest = HTTPRequest.new()
var bg_image_ready:bool = false


func _bg_image_req_done(result:int, response_code:int, headers:PoolStringArray, body:PoolByteArray):
	if result == OK and response_code == 200:
		var format = Globals.imageLoader.get_format(body)
		var img = Image.new()
		var img_err = ERR_INVALID_DATA
		if format == "png": img_err = img.load_png_from_buffer(body)
		elif format == "bmp": img_err = img.load_bmp_from_buffer(body)
		elif format == "jpg": img_err = img.load_jpg_from_buffer(body)
		elif format == "webp": img_err = img.load_webp_from_buffer(body)
		
		if img_err == OK:
			print("mraaaow mrrp meoww :3c")
			var texture = ImageTexture.new()
			texture.create_from_image(img)
			print("%s %sx%s" % [texture.get_format(), texture.get_width(), texture.get_height()])
			get_parent().texture = texture
		else:
			print("image load was error %s" % img_err)
	else:
		print("request failed: result=%s code=%s" % [result,response_code])
	bg_image_ready = true
	# if the image fails we want to fade in the normal background

func _process(delta):
	if bg_image_ready and bg_image_fade < 1.0:
		bg_image_fade += delta
		get_parent().self_modulate = Color(1.0,1.0,1.0,bg_image_fade * 0.3)
	if Input.is_action_just_pressed("ui_quicksettings"):
		get_parent().self_modulate = Color(1.0,1.0,1.0,0.0)
		bg_image_fade = 0
		bg_image_ready = false
		get_bg_image()

func get_bg_image():
	if randf() < 0.05:
		bg_image_ready = true
		get_parent().texture = load("res://assets/images/devbg.png")
		# use the default image
	else:
		var error = bg_image_httpreq.request("https://cataas.com/cat")
		if error != OK:
			print("error %s requesting bg image" % error)
			bg_image_ready = true
			# use default image

func _exit_tree():
	bg_image_httpreq.cancel_request()

func _ready():
	add_child(bg_image_httpreq)
	bg_image_httpreq.connect("request_completed",self,"_bg_image_req_done")
	bg_image_httpreq.use_threads = true
	bg_image_httpreq.timeout = 6
	bg_image_httpreq.body_size_limit = 1024*1024*4 # 4 MiB
	get_bg_image()
	
	get_parent().self_modulate = Color(1.0,1.0,1.0,0.0)
	update_status_icons()
	
	$V/Bar/Quit.connect("pressed",get_tree(),"quit")
	$V/Bar/ToDevMenu.connect("pressed",get_tree(),"change_scene",["res://scenes/devmenu.tscn"])
	$V/Bar/ToMenu2.connect("pressed",get_tree(),"change_scene",["res://scenes/menu/menu2.tscn"])
	$V/Bar/ToMenu3.connect("pressed",get_tree(),"change_scene",["res://scenes/menu/menu3d.tscn"])
	$V/Bar/ToInit3d.connect("pressed",get_tree(),"change_scene",["res://scenes/init3d.tscn"])
	$V/Bar/ToSongload.connect("pressed",get_tree(),"change_scene",["res://scenes/loaders/songload.tscn"])


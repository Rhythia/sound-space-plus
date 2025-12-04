extends Node

# https://cdn.rhythia.net/index.json
enum STATUS {
	OK = 0,
	NOT_INITIALIZED,
	CONNECTION_TEST_FAIL,
	API_HTTP_FAIL,
	CONFIG_ERROR,
	INTERNAL_ERROR,
	ANTI_TAMPER,
}
var netmaps_status:int = STATUS.NOT_INITIALIZED

var mapdb_api:String = ""

var map_registry:Registry

signal db_maps_done
signal map_downloaded

signal _httpreq_finished

var mapdl_hr:HTTPRequest = HTTPRequest.new()
var mapdl_bs:float = 1
var mapdl_bd:float = 0

signal _mapdl_req
func _on_mapdl_request_completed(result:int,response_code:int,headers:PoolStringArray,body:PoolByteArray):
	emit_signal("_mapdl_req",{result=result,response_code=response_code,headers=headers,body=body})

func cancel():
	mapdl_hr.cancel_request()
	emit_signal("_mapdl_req",{result=-1})

func mapdl_error(id:String,error:String,map:Song):
	print("[MapDB Download] Map %s errored with code %s" % [map.id,error])
	emit_signal("map_downloaded",{id=id, success=false, error=error})

func _process(_d):
	mapdl_bs = mapdl_hr.get_body_size()
	mapdl_bd = mapdl_hr.get_downloaded_bytes()

signal _connection_test
var ctest_hr:HTTPRequest = HTTPRequest.new()
func _on_ctest_request_completed(result:int,response_code:int,headers:PoolStringArray,body:PoolByteArray):
	if result == HTTPRequest.RESULT_SUCCESS:
		emit_signal("_connection_test",true)
	else:
		emit_signal("_connection_test",false)
		netmaps_status = STATUS.CONNECTION_TEST_FAIL

func test_connection():
	var res = ctest_hr.request(ProjectSettings.get_setting("application/networking/test_url"))
	if res != OK:
		emit_signal("_connection_test",false)
		netmaps_status = STATUS.CONNECTION_TEST_FAIL

func _mapdl_handler(id:String,map:Song):
	print("[MapDB Download] Starting download of map %s" % map.id)
	if !ProjectSettings.get_setting("application/networking/enabled"):
		mapdl_error(id,"Networking is disabled",map)
		netmaps_status = STATUS.CONFIG_ERROR
		return
	if mapdb_api == "":
		mapdl_error(id,"MapDB API Invalid",map)
		netmaps_status = STATUS.CONFIG_ERROR
		return
	if !Globals.is_valid_url(mapdb_api):
		mapdl_error(id,"MapDB API Invalid",map)
		netmaps_status = STATUS.CONFIG_ERROR
		return
	
	call_deferred("test_connection")
	if !yield(self,"_connection_test"):
		mapdl_error(id,"Failed to connect",map); return
	
	var dir:Directory = Directory.new()
	if dir.file_exists(Globals.p("user://mapdl.sspm.part")):
		dir.remove(Globals.p("user://mapdl.sspm.part"))
	
	mapdl_hr.download_file = Globals.p("user://mapdl.sspm.part")
	var res = mapdl_hr.request(map.download_url)
	if res != OK:
		if res == ERR_INVALID_PARAMETER: mapdl_error(id,"Invalid Parameter",map)
		elif res == ERR_CANT_CONNECT: mapdl_error(id,"Can't Connect",map)
		else: mapdl_error(id,"Unknown Error (%s)" % res,map)
	else:
		var mapdl_res = yield(self,"_mapdl_req")
		
		if mapdl_res.result == HTTPRequest.RESULT_CANT_RESOLVE:
			mapdl_error(id,"Can't Resolve",map)
		elif mapdl_res.result == HTTPRequest.RESULT_CANT_CONNECT:
			mapdl_error(id,"Can't Connect",map)
		elif mapdl_res.result == HTTPRequest.RESULT_CONNECTION_ERROR:
			mapdl_error(id,"Connection Error",map)
		elif mapdl_res.result == HTTPRequest.RESULT_SSL_HANDSHAKE_ERROR:
			mapdl_error(id,"SSL Handshake Error",map)
		elif mapdl_res.result == HTTPRequest.RESULT_TIMEOUT:
			mapdl_error(id,"Timeout",map)
		elif mapdl_res.result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			mapdl_error(id,"Redirect Limit Reached",map)
		elif mapdl_res.result == HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN:
			mapdl_error(id,"Download File Open Error",map)
		elif mapdl_res.result == HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR:
			mapdl_error(id,"Download File Write Error",map)
			
		elif mapdl_res.result == HTTPRequest.RESULT_SUCCESS:
			if mapdl_res.response_code == 200:
				dir.rename(Globals.p("user://mapdl.sspm.part"),Globals.p("user://maps/%s.sspm" % map.id))
				map.load_from_sspm(Globals.p("user://maps/%s.sspm" % map.id))
				if map.songType != Globals.MAP_SSPM2:
					if Input.is_action_pressed("skip_convert"):
						Globals.notify(
							Globals.NOTIFY_WARN,
							"Not converting to SSPMv2 as Ctrl+M was held.",
							"Skip Conversion"
						)
					else:
						map.convert_to_sspm(true)
				map.load_from_sspm(Globals.p("user://maps/%s.sspm" % map.id))
				emit_signal("map_downloaded",{id=id, success=true})
			else:
				var resp = parse_json(mapdl_res.body.get_string_from_utf8())
				if resp: mapdl_error(id, resp.error, map)
				else: mapdl_error(id, "HTTP-%s" % mapdl_res.response_code, map)
		elif mapdl_res.result == -1: # cancelled
			mapdl_error(id,"Cancelled", map)
		else: # Unknown error
			mapdl_error(id,"Unknown Error", map)


func download_map(map:Song):
	var id = v4()
	call_deferred("_mapdl_handler",id,map)
	return id


var netmaps_hr:HTTPRequest = HTTPRequest.new()
signal _netmaps_req
func _on_netmaps_request_completed(result:int,response_code:int,headers:PoolStringArray,body:PoolByteArray):
	emit_signal("_netmaps_req",{result=result,response_code=response_code,headers=headers,body=body})

const weekday = [
	"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"
]
const month = [
	"Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
]

func load_db_maps():
	yield(get_tree(),"idle_frame")
	
	if !ProjectSettings.get_setting("application/networking/enabled"):
		pass # 011-865
	elif mapdb_api == "" || mapdb_api.begins_with("http://localhost") && !OS.has_feature("debug"):
		show_db_error("Map database is improperly configured.","Map Database Error")
		yield(self,"error_done")
	elif !Globals.is_valid_url(mapdb_api):
		show_db_error("Map database download failed.\nMapDB URL Invalid","Map Database Error")
		yield(self,"error_done")
	else:
		call_deferred("test_connection")
		if !yield(self,"_connection_test"):
			Globals.notify(
				Globals.NOTIFY_ERROR,
				"Online maps will not be loaded - failed to connect to map database.\n\nMake sure your system clock is Synchronized!",
				"No Connection"
			)
			emit_signal("db_maps_done")
			return
		
		var netmaps:Dictionary = {
			"id_that_doesnt_exist": parse_json("""{
				"id":"id_that_doesnt_exist",
				"download":"http://chedski.test/ssp/mapdb/api/download/id_that_doesnt_exist",
				"audio":"http://chedski.test/ssp/mapdb/api/audio/id_that_doesnt_exist",
				"cover":null,
				"version":1,
				"name":"000000 net test map",
				"song":"Waterflame - Geometrical Dominator",
				"author":["Azurlexx"],
				"difficulty":-1,
				"difficulty_name":"LOGIC?",
				"stars":-1,
				"length_ms":96846,
				"note_count":384,
				"has_cover":false,
				"broken":false,
				"tags":["ss_archive"],
				"content_warnings":[],
				"note_data_offset":1594212,
				"note_data_length":2688,
				"music_format":"mp3",
				"music_offset":117,
				"music_length":1594095 }""")
		}
		
		var file:File = File.new()
		var dict_date = Time.get_datetime_dict_from_unix_time(1373) # first number that came to mind
		
		if file.file_exists(Globals.p("user://.mapdb_cache.json")) && file.file_exists(Globals.p("user://.mapdb_updated.txt")):
			var err = file.open(Globals.p("user://.mapdb_updated.txt"),File.READ)
			if err == OK:
				dict_date = Time.get_datetime_dict_from_datetime_string(file.get_as_text(), true)
			file.close()

		netmaps_hr.request(mapdb_api, PoolStringArray([
			"If-Modified-Since: %s, %02d %s %04d %02d:%02d:%02d GMT" % [
				weekday[dict_date.weekday],
				dict_date.day, month[dict_date.month - 1], dict_date.year,
				dict_date.hour, dict_date.minute, dict_date.second
			]
		]))
		var netmaps_res = yield(self,"_netmaps_req")
		
		
		
		if netmaps_res.result == HTTPRequest.RESULT_CANT_RESOLVE:
			show_db_error("Map database download failed.\nError: Can't Resolve","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
		elif netmaps_res.result == HTTPRequest.RESULT_CANT_CONNECT:
			show_db_error("Map database download failed.\nError: Can't Connect","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
		elif netmaps_res.result == HTTPRequest.RESULT_CONNECTION_ERROR:
			show_db_error("Map database download failed.\nError: Connection Error","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
		elif netmaps_res.result == HTTPRequest.RESULT_SSL_HANDSHAKE_ERROR:
			show_db_error("Map database download failed.\nError: SSL Handshake Error","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
		elif netmaps_res.result == HTTPRequest.RESULT_TIMEOUT:
			show_db_error("Map database download failed.\nError: Timeout","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
		elif netmaps_res.result == HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			show_db_error("Map database download failed.\nError: Redirect Limit Reached","Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
			
		elif netmaps_res.result == HTTPRequest.RESULT_SUCCESS:
			netmaps_status = STATUS.OK
			if netmaps_res.response_code == 200:
				print("Cache miss!")
				var res = file.open(Globals.p("user://.mapdb_cache.json"),File.WRITE)
				if res == OK:
					file.store_buffer(netmaps_res.body)
				file.close()
				if res == OK:
					res = file.open(Globals.p("user://.mapdb_updated.txt"),File.WRITE)
					if res == OK:
						file.store_string(Time.get_datetime_string_from_system(true))
					file.close()
				
				var nmp = parse_json(netmaps_res.body.get_string_from_utf8())
				if !(nmp is Dictionary):
					show_db_error("Map database download failed.\nError: Malformed JSON","Map Database Error")
					yield(self,"error_done")
				else:
					netmaps = nmp
					var i = 0
					for id in netmaps.keys():
						if !map_registry.idx_id.has(id):
							var song:Song = Song.new()
							var result:Dictionary = song.load_from_db_data(netmaps[id])
							
							if result.success:
								map_registry.add_item(song)
							else:
								print("[MapDB Import] Map %s errored with code %s" % [id,result.error])
								Globals.notify(
									Globals.NOTIFY_ERROR,
									"map %s errored\nError code: %s" % [id,result.error],
									"Map Database Import"
								)
							
							i += 1
							if fmod(i,floor(float(netmaps.size())/100)) == 0: yield(get_tree(),"idle_frame")
			elif netmaps_res.response_code == 304:
				print("Cache hit!")
				var res = file.open(Globals.p("user://.mapdb_cache.json"),File.READ)
				if res == OK:
					var nmp = parse_json(file.get_as_text())
					if !(nmp is Dictionary):
						var dir:Directory = Directory.new()
						dir.remove(Globals.p("user://.mapdb_cache.json"))
						dir.remove(Globals.p("user://.mapdb_updated.txt"))
					else:
						netmaps = nmp
						var i = 0
						for id in netmaps.keys():
							if !map_registry.idx_id.has(id):
								var song:Song = Song.new()
								var result:Dictionary = song.load_from_db_data(netmaps[id])
								
								if result.success:
									map_registry.add_item(song)
								else:
									print("[MapDB Import] Map %s errored with code %s" % [id,result.error])
									Globals.notify(
										Globals.NOTIFY_ERROR,
										"map %s errored\nError code: %s" % [id,result.error],
										"Map Database Import"
									)
								
								i += 1
								if fmod(i,floor(float(netmaps.size())/100)) == 0: yield(get_tree(),"idle_frame")
				file.close()
			else:
				show_db_error("Map database download failed.\nError code: HTTP-%s" % netmaps_res.response_code,"Map Database Error")
				netmaps_status = STATUS.API_HTTP_FAIL
				yield(self,"error_done")
		else: # Unknown error
			show_db_error("Map database download failed.\nError code: HTTP-%s" % netmaps_res.response_code,"Map Database Error")
			netmaps_status = STATUS.API_HTTP_FAIL
			yield(self,"error_done")
			
	
	emit_signal("db_maps_done")



var latest_version_data
signal latest_version
var version_hr:HTTPRequest = HTTPRequest.new()
func check_latest_version():
	if (
		!(OS.has_feature("Windows") or OS.has_feature("X11"))
		or !ProjectSettings.get_setting("application/networking/enabled")
		):
		emit_signal("latest_version",ProjectSettings.get_setting("application/config/version"))
		return
	var github_url = "https://api.github.com/repos/%s/releases/latest"
	version_hr.request(github_url % ProjectSettings.get_setting("application/networking/github_repo"))

func _on_version_request_completed(result:int,response_code:int,headers:PoolStringArray,body:PoolByteArray):
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		emit_signal("latest_version",ProjectSettings.get_setting("application/config/version"))
		return
	var string = body.get_string_from_utf8()
	var json = JSON.parse(string)
	var data = json.result
	latest_version_data = data
	
	emit_signal("latest_version",data.tag_name)

signal update_finished
signal _update_req
var update_hr:HTTPRequest = HTTPRequest.new()
func attempt_update():
	var asset
	var asset_name = "windows.zip"
	if OS.has_feature("X11"): asset_name = "linux.zip"
	for _asset in latest_version_data.assets:
		if _asset.name == asset_name:
			asset = _asset
			break
	if !asset:
		emit_signal("update_finished")
		return
	var exec_dir = OS.get_executable_path().get_base_dir()
	var file_path = exec_dir.plus_file("update.zip")
	update_hr.download_file = file_path
	update_hr.request(asset.url,["Accept: application/octet-stream"])
	var res = yield(self,"_update_req")
	if res[0] != HTTPRequest.RESULT_SUCCESS or res[1] != 200:
		emit_signal("update_finished")
		return
	print("Extracting")
	ProjectSettings.load_resource_pack(file_path,false)
	var read_file = File.new()
	read_file.open("res://SoundSpacePlus.pck",File.READ)
	var new_file_buffer = read_file.get_buffer(read_file.get_len())
	read_file.close()
	var file = File.new()
	var dir = Directory.new()
	if dir.file_exists(exec_dir.plus_file("SoundSpacePlus.pck.old")):
		dir.remove(exec_dir.plus_file("SoundSpacePlus.pck.old"))
	if dir.file_exists(exec_dir.plus_file("SoundSpacePlus.pck")):
		dir.rename(exec_dir.plus_file("SoundSpacePlus.pck"),exec_dir.plus_file("SoundSpacePlus.pck.old"))
	file.open(exec_dir.plus_file("SoundSpacePlus.pck"),File.WRITE)
	file.store_buffer(new_file_buffer)
	file.close()
	emit_signal("update_finished")
func _on_update_request_completed(result:int,response_code:int,headers:PoolStringArray,body:PoolByteArray):
	emit_signal("_update_req",[result,response_code])

func _ready():
	add_child(netmaps_hr)
	netmaps_hr.use_threads = true
	netmaps_hr.timeout = 30#80
	netmaps_hr.connect("request_completed",self,"_on_netmaps_request_completed")
	
	add_child(ctest_hr)
	ctest_hr.use_threads = true
	ctest_hr.timeout = 5
	ctest_hr.connect("request_completed",self,"_on_ctest_request_completed")
	
	add_child(mapdl_hr)
	mapdl_hr.use_threads = false
	mapdl_hr.timeout = 0
	mapdl_hr.connect("request_completed",self,"_on_mapdl_request_completed")
	
	add_child(version_hr)
	version_hr.use_threads = true
	version_hr.timeout = 5
	version_hr.connect("request_completed",self,"_on_version_request_completed")
	
	add_child(update_hr)
	update_hr.use_threads = true
	update_hr.timeout = 0
	update_hr.connect("request_completed",self,"_on_update_request_completed")
	
	pause_mode = PAUSE_MODE_PROCESS
	
	mapdb_api = ProjectSettings.get_setting("application/networking/mapdb_api")

signal error_done
func show_db_error(body:String,title:String):
	# Globals.notify(Globals.NOTIFY_ERROR,title,body)
	Globals.confirm_prompt.s_alert.play()
	Globals.confirm_prompt.open(body,title,[{text="OK"}])
	yield(Globals.confirm_prompt,"option_selected")
	Globals.confirm_prompt.s_back.play()
	Globals.confirm_prompt.close()
	yield(Globals.confirm_prompt,"done_closing")
	emit_signal("error_done")

const MODULO_8_BIT = 256

static func getRandomInt():
  # Randomize every time to minimize the risk of collisions
  randomize()

  return randi() % MODULO_8_BIT

static func uuidbin():
  # 16 random bytes with the bytes on index 6 and 8 modified
  return [
	getRandomInt(), getRandomInt(), getRandomInt(), getRandomInt(),
	getRandomInt(), getRandomInt(), ((getRandomInt()) & 0x0f) | 0x40, getRandomInt(),
	((getRandomInt()) & 0x3f) | 0x80, getRandomInt(), getRandomInt(), getRandomInt(),
	getRandomInt(), getRandomInt(), getRandomInt(), getRandomInt(),
  ]

static func v4():
  # 16 random bytes with the bytes on index 6 and 8 modified
  var b = uuidbin()

  return '%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x' % [
	# low
	b[0], b[1], b[2], b[3],
	# mid
	b[4], b[5],
	# hi
	b[6], b[7],
	# clock
	b[8], b[9],
	# clock
	b[10], b[11], b[12], b[13], b[14], b[15]
  ]

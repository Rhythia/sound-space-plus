extends Node

# URL for the WebSocket server
export var SOCKET_URL = "ws://127.0.0.1:36331"

# WebSocket client instance
var _wsClient = WebSocketClient.new()

# Maximum number of reconnection attempts (-1 for unlimited retries)
export var max_retries = -1
var retry_count = 0
var loadingProgress = 0
var reconnect_delay = 2.0 # Delay between reconnection attempts in seconds
var forceExit = false

var connected = false

### **Lifecycle Methods**

func replay_error(txt:String):
	Rhythia.get_tree().paused = true
	Globals.confirm_prompt.s_alert.play()
	Globals.confirm_prompt.open(txt,"Error",[{text="OK"}])
	yield(Globals.confirm_prompt,"option_selected")
	Globals.confirm_prompt.s_back.play()
	Globals.confirm_prompt.close()
	yield(Globals.confirm_prompt,"done_closing")
	Rhythia.just_ended_song = false # Prevent PB handling
	Rhythia.get_tree().change_scene("res://scenes/loaders/menuload.tscn")

# Called when the node is added to the scene
func _ready():
	print("Initializing Socket Module")
	self.pause_mode = Node.PAUSE_MODE_PROCESS
	

# Initializes the WebSocket and connects signals
func initialize_socket():
	"""
	Initializes the WebSocket module, connects signals for WebSocket events,
	and attempts to establish a connection to the server.

	- Signals:
	  - `connection_closed`: Handles when the connection is closed.
	  - `connection_error`: Handles connection errors.
	  - `connection_established`: Handles successful connection establishment.
	  - `data_received`: Handles incoming data.
	"""
	_wsClient = WebSocketClient.new()
	_wsClient.connect("connection_closed", self, "_on_connection_closed")
	_wsClient.connect("connection_error", self, "_on_connection_closed")
	_wsClient.connect("connection_established", self, "_on_connection_established")
	_wsClient.connect("data_received", self, "_on_data_received")
	
	var err = _wsClient.connect_to_url(SOCKET_URL)
	if err != OK:
		print("Error while connecting:", err)
		set_physics_process(false)

# Called every frame
func _physics_process(delta):
	"""
	Polls the WebSocket client for updates. This keeps the connection
	alive and processes incoming/outgoing packets.
	"""
	_wsClient.poll()


### **Signal Handlers**

# Handles the connection being closed
func _on_connection_closed(was_clean = false):
	print("Connection Closed. Clean:", was_clean)
	set_physics_process(false)
	if max_retries == -1 or retry_count < max_retries:
		print("Attempting to reconnect in", reconnect_delay, "seconds...")
		retry_count += 1
		yield (get_tree().create_timer(reconnect_delay), "timeout")
		initialize_socket()
	else:
		print("Maximum reconnection attempts reached. Giving up.")

# Handles the connection being successfully established
func _on_connection_established(proto = ""):	
	print("Connection Established", proto)
	


# Handles data received from the WebSocket
func _on_data_received():
	var payload = JSON.parse(_wsClient.get_peer(1).get_packet().get_string_from_utf8()).result
	print("RECEIVED:", payload)
	
	connected = true
	
	if(payload.get("loading")):
		loadingProgress = payload.get("loading")
	
	if(payload.get("loaded")):
		get_tree().change_scene("res://scenes/Intro.tscn")
	
	if(payload.get("test")==1):
		send_start()
	
	if (payload.get("pause")==true):
		get_tree().paused = true  # Pauses the main game loop
	
	if(payload.get("pause") == false):
		get_tree().paused = false  # Unpauses the game
		
	
	if payload.get("start_song"):
		Rhythia.restart_on_death = false
		Rhythia.start_offset = 0
		Rhythia.mod_nofail = true
		Rhythia.mod_sudden_death = false
		Rhythia.disable_pausing = true
		Rhythia.visual_mode = false
		
		Rhythia.note_hitbox_size = 1.14
		Rhythia.hitwindow_ms = 55
		Rhythia.speed_hitwindow = true

		Rhythia.custom_speed = payload.get("custom_speed")
		Rhythia.mod_speed_level = payload.get("mod_speed_level")
		Rhythia.mod_hardrock = payload.get("mod_hardrock")
		Rhythia.mod_ghost = payload.get("mod_ghost")
		Rhythia.mod_chaos = payload.get("mod_chaos")
		Rhythia.mod_earthquake = payload.get("mod_earthquake")
		Rhythia.mod_flashlight = payload.get("mod_flashlight")
		Rhythia.mod_nearsighted = payload.get("mod_nearsighted")
			
		var song:Song = Song.new()
		var result = song.load_from_sspm(payload.get("start_song"))
		Rhythia.selected_song = song
		yield(get_tree().create_timer(0.5),"timeout")
		get_tree().change_scene("res://scenes/loaders/songload.tscn")
	
	if payload.get("import_song"):
		var song
		song = Song.new()
		song.load_from_sspm(payload.get("import_song"))
		var result = song.convert_to_sspm()
		if result == "Converted!":
			Rhythia.registry_song.check_and_remove_id(song.id)
			song = Rhythia.registry_song.add_sspm_map("user://maps/%s.sspm" % song.id)
		var list = $"/root/Menu/Main/Maps/MapRegistry/S/VBoxContainer"
		list.prepare_songs()
		list.build_list()
		if song:
			Rhythia.select_song(song)
			list.switch_to_play_screen()



### **Sending Data**

# Sends a packet via the WebSocket
func send(packet = ""):
	print("SENDING PACKET:" + packet)
	"""
	Sends a JSON-formatted packet to the WebSocket server.

	- Parameters:
	  - `packet` (String): The JSON-formatted data to send.
	"""
	_wsClient.get_peer(1).set_write_mode(WebSocketPeer.WRITE_MODE_TEXT)
	_wsClient.get_peer(1).put_packet(packet.to_utf8())


func send_map_select():
	send(
		JSON.print(
			{
				# Identifiers
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "map_select",
				
				# Basis
				"song_name": Rhythia.selected_song.name,
				"song_id": Rhythia.selected_song.id,
				"song_path": Rhythia.selected_song.filePath,
				
				# Mods
				"start_offset": Rhythia.start_offset,
				"note_hitbox_size": Rhythia.note_hitbox_size,
				"hitwindow_ms": Rhythia.hitwindow_ms,
				"custom_speed": Rhythia.custom_speed,
				"health_model": Rhythia.health_model,
				"grade_system": Rhythia.grade_system,
				"visual_mode": Rhythia.visual_mode,
				"invert_mouse": Rhythia.invert_mouse,
				"disable_pausing": Rhythia.disable_pausing,
				"speed_hitwindow": Rhythia.speed_hitwindow,
				"restart_on_death": Rhythia.restart_on_death,
				"mod_extra_energy": Rhythia.mod_extra_energy,
				"mod_no_regen": Rhythia.mod_no_regen,
				"mod_speed_level": Rhythia.mod_speed_level,
				"mod_nofail": Rhythia.mod_nofail,
				"mod_mirror_x": Rhythia.mod_mirror_x,
				"mod_mirror_y": Rhythia.mod_mirror_y,
				"mod_nearsighted": Rhythia.mod_nearsighted,
				"mod_ghost": Rhythia.mod_ghost,
				"mod_sudden_death": Rhythia.mod_sudden_death,
				"mod_chaos": Rhythia.mod_chaos,
				"mod_earthquake": Rhythia.mod_earthquake,
				"mod_flashlight": Rhythia.mod_flashlight,
				"mod_hardrock": Rhythia.mod_hardrock,
			}
		)
	)

func send_map_progress(hits, misses, total_notes, combo, score):
	send(
		JSON.print(
			{
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "map_progress",
				"song_name": Rhythia.selected_song.name,
				"song_id": Rhythia.selected_song.id,
				"song_path": Rhythia.selected_song.filePath,
				"misses": misses,
				"hits": hits,
				"combo": combo,
				"total_notes": total_notes,
				"score": score,
			}
		)
	)

# Sends a "map_start" event
func send_map_start():
	"""
	Sends a message indicating that a map has started.
	I0ncludes details about the selected song and related replay data.
	"""
	send(
		JSON.print(
			{
				# Identifiers
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "map_start",
				
				# Basis
				"song_name": Rhythia.selected_song.name,
				"song_id": Rhythia.selected_song.id,
				"song_path": Rhythia.selected_song.filePath,
				
				
				# Mods
				"start_offset": Rhythia.start_offset,
				"note_hitbox_size": Rhythia.note_hitbox_size,
				"hitwindow_ms": Rhythia.hitwindow_ms,
				"custom_speed": Rhythia.custom_speed,
				"health_model": Rhythia.health_model,
				"grade_system": Rhythia.grade_system,
				"visual_mode": Rhythia.visual_mode,
				"invert_mouse": Rhythia.invert_mouse,
				"disable_pausing": Rhythia.disable_pausing,
				"speed_hitwindow": Rhythia.speed_hitwindow,
				"restart_on_death": Rhythia.restart_on_death,
				"mod_extra_energy": Rhythia.mod_extra_energy,
				"mod_no_regen": Rhythia.mod_no_regen,
				"mod_speed_level": Rhythia.mod_speed_level,
				"mod_nofail": Rhythia.mod_nofail,
				"mod_mirror_x": Rhythia.mod_mirror_x,
				"mod_mirror_y": Rhythia.mod_mirror_y,
				"mod_nearsighted": Rhythia.mod_nearsighted,
				"mod_ghost": Rhythia.mod_ghost,
				"mod_sudden_death": Rhythia.mod_sudden_death,
				"mod_chaos": Rhythia.mod_chaos,
				"mod_earthquake": Rhythia.mod_earthquake,
				"mod_flashlight": Rhythia.mod_flashlight,
				"mod_hardrock": Rhythia.mod_hardrock,
				"spin": Rhythia.cam_unlock,
				"grid_parallax": Rhythia.grid_parallax,
				
				
				"replaying": Rhythia.replaying,
			}
		)
	)


func send_start():
	send(
		JSON.print(
			{
				# Identifiers
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "game_start",
			}
		))
		
# Sends a "menu_state" event
func send_menu_state(menu_state = 0):
	"""
	Sends a message indicating the current state of the menu.

	- Parameters:
	  - `menu_state` (int): Represents the current state of the menu.
	"""
	send(
		JSON.print(
			{
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "menu_state",
				"state": menu_state,
				"version": 10
			}
		)
	)

# Sends a "map_end" event
func send_map_end(end_type = 0):
	"""
	Sends a message indicating that a map has ended.
	Includes performance statistics and related song information.

	- Parameters:
	  - `end_type` (int): Type of map end event (e.g., success, failure).
	"""
	send(
		JSON.print(
			{
				# Identifiers
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "map_end",
				"end_type": end_type,
				
				# Basis
				"song_name": Rhythia.selected_song.name,
				"song_id": Rhythia.selected_song.id,
				"song_path": Rhythia.selected_song.filePath,
				
				# Mods
				"start_offset": Rhythia.start_offset,
				"note_hitbox_size": Rhythia.note_hitbox_size,
				"hitwindow_ms": Rhythia.hitwindow_ms,
				"custom_speed": Rhythia.custom_speed,
				"health_model": Rhythia.health_model,
				"grade_system": Rhythia.grade_system,
				"visual_mode": Rhythia.visual_mode,
				"invert_mouse": Rhythia.invert_mouse,
				"disable_pausing": Rhythia.disable_pausing,
				"speed_hitwindow": Rhythia.speed_hitwindow,
				"restart_on_death": Rhythia.restart_on_death,
				"mod_extra_energy": Rhythia.mod_extra_energy,
				"mod_no_regen": Rhythia.mod_no_regen,
				"mod_speed_level": Rhythia.mod_speed_level,
				"mod_nofail": Rhythia.mod_nofail,
				"mod_mirror_x": Rhythia.mod_mirror_x,
				"mod_mirror_y": Rhythia.mod_mirror_y,
				"mod_nearsighted": Rhythia.mod_nearsighted,
				"mod_ghost": Rhythia.mod_ghost,
				"mod_sudden_death": Rhythia.mod_sudden_death,
				"mod_chaos": Rhythia.mod_chaos,
				"mod_earthquake": Rhythia.mod_earthquake,
				"mod_flashlight": Rhythia.mod_flashlight,
				"mod_hardrock": Rhythia.mod_hardrock,
				"pause_count": Rhythia.song_end_pause_count,
				"spin": Rhythia.cam_unlock,
				"grid_parallax": Rhythia.grid_parallax,
				
				"replaying": Rhythia.replaying,
			}
		)
	)
	
func send_mods():
	"""
	Sends a message indicating that a map has ended.
	Includes performance statistics and related song information.

	- Parameters:
	  - `end_type` (int): Type of map end event (e.g., success, failure).
	"""
	send(
		JSON.print(
			{
				# Identifiers
				"pid": OS.get_process_id(),
				"start_arguments": OS.get_cmdline_args(),
				"type": "mods",
				
				# Mods
				"start_offset": Rhythia.start_offset,
				"note_hitbox_size": Rhythia.note_hitbox_size,
				"hitwindow_ms": Rhythia.hitwindow_ms,
				"custom_speed": Rhythia.custom_speed,
				"health_model": Rhythia.health_model,
				"grade_system": Rhythia.grade_system,
				"visual_mode": Rhythia.visual_mode,
				"invert_mouse": Rhythia.invert_mouse,
				"disable_pausing": Rhythia.disable_pausing,
				"speed_hitwindow": Rhythia.speed_hitwindow,
				"restart_on_death": Rhythia.restart_on_death,
				"mod_extra_energy": Rhythia.mod_extra_energy,
				"mod_no_regen": Rhythia.mod_no_regen,
				"mod_speed_level": Rhythia.mod_speed_level,
				"mod_nofail": Rhythia.mod_nofail,
				"mod_mirror_x": Rhythia.mod_mirror_x,
				"mod_mirror_y": Rhythia.mod_mirror_y,
				"mod_nearsighted": Rhythia.mod_nearsighted,
				"mod_ghost": Rhythia.mod_ghost,
				"mod_sudden_death": Rhythia.mod_sudden_death,
				"mod_chaos": Rhythia.mod_chaos,
				"mod_earthquake": Rhythia.mod_earthquake,
				"mod_flashlight": Rhythia.mod_flashlight,
				"mod_hardrock": Rhythia.mod_hardrock,
				"spin": Rhythia.cam_unlock,
				"grid_parallax": Rhythia.grid_parallax,
				
			}
		)
	)


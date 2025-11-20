extends Node

const HELPER_VERSION_URL = "https://github.com/cunev/rhythia-online-release/releases/download/packaged-experimental-bun/rhythia-online-runtime-version.txt"
const HELPER_DOWNLOAD_URL = "https://github.com/cunev/rhythia-online-release/releases/download/packaged-experimental-bun/rhythia-online-runtime.exe"
const HELPER_PATH = "user://helper"
const VERSION_FILE = "user://helper_version.txt"

var http_request: HTTPRequest
var downloading = false
var current_version = ""
var remote_version = ""  # Added to store the remote version

func _ready():
	get_tree().change_scene("res://scenes/loaders/onlineload.tscn")
	
	pause_mode = Node.PAUSE_MODE_PROCESS
	get_tree().paused = false
	print("Initializing updater...")
	
	# Create HTTP request node
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.connect("request_completed", self, "_on_request_completed")
	
	# Start update process
	check_for_updates()

func check_for_updates():
	close_existing_processes()
	
	print("Checking for updates...")
	# Pause the game tree
	get_tree().paused = true
	
	print(VERSION_FILE)
	var file = File.new()
	if not file.file_exists(VERSION_FILE):
		start_download()
		return
		
	file.open(VERSION_FILE, File.READ)
	current_version = file.get_as_text().strip_edges()
	file.close()
	
	http_request.request(HELPER_VERSION_URL)

func _on_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray):
	if downloading:
		_handle_download_completed(result, response_code, body)
	else:
		_handle_version_check(result, response_code, body)

func _handle_version_check(result: int, response_code: int, body: PoolByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error: Failed to check for updates")
		get_tree().paused = false  # Unpause on error
		return
		
	remote_version = body.get_string_from_utf8().strip_edges()  # Store the remote version
	
	var file = File.new()
	if file.file_exists(VERSION_FILE):
		file.open(VERSION_FILE, File.READ)
		current_version = file.get_as_text().strip_edges()
		file.close()
	
	if remote_version != current_version:
		print("Update available! Current version: %s, Remote version: %s" % [current_version, remote_version])
		start_download()
	else:
		print("Already up to date!")
		get_tree().paused = false  # Unpause if no update needed
		launch_helper()

func start_download():
	print("Starting download...")
	downloading = true
	get_tree().paused = true
	
	var dir = Directory.new()
	dir.make_dir_recursive(OS.get_user_data_dir().plus_file("helper"))
	
	http_request.download_file = OS.get_user_data_dir().plus_file("helper/rhythia-online-runtime.exe")
	http_request.request(HELPER_DOWNLOAD_URL)


func restart_game():
	print("Restarting game...")
	get_tree().quit()

func _handle_download_completed(result: int, response_code: int, body: PoolByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		print("Error: Download failed")
		get_tree().paused = false  # Unpause on error
		return
		
	print("Download complete, extracting files...")
		
	# Store the new remote version after successful update
	var version_file = File.new()
	version_file.open(VERSION_FILE, File.WRITE)
	version_file.store_string(remote_version)  # Store remote_version instead of current_version
	version_file.close()

	# Only unpause after successful update
	get_tree().paused = false
	close_existing_processes()
	restart_game()
	print("Game unpaused - update complete")
	
	launch_helper()

func close_existing_processes():
	if OS.get_name() == "Windows":
		# Safely terminate tosu_overlay.exe
		OS.execute("taskkill", ["/F", "/IM", "tosu_overlay.exe"], true)
		# Safely terminate node.exe
		OS.execute("taskkill", ["/F", "/IM", "rhythia-online-runtime.exe"], true)
	else:
		# Unix-like systems
		OS.execute("killall", ["-9", "tosu_overlay"], true)
		OS.execute("killall", ["-9", "rhythia-online-runtime"], true)

func launch_helper():
	print("Launching helper module...")
	
	# First close any existing processes
	close_existing_processes()
	
	
	
	var helper_path = OS.get_user_data_dir().plus_file("helper/rhythia-online-runtime")
	
	print("Node path: ", helper_path)
	
	var output = []
	var exit_code
	get_tree().paused = false
	
	Socket.initialize_socket()

	if OS.get_name() == "Windows":
		helper_path += ".exe"
		# Using the START command with /MIN to minimize and /B to run in background
		exit_code = OS.execute("cmd", [
			"/c", 
			"start", 
			"/MIN",
			"/B",
			"\"NodeHelper\"",  # Window title (required when using start)
			helper_path
		], false)
	else:
		exit_code = OS.execute("nohup", [helper_path, "&"], false)

	if exit_code != 0:
		print("Error: Failed to launch helper module")
		if not output.empty():
			print("Output: ", output)
		return

	print("Helper module launched successfully")
# Handle download progress

var downloadProgress = 0;
func _process(_delta):
	if downloading and http_request.get_downloaded_bytes() > 0:
		var progress = float(http_request.get_downloaded_bytes()) / http_request.get_body_size() * 100
		downloadProgress = progress
		get_tree().paused = true

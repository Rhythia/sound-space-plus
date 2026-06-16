extends Resource
class_name Song

signal downloaded

var id:String
var name:String
var song:String
var creator:String

var difficulty:int = Globals.DIFF_UNKNOWN
var rating:int = 0 # Star rating

var markers:Dictionary = {}
var marker_types:Array = []
var custom_data:Dictionary = {}

var rawData:String = ""
var notes:Array
var note_count:int
var marker_count:int
var musicFile:String = ""
var last_ms:float = 0
var source_registry:String = "[unknown]"
var warning:String = ""

var marker_hash:PoolByteArray

var should_reload_on_play:bool = false
var songType:int = -1
var initFile:String = ""

var filePath:String

var cover:Texture setget , _get_cover
var has_cover:bool = false
var cover_offset:int = -1
var cover_length:int = -1
var is_broken:bool = false
var converted:bool = false

var is_builtin:bool = false

var is_online:bool = false
var download_url:String = ""
var has_combo:bool

var sspm_song_stored:bool = false

var pbs_loaded:bool = false
var pb_data:Dictionary = {}

const hash_chunk_size = 1024

enum {
	DT_UNKNOWN = 0x00
	DT_INT_8 = 0x01 # Unsigned
	DT_INT_16 = 0x02 # Unsigned
	DT_INT_32 = 0x03 # Unsigned
	DT_INT_64 = 0x04 # Unsigned
	DT_FLOAT_32 = 0x05
	DT_FLOAT_64 = 0x06
	DT_POSITION = 0x07
	DT_BUFFER = 0x08
	DT_STRING = 0x09
	DT_BUFFER_LONG = 0x0a
	DT_STRING_LONG = 0x0b
	DT_ARRAY = 0x0c
}

func _get_cover():
	if !has_cover:
		return
	if is_instance_valid(cover):
		return cover
	var file = File.new()
	var err = file.open(filePath,File.READ)
	if err != OK:
		print(err)
	file.seek(cover_offset)
	if songType == Globals.MAP_SSPM:
		var ct = file.get_8()
		if ct == 1 or ct == 2:
			var img:Image = Image.new()
			if ct == 1:
				var h:int = file.get_16()
				var w:int = file.get_16()
				var mip:bool = bool(file.get_8())
				var format:int = file.get_8()
				var clen:int = file.get_64()
				var cbuf:PoolByteArray = file.get_buffer(clen)
				img.create_from_data(w,h,mip,format,cbuf)
				var imgtex:ImageTexture = ImageTexture.new()
				imgtex.create_from_image(img)
				cover = imgtex
			elif ct == 2:
				var clen:int = file.get_64()
				var cbuf:PoolByteArray = file.get_buffer(clen)
				cover = Globals.imageLoader.load_buffer(cbuf) as ImageTexture
	elif songType == Globals.MAP_SSPM2:
		var cbuf:PoolByteArray = file.get_buffer(cover_length)
		cover = Globals.imageLoader.load_buffer(cbuf) as ImageTexture
	file.close()
#	cover.call_deferred("unreference")
	return cover

func is_valid_id(txt:String):
	return !(
		(txt.to_lower() != txt) or 
		(txt.length() == 0) or 
		txt.begins_with("_") or 
		!(("n" + txt).replace("-","")).is_valid_identifier()
	)

const db_builtin_difficulty_names = [
	"N/A",
	"Easy",
	"Medium",
	"Hard",
	"LOGIC?",
	"助 (Tasukete)"
]

func load_from_db_data(data:Dictionary={
		"id":"INVALID_id_that_doesnt_exist",
		"download":"http://chedski.test/ssp/mapdb/api/download/INVALID_id_that_doesnt_exist",
		"audio":"http://chedski.test/ssp/mapdb/api/audio/INVALID_id_that_doesnt_exist",
#		"id":"ss_archive_waterflame_-_geometrical_dominator",
#		"download":"http://chedski.test/ssp/mapdb/api/download/ss_archive_waterflame_-_geometrical_dominator",
#		"audio":"http://chedski.test/ssp/mapdb/api/audio/ss_archive_waterflame_-_geometrical_dominator",
		"cover":null,
		"version":1,
		"name":"000000 net test map",
		"song":"Waterflame - Geometrical Dominator",
		"author":["Azurlexx"],
		"difficulty":3,
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
		"music_length":1594095
	}):
	
	if !data.has("id"): return {success=false,error="Missing id"}
	if !data.has("name"): return {success=false,error="Missing name"}
	if !data.has("author"): return {success=false,error="Missing author"}
	if !data.has("version"): return {success=false,error="Missing version"}
	if !data.has("difficulty"): return {success=false,error="Missing difficulty"}
	if !data.has("difficulty_name"): return {success=false,error="Missing difficulty_name"}
#	if !data.has("length_ms"): return {success=false,error="Missing length_ms"}
#	if !data.has("note_count"): return {success=false,error="Missing note_count"}
	if !data.has("download"): return {success=false,error="Missing download"}
	
	if typeof(data.id) != TYPE_STRING: return {success=false,error="Invalid id"}
	if typeof(data.name) != TYPE_STRING: return {success=false,error="Invalid name"}
	if typeof(data.author) != TYPE_ARRAY: return {success=false,error="Invalid author"}
	if typeof(data.difficulty) != TYPE_INT and typeof(data.difficulty) != TYPE_REAL: return {success=false,error="Invalid difficulty"}
	if typeof(data.version) != TYPE_INT and typeof(data.version) != TYPE_REAL: return {success=false,error="Invalid version"}
#	if typeof(data.length_ms) != TYPE_INT and typeof(data.length_ms) != TYPE_REAL: return {success=false,error="Invalid length_ms"}
#	if typeof(data.note_count) != TYPE_INT and typeof(data.note_count) != TYPE_REAL: return {success=false,error="Invalid note_count"}
	if typeof(data.download) != TYPE_STRING or !Globals.is_valid_url(data.download): return {success=false,error="Invalid download"}
	
	if !is_valid_id(data.id): return {success=false,error="Invalid id (2)"}
	if data.difficulty < -1 or data.difficulty > 4: return {success=false,error="Difficulty out of bounds"}
	
	if !db_builtin_difficulty_names.has(data.difficulty_name):
		custom_data = {difficulty_name = data.difficulty_name}
	
	id = data.id
	name = data.name
	song = data.name
	var authorstr = ""
	for a in data.author:
		if a != data.author[0]: authorstr += " & "
		authorstr += a
	creator = authorstr
	difficulty = int(data.difficulty)
	last_ms = float(data.length_ms)
	note_count = int(data.note_count)
	download_url = data.download
	is_online = true
	is_broken = data.get("broken",false)
	
	return {success=true}

func load_pbs():
	if Rhythia.single_map_mode:
		return
	var file:File = File.new()
	if file.file_exists(Globals.p("user://bests/%s" % id)):
		var err:int = file.open(Globals.p("user://bests/%s" % id),File.READ)
		if err != OK:
			return
		
		if file.get_buffer(5) != PoolByteArray([0x53,0x53,0x2B,0x70,0x42]):
			print("invalid signature for pb file (%s)" % id)
			file.close()
			return
		
		var sv:int = file.get_16()
		if sv > 3:
			print("invalid file version for pb file (%s)" % id)
			file.close()
			return
			
		if sv < 3: has_combo = false
		else: has_combo = true
		
		var amt:int = file.get_64() # number of bests stored
		
		for i in range(amt):
			var pb:Dictionary = {}
			var s:String = file.get_line()
			# if sv == 1: s = s.replace("1.27","1.14") # handle the default hitbox change
			# this line was literally giving people free silent aim what
			
			pb.has_passed = bool(file.get_8())
			pb.pauses = file.get_16()
			pb.hit_notes = file.get_32()
			pb.total_notes = file.get_32()
			pb.position = file.get_32()
			pb.length = file.get_32()
			
			if has_combo: pb.max_combo = file.get_16()
			else: pb.max_combo = -1
			
			pb_data[s] = pb
			
		file.close()

func save_pbs():
	if Rhythia.single_map_mode:
		return
	var file:File = File.new()
	var err:int = file.open(Globals.p("user://bests/%s") % id,File.WRITE)
	if err != OK:
		print("error writing pb file for %s:  %s" % [id, String(err)])
		return
	file.store_buffer(PoolByteArray([0x53,0x53,0x2B,0x70,0x42]))
	file.store_16(3) # version
	file.store_64(pb_data.size()) # number of PBs
	for k in pb_data.keys():
		var pb:Dictionary = pb_data[k]
		file.store_line(k)
		file.store_8(int(pb.has_passed))
		file.store_16(pb.pauses)
		
		file.store_32(pb.hit_notes)
		file.store_32(pb.total_notes)
		# prevent the 69420:00 bug (hacky but it should work)
		if pb.has_passed: file.store_32(floor(pb.length))
		else: file.store_32(floor(min(pb.length,pb.position)))
		file.store_32(floor(pb.length))

		file.store_16(pb.max_combo)		
		
	file.close()

func get_pb(pb_str:String):
	if !pbs_loaded: load_pbs()
	return pb_data.get(pb_str,{})

func is_pb_better(ob:Dictionary,pb:Dictionary):
	# ensure everything exists on ob
	ob.has_passed = ob.get("has_passed",false)
	ob.total_notes = ob.get("total_notes",4294967295)
	ob.hit_notes = ob.get("hit_notes",0)
	ob.pauses = ob.get("pauses",65535)
	ob.position = ob.get("position",0)
	ob.length = ob.get("length",1)
	
	if int(pb.has_passed) < int(ob.has_passed): return false # pass -> fail
	elif int(pb.has_passed) > int(ob.has_passed): return true # fail -> pass
	
	if !pb.has_passed:
		if pb.position > ob.position: return true # made more progress
		elif pb.position < ob.position: return false # made less progress
	var pbm = pb.total_notes - pb.hit_notes
	var obm = ob.total_notes - ob.hit_notes
	
	if pbm < obm: return true # fewer misses
	elif pbm > obm: return false # more misses
	
	if pb.pauses < ob.pauses: return true # fewer pauses
	elif pb.pauses > ob.pauses: return false # more pauses

func set_pb_if_better(pb_str:String,pb:Dictionary):
	if Rhythia.single_map_mode:
		return false
	if !pbs_loaded: load_pbs()
	var ob:Dictionary = get_pb(pb_str)
	
	if is_pb_better(ob,pb):
		pb_data[pb_str] = pb
		save_pbs()
		return true
	else: return false

func get_music_buffer():
	var file2:File = File.new()
	if songType == Globals.MAP_SSPM:
		print("[sspm] %s: reading audio buffer" % id)
		var err = file2.open(filePath,File.READ)
		if err == OK:
			file2.seek(8) # Skip over header data
			file2.get_line() # Skip over metadata
			file2.get_line()
			file2.get_line()
			file2.seek(file2.get_position() + 9)
			
			var ct = file2.get_8()
			if ct == 1: # Skip over cover
				file2.seek(file2.get_position() + 6)
				var clen = file2.get_64()
				file2.seek(file2.get_position() + clen)
			elif ct == 2:
				var clen = file2.get_64()
				file2.seek(file2.get_position() + clen)
			
			if file2.get_8() != 1:
				file2.close()
				print("[sspm] %s: No music present!" % id)
				return null
			else:
				var blen:int = file2.get_64()
				var buf:PoolByteArray = file2.get_buffer(blen) # Actual song data
				file2.close()
				print("[sspm] %s: music ok" % id)
				return buf
		else:
			print("[sspm] %s: Error while loading music! err was %s" % [id, err])
			return null
	elif songType == Globals.MAP_SSPM2:
		print("[sspm2] %s: reading audio buffer" % id)
		var err = file2.open(filePath,File.READ)
		if err == OK:
			file2.seek(0x2d) # Skip over header data
			
			if file2.get_8() != 1:
				file2.close()
				print("[sspm2] %s: No music present!" % id)
				return null
			else:
				file2.seek(0x40)
				var bpos:int = file2.get_64()
				var blen:int = file2.get_64()
				file2.seek(bpos)
				var buf:PoolByteArray = file2.get_buffer(blen) # Actual song data
				file2.close()
				print("[sspm2] %s: music ok" % id)
				return buf
		else:
			print("[sspm2] %s: Error while loading music! err was %s" % [id, err])
			return null
	else:
		var err = file2.open(musicFile,File.READ)
		if err != OK:
			print("[file] %s: Failed to open music file!" % id)
			return null
		else:
			var mdata:PoolByteArray = file2.get_buffer(file2.get_len())
			file2.close()
			print("[file] %s: music ok" % id)
			return mdata

func stream() -> AudioStream:
	if sspm_song_stored || !musicFile.begins_with("res://"):
		var buf = get_music_buffer()
		if buf:
			var s = Globals.audioLoader.load_buffer(buf)
			if s is AudioStreamOGGVorbis or s is AudioStreamMP3: s.loop = false
			if s: return s
			else: return Globals.error_sound
		else:
			return Globals.error_sound
#	elif !musicFile.begins_with("res://"):
#		var stream = Globals.audioLoader.load_file(musicFile)
#		if stream: return stream
#		else: return Globals.error_sound
	else: 
		var mf:AudioStream = load(musicFile) as AudioStream
		if mf is AudioStreamOGGVorbis or mf is AudioStreamMP3: mf.loop = false
		elif mf is AudioStreamSample: mf.loop_mode = AudioStreamSample.LOOP_DISABLED
		return mf

func loadFromFile(path:String):
	initFile = path
	var file:File = File.new()
	var err = file.open(path,File.READ)
	if err != OK:
		warning = "[txt map] File could not be opened - returned error " + String(err)
		return
	rawData = file.get_as_text()
	file.close()

func loadRawData(data:String):
	rawData = data
	var blank = 0
	var invalid = 0
	var split:Array = rawData.split(",")
	split.remove(0)
	notes = []
	for s in split:
		if s != "":
			var dat = s.split("|")
			if (dat is Array or dat is PoolStringArray) and dat.size() == 3:
				var x = 2 - float(dat[0])
				var y = 2 - float(dat[1])
				var ms = float(dat[2])
				last_ms = ms
				notes.append([x,y,ms])
			else: invalid += 1
		else: blank += 1
	var file = File.new()
	if !file.file_exists(musicFile) and !musicFile.begins_with("res://"):
		warning = "[txt map] Audio file doesn't exist!"
		is_broken = true
	elif invalid != 0: warning = "[txt map] Song has %s invalid note(s)" % String(invalid)
	elif blank != 0: warning = "[txt map] Song has %s blank note(s)" % String(blank)
	else:
		warning = ""
		is_broken = false
#	notes.sort_custom(self,"notesort")
	note_count = notes.size()

func loadVulnusNoteArray(vNotes:Array):
	notes = []
	var invalid = 0
	for n in vNotes:
		if n.get("_time") != null and n.get("_x") != null and n.get("_y") != null:
			var ms = n._time*1000
			var x = 2 - (n._x + 1)
			var y = 2 - (n._y + 1)
			last_ms = ms
			notes.append([x,y,ms])
		else: invalid += 1
	var file = File.new()
	if !file.file_exists(musicFile) and !musicFile.begins_with("res://"):
		warning = "[vulnus map] Audio file doesn't exist!"
		is_broken = true
	elif invalid != 0: warning = "[vulnus map] Song has %s invalid note(s)" % String(invalid)
#	notes.sort_custom(self,"notesort")
	note_count = notes.size()

func setup_from_file(mapFile:String,songFile:String):
	songType = Globals.MAP_TXT
	initFile = mapFile
	musicFile = songFile
	if songFile.begins_with("res://") or mapFile.begins_with("res://"):
		is_builtin = true
	loadFromFile(mapFile)
	if rawData: loadRawData(rawData)
	return self

func setup_from_data(mapData:String,songFile:String):
	songType = Globals.MAP_RAW
	musicFile = songFile
	if songFile.begins_with("res://"):
		is_builtin = true
	loadRawData(mapData)
	return self


func setup_from_vulnus_json(jsonPath:String,songFile:String,useDifficultyName:bool=false):
	print("PARSING VULNUS JSON: " + jsonPath)
	songType = Globals.MAP_VULNUS
	musicFile = songFile
	filePath = jsonPath
	var file = File.new()
	file.open(jsonPath,File.READ)
	var json = file.get_as_text()
	file.close()
	var dn = json.find('"_name":')
	if dn && dn > 0:
		var nq_open = json.find('"',dn + 7)
		var nq_close = json.find('",',nq_open)
		var diffname = json.substr(nq_open + 1, nq_close - (nq_open + 1))
		custom_data.difficulty_name = diffname
	
	note_count = json.count('"_time"')
	if note_count != 0:
		var last = json.find_last('"_time":')
		var comma = json.find(",",last)
		var time_str:String = json.substr(last+8,comma-last-8).trim_prefix(" ")
		if !time_str.is_valid_float():
			warning = "[vulnus map] Couldn't read final timestamp!"
			is_broken = true
			return self
		var ms = float(time_str)*1000
		last_ms = ms
		return self
	else:
		warning = "[vulnus map] Song has no notes!"
		is_broken = true
		return self


const valid_chars = "0123456789abcdefghijklmnopqrstuvwxyz_-"
func generate_vmapimp_id(sname:String,dname:String,useDifficultyName:bool=false):
	var txt:String = "vmapimp_"
	for i in range(sname.length()):
		if sname.to_lower()[i].is_subsequence_of(valid_chars):
			txt += sname.to_lower()[i]
		elif sname[i] == " " and txt[txt.length()-1] != "_": txt += "_"
	if useDifficultyName:
		txt += "_"
		for i in range(dname.length()):
			if dname.to_lower()[i].is_subsequence_of(valid_chars):
				txt += dname.to_lower()[i]
			elif dname[i] == " " and txt[txt.length()-1] != "_": txt += "_"
	return txt.trim_prefix("_").trim_suffix("_")

func load_from_vulnus_map(folder_path:String,difficulty_id:int=0):
	var file:File = File.new()
	if !file.file_exists(folder_path + "/meta.json"): return
	
	var err = file.open(folder_path + "/meta.json",File.READ)
	if err != OK: return
	var meta_json:String = file.get_as_text()
	file.close()
	var meta:Dictionary = parse_json(meta_json)
	
	var artist:String = meta.get("_artist","Unknown Artist")
	var difficulties:Array = meta.get("_difficulties",[])
	var mappers:Array = meta.get("_mappers",[])
	var music_path:String = meta.get("_music","**missing**")
	var title:String = meta.get("_title","Unknown Song")
	
	song = "%s - %s" % [artist,title]
	
	if difficulties.size() <= difficulty_id: return
	if music_path == "**missing**" or !music_path.is_valid_filename(): return
	if mappers.size() == 0: mappers = ["Unknown"]
	
	if !file.file_exists(folder_path + "/" + music_path): return
	if !file.file_exists(folder_path + "/" + difficulties[difficulty_id]): return
	var diff = Globals.DIFF_UNKNOWN
	if difficulties[difficulty_id] == "official.json":
		var audioid = int(music_path.split(".")[0])
		diff = Globals.official_map_difficulties.get(audioid,Globals.DIFF_UNKNOWN)
	
	var conc:String = ""
	for i in range(mappers.size()):
		if i != 0: conc += ", "
		conc += mappers[i]
	creator = conc
	
	#var song:Song = Song.new(id,,conc)
	setup_from_vulnus_json(folder_path + "/" + difficulties[difficulty_id], folder_path + "/" + music_path)
	id = generate_vmapimp_id(title,custom_data.get("difficulty_name",String(difficulty_id)), difficulty_id != 0)
	
	if difficulties.size() != 1:
		name = "%s - %s [%s]" % [artist,title,custom_data.get("difficulty_name",String(difficulty_id))]
	else:
		name = song
	
	difficulty = diff
	
	var c = Globals.imageLoader.load_if_exists(folder_path + "/cover.png")
	if c:
		cover = c
		has_cover = true
	
	return self

func get_vulnus_map_difficulty_list(folder_path:String):
	var file:File = File.new()
	if !file.file_exists(folder_path + "/meta.json"): return []
	
	var err = file.open(folder_path + "/meta.json",File.READ)
	if err != OK: return []
	var meta_json:String = file.get_as_text()
	file.close()
	var meta:Dictionary = parse_json(meta_json)
	
	var difficulties:Array = meta.get("_difficulties",[])
	if difficulties.size() == 0: return []
	
	var names = []
	
	for i in range(difficulties.size()):
		var p = difficulties[i]
		file.open(folder_path + "/" + p,File.READ)
		var json = file.get_as_text()
		file.close()
		var dn = json.find('"_name":')
		if dn > 0:
			var nq_open = json.find('"',dn + 7)
			var nq_close = json.find('",',nq_open)
			var diffname = json.substr(nq_open + 1, nq_close - (nq_open + 1))
			names.append(diffname)
		else:
			names.append("NAMELESS_DIFFICULTY_%d" % i)
	
	return names



func notesort(a,b):
	if a[2] == b[2]:
		if a[1] == b[1]: return a[0] < b[0]
		return a[1] < b[1]
	return a[2] < b[2]

func markersort(a,b):
	return a[-1] < b[-1]

func read_notes() -> Array:
	if songType == Globals.MAP_TXT:
		discard_notes()
	if notes.size() == 0:
		if (songType == Globals.MAP_RAW or songType == Globals.MAP_TXT):
			if songType == Globals.MAP_TXT:
				print("Reading: TXT")
				loadFromFile(initFile)
			else: print("Reading: RAW")
			loadRawData(rawData)
			print(notes.size())
			notes.sort_custom(self,"notesort")
			markers.ssp_note = notes
			return notes
		elif songType == Globals.MAP_VULNUS:
			print("Reading: VULNUS")
			var file = File.new()
			file.open(filePath,File.READ)
#			print(filePath)
			var json = file.get_as_text()
			file.close()
			var data:Dictionary = parse_json(json)
#			print(data.has("_notes"))
			var n:Array = data.get("_notes",[])
#			print(n.size())
			loadVulnusNoteArray(n)
			notes.sort_custom(self,"notesort")
			markers.ssp_note = notes
			return notes
		elif songType == Globals.MAP_SSPM:
			print("Reading: SSPM")
			var file:File = File.new()
			var err = file.open(filePath,File.READ)
			if err != OK:
				print("error opening file")
				return []
			
			file.seek(8) # Skip over header data
			file.get_line() # Skip over metadata
			file.get_line()
			file.get_line()
			file.seek(file.get_position() + 4)
			note_count = file.get_32()
			file.seek(file.get_position() + 1)
			
			var ct = file.get_8()
			if ct == 1: # Skip over cover
				file.seek(file.get_position() + 6)
				var clen = file.get_64()
				file.seek(file.get_position() + clen)
			elif ct == 2:
				var clen = file.get_64()
				file.seek(file.get_position() + clen)
			
			if file.get_8() != 1:
				print("no music?")
#				file.close()
#				return []
			else:
				file.seek(file.get_position() + file.get_64() + 8) # Skip over music
			
			# Note data
			for i in range(note_count):
				var n = [0,0,-1]
				n[2] = file.get_32()
				if file.get_8() == 1:
					# Note is off-grid (Quantum!)
					n[0] = file.get_float()
					n[1] = file.get_float()
				else:
					# Note is on-grid (boring and unfun)
					n[0] = float(file.get_8())
					n[1] = float(file.get_8())
				notes.append(n)
			notes.sort_custom(self,"notesort")
				
			file.close()
		elif songType == Globals.MAP_SSPM2:
			print("Reading: SSPM2")
			var markers = read_markers()
			notes = markers.get("ssp_note",[])
			return notes
			
	markers.ssp_note = notes
	return notes

func read_markers() -> Dictionary:
	if songType == Globals.MAP_SSPM2:
		markers = {}
		
		var mt_name:Array = []
		mt_name.resize(marker_types.size())
		
		var mt_type:Array = []
		mt_type.resize(marker_types.size())
		
		var mt_size:Array = []
		mt_size.resize(marker_types.size())
		
		for i in range(marker_types.size()):
			var mt:Array = marker_types[i]
			mt_name[i] = mt[0]
			mt_size[i] = 0
			markers[mt[0]] = []
			
			var mtt = []
			mtt.resize(mt.size() - 1)
			mt_type[i] = mtt
			for j in range(1,mt.size()):
				mtt[j-1] = mt[j]
				
				if mt[j] == DT_POSITION:
					mt_size[i] += 2
				else:
					mt_size[i] += 1
		
		var file:File = File.new()
		var err = file.open(filePath,File.READ)
		if err != OK:
			print("error opening file")
			return markers
		
		file.seek(0x70)
		file.seek(file.get_64())
		
		for i in range(marker_count):
			var m:Array = []
			var ms = file.get_32()
			
			var type_id = file.get_8()
			var name:String = mt_name[type_id]
			var data:Array = mt_type[type_id]
			m.resize(mt_size[type_id] + 1)
			
			
			var offset = 0
			m[mt_size[type_id]] = ms # ms timestamp
			
			for ti in range(data.size()):
				var v = read_data_type(
					file,
					true,
					false,
					data[ti] # type
				)
				
				if data[ti] == DT_POSITION:
					m[ti + offset] = v.x
					offset += 1
					m[ti + offset] = v.y
				else:
					m[ti + offset] = v
			
			markers[name].append(m)
		
		for arr in markers.values():
			arr.sort_custom(self,"markersort")
#			print(String(arr.slice(0,35)).replace("], ","],\n "))
		
		return markers
	else:
		markers = {
			ssp_note = read_notes()
		}
		marker_types = [
			["ssp_note", DT_POSITION]
		]
		return markers

func discard_notes():
	if songType != Globals.MAP_RAW:
		markers = {}
		notes = []
		rawData = "" 

func change_difficulty(to:int):
	if songType == Globals.MAP_SSPM:
		if Globals.difficulty_names.get(to,null) == null:
			print("invalid difficulty")
			return ERR_INVALID_PARAMETER
		
		var file:File = File.new()
		var err = file.open(filePath,File.READ_WRITE)
		if err != OK:
			print("file open failed: ",err)
			return err
		
		if file.get_buffer(4) != PoolByteArray([0x53,0x53,0x2b,0x6d]): # signature
			print("invalid sspm file")
			return ERR_INVALID_DATA
		
		if file.get_16() != 1 or file.get_16() != 0: # version, reserved header
			print("invalid version or reserved header")
			return ERR_INVALID_DECLARATION
		
		file.get_line() # id
		file.get_line() # name
		file.get_line() # creator
		file.seek(file.get_position() + 8) # skip over map length and note count
		
		difficulty = to
		file.store_8(difficulty + 1)
		file.close()
		return OK
	
	elif songType == Globals.MAP_SSPM2:
		if Globals.difficulty_names.get(to,null) == null:
			print("invalid difficulty")
			return ERR_INVALID_PARAMETER
		
		var file:File = File.new()
		var err = file.open(filePath,File.READ_WRITE)
		if err != OK:
			print("file open failed: ",err)
			return err
		
		if file.get_buffer(4) != PoolByteArray([0x53,0x53,0x2b,0x6d]): # signature
			print("invalid sspm file")
			return ERR_INVALID_DATA
		
		if file.get_16() != 2 or file.get_32() != 0: # version, reserved header
			print("invalid version or reserved header")
			return ERR_INVALID_DECLARATION
		
		file.seek(0x2a)
		difficulty = to
		file.store_8(difficulty + 1)
		file.close()
		return OK
	
	else: 
		print("tried to change difficulty of a non .sspm map")
		return ERR_UNAVAILABLE

func convert_to_sspm_v1():
	var file:File = File.new()
	var dir:Directory = Directory.new()
	# Figure out the path and make sure it's usable
	var path:String = Globals.p("user://maps/%s.sspm") % id
	if !dir.dir_exists(Globals.p("user://maps")): dir.make_dir(Globals.p("user://maps"))
	if file.file_exists(path): return "File already exists!"
	# Open the file for writing
	var err = file.open(path,File.WRITE)
	if err != OK: return "file.open errored - code " + String(err)
	
	# Header
	file.store_buffer(PoolByteArray([0x53,0x53,0x2b,0x6d])) # File signature
	file.store_16(1) # File type version
	file.store_16(0) # Reserved for future things
	
	# General metadata
	file.store_line(id) # Song ID
	file.store_line(name) # Song name
	file.store_line(creator) # Song name
	
	# Map metadata
	var notes:Array = read_notes()
	note_count = notes.size()
	if notes.size() != 0:
		last_ms = notes[notes.size()-1][2]
	else: last_ms = 0
	file.store_32(last_ms) # Map length
	file.store_32(note_count) # Map note count
	file.store_8(difficulty + 1)
	
	var file2:File = File.new()
	# Cover
	if has_cover and cover and (cover.get_height() + cover.get_width()) >= 9:
		file.store_8(2)
		var img:Image = cover.get_data()
		var data:PoolByteArray = img.save_png_to_buffer()
		file.store_64(data.size()) # Buffer length in bytes
		file.store_buffer(data) # Actual cover data
	else: file.store_8(0)
	
	# Audio
	var musicBuffer = get_music_buffer()
	if !musicBuffer:
		file.store_8(0)
	else:
		file.store_8(1)
		file2.close()
		file.store_64(musicBuffer.size())
		file.store_buffer(musicBuffer)
	
	# Note data
	for n in notes:
		file.store_32(floor(n[2]))
		if floor(n[0]) != n[0] or floor(n[1]) != n[1]:
			file.store_8(1)
			file.store_float(n[0])
			file.store_float(n[1])
		else:
			file.store_8(0)
			file.store_8(n[0])
			file.store_8(n[1])
	
	file.close() # All done! No need for an external converter, unlike Vulnus :3
	converted = true
	return "Converted!"

func check_if_modded():
	# Mod developers need to override this themselves if they're handling map stuff
	return false

func auto_data_type(value) -> int:
	if typeof(value) == TYPE_INT:
		if value < 0: return DT_FLOAT_64
		elif value < 2^8: return DT_INT_8
		elif value < 2^16: return DT_INT_16
		elif value < 2^32: return DT_INT_32
		else: return DT_INT_64
		
	elif typeof(value) == TYPE_REAL:
		return DT_FLOAT_64
		
	elif typeof(value) == TYPE_STRING:
		if value.to_utf8().size() < 2^16: return DT_STRING
		else: return DT_STRING_LONG
		
	elif typeof(value) == TYPE_RAW_ARRAY:
		if value.size() < 2^16: return DT_BUFFER
		else: return DT_BUFFER_LONG
		
	elif typeof(value) == TYPE_VECTOR2:
		return DT_POSITION
		
	elif typeof(value) == TYPE_ARRAY:
		return DT_ARRAY
		
	return DT_UNKNOWN

func store_data_type(file:File, type:int, value, skip_type:bool = false, array_type:int = DT_UNKNOWN, skip_array_type:bool = true):
	match type:
		DT_INT_8:
			if !skip_type:
				file.store_8(type)
			file.store_8(value)
		DT_INT_16:
			if !skip_type:
				file.store_8(type)
			file.store_16(value)
		DT_INT_32:
			if !skip_type:
				file.store_8(type)
			file.store_32(value)
		DT_INT_64:
			if !skip_type:
				file.store_8(type)
			file.store_64(value)
		DT_FLOAT_32:
			if !skip_type:
				file.store_8(type)
			file.store_float(value)
		DT_FLOAT_64:
			if !skip_type:
				file.store_8(type)
			file.store_real(value)
		DT_POSITION:
			if !skip_type: file.store_8(type)
			if floor(abs(value.x)) == value.x and floor(abs(value.y)) == value.y and value.x < 256 and value.y < 256:
				file.store_8(0)
				file.store_8(value.x)
				file.store_8(value.y)
			else:
				file.store_8(1)
				file.store_float(value.x)
				file.store_float(value.y)
		DT_BUFFER:
			if !skip_type:
				file.store_8(type)
			file.store_16(value.size())
			file.store_buffer(value)
		DT_STRING:
			if !skip_type: file.store_8(type)
			var buf:PoolByteArray = value.to_utf8()
			file.store_16(buf.size())
			file.store_buffer(buf)
		DT_BUFFER_LONG:
			if !skip_type:
				file.store_8(type)
			file.store_32(value.size())
			file.store_buffer(value)
		DT_STRING_LONG:
			if !skip_type:
				file.store_8(type)
			var buf:PoolByteArray = value.to_utf8()
			file.store_32(buf.size())
			file.store_buffer(buf)
		DT_ARRAY:
			if !skip_type:
				file.store_8(type)
			if !skip_array_type:
				file.store_8(array_type)
			var p = file.get_position()
			file.store_32(0)
			file.store_16(value.size())
			for v in value:
				store_data_type(file,array_type,v,true)

func read_data_type(
	file:File,
	skip_type:bool = false,
	skip_array_type:bool = false,
	type:int = DT_UNKNOWN, # Will be auto-detected if skip_type is false
	array_type:int = DT_UNKNOWN # Will be auto-detected if skip_array_type is false
):
	if !skip_type:
		type = file.get_8()
	
	match type:
		DT_INT_8:
			return file.get_8()
		
		DT_INT_16:
			return file.get_16()
		
		DT_INT_32:
			return file.get_32()
		
		DT_INT_64:
			return file.get_64()
		
		DT_FLOAT_32:
			return file.get_float()
		
		DT_FLOAT_64:
			return file.get_real()
		
		DT_POSITION:
			var value:Vector2 = Vector2(5,3)
			var t = file.get_8()
			if t == 0:
				var x = file.get_8()
				var y = file.get_8()
				value = Vector2(x,y)
			elif t == 1:
				var x = file.get_float()
				var y = file.get_float()
				value = Vector2(x,y)
			else:
				# Something has gone wrong
				assert(false)
			return value
		
		DT_BUFFER:
			var size = file.get_16()
			return file.get_buffer(size)
		
		DT_STRING:
			var size = file.get_16()
			var buf = file.get_buffer(size)
			return buf.get_string_from_utf8()
		
		DT_BUFFER_LONG:
			var size = file.get_32()
			return file.get_buffer(size)
		
		DT_STRING_LONG:
			var size = file.get_32()
			var buf = file.get_buffer(size)
			return buf.get_string_from_utf8()
		
		DT_ARRAY:
			if !skip_array_type:
				array_type = file.get_8()
			
			var arr = []
			var size = file.get_16()
			arr.resize(size)
			for i in range(size):
				arr[i] = read_data_type(file,true,false,array_type)
			
			return arr

func convert_to_sspm(upgrade:bool=false):
	var file:File = File.new()
	var file2:File = File.new()
	var dir:Directory = Directory.new()
	# Figure out the path and make sure it's usable
	var path:String = Globals.p("user://maps/%s.sspm") % id
	if !dir.dir_exists(Globals.p("user://maps")): dir.make_dir(Globals.p("user://maps"))
	
	var oldPath = filePath
	if upgrade:
		if songType == Globals.MAP_SSPM or songType == Globals.MAP_SSPM2:
			var res = dir.copy(filePath,Globals.p("user://upgrade_temp.sspm"))
			if res != OK:
				return "copy failed - err %s" % res
			path = filePath
			filePath = Globals.p("user://upgrade_temp.sspm")
	elif file.file_exists(path):
		return "File already exists!"
	
	var err:int
	var markers = read_markers()
	
	
	var map_has_cover = (has_cover and self.cover and (cover.get_height() + cover.get_width()) >= 9)
	
	var map_has_music:bool = false
	var music_buffer:PoolByteArray = get_music_buffer()
	var music_buffer_length:int = 0
	
	# Get music buffer
	if music_buffer:
		map_has_music = true
		music_buffer_length = music_buffer.size()
	
	
	var author_regex = RegEx.new()
	author_regex.compile("(?:^|\\g'2')(.*?)(?=$|\\g'2')(?(DEFINE)([,\\s]*(?>(?<=[,\\s])&(?=\\s)|(?<=[,\\s])and(?=\\s)|\\+)\\s*|,\\s*+))")
	var author_matches = author_regex.search_all(creator)
	var authors = []
	for m in author_matches:
		authors.append(m.get_string(1))
	
	read_markers()
	
	# Open the file for writing
	err = file.open(path,File.WRITE_READ)
	if err != OK: return "file.open errored - code " + String(err)
	
	
	
	
	
	
	# This format has documentation:
	# https://github.com/basils-garden/types/blob/sspm-v2-draft/sspm/v2.md
	
	# Header
	file.store_buffer(PoolByteArray([0x53,0x53,0x2b,0x6d])) # File signature
	file.store_16(2) # File type version
	file.store_buffer(PoolByteArray([0x00,0x00,0x00,0x00])) # Reserved space
	
	# Static metadata
	# Position: 0x0a
	file.store_buffer(PoolByteArray([
		0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00,
		0x00, 0x00, 0x00, 0x00, 0x00,
	])) # Save 20 bytes for the marker block hash, we'll come back here later
	
	# Position: 0x1e
	file.store_32(last_ms) # Millisecond position of the last marker (32 bit uint)
	
	# Position: 0x22
	file.store_32(note_count) # Number of notes in the map (32 bit uint).
	
	var marker_count:int = 0
	for array in read_markers().values():
		marker_count += array.size()
	
	# Position: 0x26
	file.store_32(marker_count)
	
	# Position: 0x2a
	file.store_8(difficulty + 1)
	
	# Position: 0x2b
	file.store_16(rating)
	
	# Position: 0x2d
	file.store_8(int(map_has_music)) # Does this map have audio? 
	# Position: 0x2e
	file.store_8(int(map_has_cover)) # Does this map have a cover? 
	# Position: 0x2f
	file.store_8(0) # Does this map require at least one mod?
	
	
	# Pointers
	# We will to return to these values later.
	
	var point_cdb = file.get_position()
	print("cdb: %s" % String(point_cdb))
	
	# Position: 0x30
	file.store_64(0) # Byte offset of the custom data block
	
	# Position: 0x38
	file.store_64(0) # Byte length of the custom data block
	
	
	var point_ab = file.get_position()
	print("ab: %s" % String(point_ab))
	
	# Position: 0x40
	file.store_64(0) # Byte offset of the audio block (0 if not present)
	
	# Position: 0x48
	file.store_64(0) # Byte length of the audio block (0 if not present)
	
	
	var point_cb = file.get_position()
	print("cb: %s" % String(point_cb))
	
	# Position: 0x50
	file.store_64(0) # Byte offset of the cover block (0 if not present)
	
	# Position: 0x58
	file.store_64(0) # Byte length of the cover block (0 if not present)
	
	
	var point_mdb = file.get_position()
	print("mdb: %s" % String(point_mdb))
	
	# Position: 0x60
	file.store_64(0) # Byte offset of the marker definitions block
	
	# Position: 0x68
	file.store_64(0) # Byte length of the marker definitions block
	
	
	var point_mb = file.get_position()
	print("mb: %s" % String(point_mb))
	
	# Position: 0x70
	file.store_64(0) # Byte offset of the marker block
	
	# Position: 0x78
	file.store_64(0) # Byte length of the marker block
	
	
	# Strings
	var start:int = file.get_position()
	
	# Map ID
	var buf:PoolByteArray = id.to_utf8()
	file.store_16(buf.size())
	file.store_buffer(buf)
	
	# Map name
	buf = name.to_utf8()
	file.store_16(buf.size())
	file.store_buffer(buf)
	
	# Song name
	buf = song.to_utf8()
	file.store_16(buf.size())
	file.store_buffer(buf)
	
	# Mapper list
	file.store_16(authors.size())
	for n in authors:
		buf = n.to_utf8()
		file.store_16(buf.size())
		file.store_buffer(buf)
	
	
	# Custom Data
	start = file.get_position()
	
	file.store_16(custom_data.size()) # Number of fields
	
	for n in custom_data.keys():
		buf = n.to_utf8()
		file.store_16(buf.size())
		file.store_buffer(buf)
		var v = custom_data[n]
		var t = auto_data_type(v)
		var at = DT_UNKNOWN
		if t == DT_ARRAY and t.size() != 0:
			at = auto_data_type(t[0])
		store_data_type(file,t,v,false,at,false)
	
	
	var end = file.get_position()
	file.seek(point_cdb)
	file.store_64(start)
	file.store_64(end - start)
	file.seek(end)
	
	
	# Audio
	print(map_has_music)
	if map_has_music:
		start = file.get_position()
		file.store_buffer(music_buffer)
		end = file.get_position()
		
		file.seek(point_ab)
		print("music block:")
		print(start)
		print(end - start, ", should equal ", music_buffer_length)
		file.store_64(start)
		file.store_64(end - start)
		file.seek(end)
	
	# Cover
	print(map_has_cover)
	if map_has_cover:
		start = file.get_position()
		file.store_buffer(cover.get_data().save_png_to_buffer())
		end = file.get_position()
		
		file.seek(point_cb)
		file.store_64(start)
		file.store_64(end - start)
		file.seek(end)
	
	var marker_td:Dictionary = {}
	
	# Marker definitions
	var markers_start = file.get_position()
	start = file.get_position()
	file.store_8(marker_types.size())
	for i in range(marker_types.size()):
		var t = marker_types[i]
		buf = t[0].to_utf8()
		file.store_16(buf.size())
		file.store_buffer(buf)
		file.store_8(t.size() - 1)
		
		# t[0] = name
		marker_td[t[0]] = [i, []]
		for j in range(1, t.size()):
			marker_td[t[0]][1].append(t[j])
			file.store_8(t[j])
		file.store_8(0)
	
	end = file.get_position()
	
	file.seek(point_mdb)
	file.store_64(start)
	file.store_64(end - start)
	file.seek(end)
	
	# Markers
	var allmarkers = []
	
	for t in markers.keys():
		for d in markers[t]:
			var ms = d[-1]
			var v = [ms, t, []]
			
			for i in range(d.size() - 1):
				v[2].append(d[i])
			
			allmarkers.append(v)
	
	allmarkers.sort_custom(self,"marker_sort")
	
	start = file.get_position()
	for m in allmarkers:
		var ms = m[0]
		var type = marker_td[ m[1] ]
		var type_id = type[0]
		var type_data = type[1]
		
		file.store_32(floor(m[0]))
		file.store_8(type_id)
		
		var offset = 0
		for i in range(type_data.size()):
			var dt = type_data[i]
			var v = m[2][i + offset]
			
			if dt == DT_POSITION:
				offset += 1
				v = Vector2(v, m[2][i + offset])
			
			store_data_type(
				file, 
				type_data[i], # type
				v, # value
				true
			)
	end = file.get_position()
	
	file.seek(point_mb)
	file.store_64(start)
	file.store_64(end - start)
	file.seek(end)
	
	file.seek(markers_start)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA1)
	
	while !file.eof_reached():
		ctx.update(file.get_buffer(hash_chunk_size))
	
	marker_hash = ctx.finish()
	
	file.seek(0x0a)
	file.store_buffer(marker_hash)
	
	songType = Globals.MAP_SSPM2
	filePath = path
	dir.remove(Globals.p("user://upgrade_temp.sspm"))
	
	load_from_sspm(path)
	
	return "Converted!"

func load_from_sspm(path:String):
	is_online = false
	songType = Globals.MAP_SSPM
	filePath = path
	musicFile = path
	if path.begins_with("res://"):
		is_builtin = true
	var file:File = File.new()
	# Open the file for reading
	var err = file.open(path,File.READ)
	if err != OK: return "file.open errored - code " + String(err)
	
	# Header
	if file.get_buffer(4) != PoolByteArray([0x53,0x53,0x2b,0x6d]): return "File is not a valid .sspm (or header is borked)"
	
	var version:int = file.get_16()
	if version == 1:
		if file.get_16() != 0: return "Header reserved space is invalid (modded map?)"
		
		id = file.get_line()
		name = file.get_line()
		song = name
		creator = file.get_line()
		
		# Map metadata
		last_ms = file.get_32()
		note_count = file.get_32()
		difficulty = file.get_8() - 1
		
		# Cover
		cover_offset = file.get_position()
		var ct = file.get_8()
		if ct == 1 or ct == 2:
#			var img:Image = Image.new()
			if ct == 1:
				var h:int = file.get_16()
				var w:int = file.get_16()
				var mip:bool = bool(file.get_8())
				var format:int = file.get_8()
				var clen:int = file.get_64()
				var cbuf:PoolByteArray = file.get_buffer(clen)
#				img.create_from_data(w,h,mip,format,cbuf)
			elif ct == 2:
				var clen:int = file.get_64()
				var cbuf:PoolByteArray = file.get_buffer(clen)
#				img.load_png_from_buffer(cbuf)
			
#			var imgtex:ImageTexture = ImageTexture.new()
#			imgtex.create_from_image(img)
#			cover = imgtex
			has_cover = true
		
		if file.get_8() != 1:
			warning = "[sspm] Invalid music storage type!"
			is_broken = true
			file.close()
			return
		else:
			file.get_64()
			var buf:PoolByteArray = file.get_buffer(12)
			if Globals.audioLoader.get_format(buf) == "unknown":
				warning = "[sspm] Invalid music data!"
				is_broken = true
				file.close()
				return
		
		sspm_song_stored = true
		
		file.close() # All done!
		return self
	
	elif version == 2:
		songType = Globals.MAP_SSPM2
		if file.get_buffer(4) != PoolByteArray([0x00,0x00,0x00,0x00]):
			return "Header reserved space is invalid"
		
		# Static metadata
		# Position: 0x0a
		marker_hash = file.get_buffer(20)
		
		# Position: 0x1e
		last_ms = file.get_32() # Millisecond position of the last marker (32 bit uint)
		
		# Position: 0x22
		note_count = file.get_32() # Number of notes in the map (32 bit uint).
		
		# Position: 0x26
		marker_count = file.get_32()
		
		# Position: 0x2a
		difficulty = file.get_8() - 1
		
		# Position: 0x2b
		rating = file.get_16()
		
		# Position: 0x2d
		var map_has_music = bool(file.get_8()) # Does this map have audio?
		if !map_has_music:
			is_broken = true
		else:
			sspm_song_stored = true
		# Position: 0x2e
		has_cover = bool(file.get_8()) # Does this map have a cover? 
		# Position: 0x2f
		var mods_required = file.get_8() # Does this map require at least one mod?
		if mods_required and !check_if_modded():
			return "Map requires mods"
		
		# Pointers
		# We will to return to these values later.
		# Position: 0x30
		var cdb_offset = file.get_64() # Byte offset of the custom data block
		
		# Position: 0x38
		var cdb_length = file.get_64() # Byte length of the custom data block
		
		# Position: 0x40
		var ab_offset = file.get_64() # Byte offset of the audio block (0 if not present)
		
		# Position: 0x48
		var ab_length = file.get_64() # Byte length of the audio block (0 if not present)
		
		# Position: 0x50
		var cb_offset = file.get_64() # Byte offset of the cover block (0 if not present)
		
		# Position: 0x58
		var cb_length = file.get_64() # Byte length of the cover block (0 if not present)
		
		# Position: 0x60
		var mdb_offset = file.get_64() # Byte offset of the marker definitions block
		
		# Position: 0x68
		var mdb_length = file.get_64() # Byte length of the marker definitions block
		
		# Position: 0x70
		var mb_offset = file.get_64() # Byte offset of the marker block
		
		# Position: 0x78
		var mb_length = file.get_64() # Byte length of the marker block
		
		
		# Map ID
		id = file.get_buffer(file.get_16()).get_string_from_utf8()
		
		# Map name
		name = file.get_buffer(file.get_16()).get_string_from_utf8()
		
		# Song name
		song = file.get_buffer(file.get_16()).get_string_from_utf8()
		
		# Mapper list
		var authors = []
		authors.resize(file.get_16())
		for i in range(authors.size()):
			authors[i] = file.get_buffer(file.get_16()).get_string_from_utf8()
		
		creator = ""
		for i in range(authors.size()):
			if i != 0:
				creator += " & "
			creator += authors[i]
		
		# Custom Data
		file.seek(cdb_offset)
		var field_count = file.get_16()
		
		for i in range(field_count):
			var n = file.get_buffer(file.get_16()).get_string_from_utf8()
			custom_data[n] = read_data_type(file,false,false)
		
		
		
		# Cover
		cover_offset = cb_offset
		cover_length = cb_length
#		if has_cover:
#			file.seek(cb_offset)
#			var img:Image = Image.new()
#			var cbuf:PoolByteArray = file.get_buffer(cb_length)
#			img.load_png_from_buffer(cbuf)
#
#			var imgtex:ImageTexture = ImageTexture.new()
#			imgtex.create_from_image(img)
#			cover = imgtex
		
		# Marker definitions
		file.seek(mdb_offset)
		marker_types = []
		var marker_type_count = file.get_8()
		marker_types.resize(marker_type_count)
		
		for i in range(marker_types.size()):
			var t = []
			marker_types[i] = t
			var buf = file.get_buffer(file.get_16())
			var name = buf.get_string_from_utf8()
			t.append(name)
			
			var typecount = file.get_8()
			
			# t[0] = name
			for j in range(1, typecount+1):
				var type = file.get_8()
				t.append(type)
				
			file.get_8()
		
		return self
	
	else:
		return "Unknown .sspm version (update your game?)"

func export_text(path:String):
	var txt = id + ","
	var notearr:Array = read_notes()
	if notearr.size() == 0:
		return "no notes"
	else:
		for n in read_notes():
			txt += "%s|%s|%s," % [2 - n[0], 2 - n[1], n[2]]

	var file:File = File.new()
	var err:int = file.open(path,File.WRITE)
	if err != OK: return "file.open errored - code " + String(err)
	file.store_string(txt.trim_suffix(","))
	file.close()
	return "OK"

func delete():
	if songType == Globals.MAP_SSPM or songType == Globals.MAP_SSPM2:
		var dir:Directory = Directory.new()
		var err = dir.remove(Globals.p(filePath))
		if err == OK:
			songType = -1
			difficulty = -1
			is_broken = true
			name = ""
			song = ""
			creator = ""
			Rhythia.registry_song.check_and_remove_id(id)
			id = "!DELETED"
			
			filePath = ""
			musicFile = ""
			initFile = ""
			Rhythia.emit_signal("selected_song_changed")
			Rhythia.emit_signal("favorite_songs_changed")
		else:
			Globals.notify(Globals.NOTIFY_ERROR,"Failed to delete map (error code %s)" % err,"Error")
		

func _init(idI:String="SOMETHING IS VERY BROKEN",nameI:String="SOMETHING IS VERY BROKEN",creatorI:String="Unknown"):
	id = idI
	name = nameI
	song = nameI
	creator = creatorI

func load_from_cache(cache:Dictionary):
	songType = cache.get("version")
	var path = cache.get("path")
	filePath = path
	musicFile = path
	sspm_song_stored = true
	id = cache.get("id")
	name = cache.get("name")
	song = cache.get("song")
	creator = cache.get("creator")
	difficulty = cache.get("difficulty")
	custom_data = cache.get("custom_data")
	last_ms = cache.get("last_ms")
	note_count = cache.get("note_count")
	has_cover = cache.get("cover")
	if has_cover:
		cover_offset = cache.get("cover_offset")
		cover_length = cache.get("cover_length")
	if songType == Globals.MAP_SSPM2:
		marker_types = cache.get("marker_types")
		marker_count = cache.get("marker_count")
func make_cache():
	var cache = {
		version = songType,
		path = filePath,
		id = id,
		name = name,
		song = song,
		creator = creator,
		difficulty = difficulty,
		custom_data = custom_data,
		last_ms = last_ms,
		note_count = note_count,
		cover = has_cover
	}
	if has_cover:
		cache["cover_offset"] = cover_offset
		cache["cover_length"] = cover_length
	if songType == Globals.MAP_SSPM2:
		cache["marker_types"] = marker_types
		cache["marker_count"] = marker_count
	return cache

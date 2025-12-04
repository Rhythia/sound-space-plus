extends Node

var transition_time:float = 0.6

var strings_target:bool = false
var piano_target:bool = false
var phaser_target:bool = false
var drums_target:bool = false

var strings_v:float = 0
var piano_v:float = 0
var phaser_v:float = 0
var drums_v:float = 0

var hv:float = 0 # highest value, for fade-out checks

func change(strings:bool,piano:bool,phaser:bool,drums:bool):
	strings_target = strings
	piano_target = piano
	phaser_target = phaser
	drums_target = drums
	
	if (strings_v + piano_v + phaser_v + drums_v) == 0:
		$Strings.play()
#		strings_v = float(strings)
		$Piano.play()
#		piano_v = float(piano)
		$Phaser.play()
#		phaser_v = float(phaser)
		$Drums.play()
#		drums_v = float(drums)

func m(x:float,v:bool):
	if v: return x
	else: return -x

func _process(delta:float):
	var c:float = delta / transition_time
	var bfm:float = 1.0 - get_parent().black_fade
	
	strings_v = clamp(strings_v + m(c,strings_target),0,1)
	piano_v = clamp(piano_v + m(c,piano_target),0,1)
	phaser_v = clamp(phaser_v + m(c,phaser_target),0,1)
	drums_v = clamp(drums_v + m(c,drums_target),0,1)
	
	$Strings.volume_db = linear2db(strings_v * bfm)
	$Piano.volume_db = linear2db(piano_v * bfm)
	$Phaser.volume_db = linear2db(phaser_v * bfm)
	$Drums.volume_db = linear2db(drums_v * bfm)
	
	hv = max(max(strings_v,piano_v),max(phaser_v,drums_v))

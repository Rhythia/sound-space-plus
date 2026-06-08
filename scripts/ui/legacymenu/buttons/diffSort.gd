extends ReferenceRect

onready var G = get_parent().get_parent().get_node("S/G")

func setc(n:Control,v:bool):
	if v: n.modulate = Color(1,1,1,1)
	else: n.modulate = Color(0.5,0.5,0.5,1)

func upd(_1=0,_2=0,_3=0):
	setc($NODIF,G.difficulty_filter.has(Globals.DIFF_UNKNOWN))
	setc($EASY,G.difficulty_filter.has(Globals.DIFF_EASY))
	setc($MEDIUM,G.difficulty_filter.has(Globals.DIFF_MEDIUM))
	setc($HARD,G.difficulty_filter.has(Globals.DIFF_HARD))
	setc($LOGIC,G.difficulty_filter.has(Globals.DIFF_LOGIC))
	setc($AMOGUS,G.difficulty_filter.has(Globals.DIFF_AMOGUS))

func tg(d:int):
	G.get_node("Press").play()
	if G.difficulty_filter.has(d):
		G.difficulty_filter.remove(G.difficulty_filter.find(d))
	else: G.difficulty_filter.append(d)
	G.update_search_dfil(G.difficulty_filter)

func _ready():
	$NODIF/Select.connect("pressed",self,"tg",[Globals.DIFF_UNKNOWN])
	$EASY/Select.connect("pressed",self,"tg",[Globals.DIFF_EASY])
	$MEDIUM/Select.connect("pressed",self,"tg",[Globals.DIFF_MEDIUM])
	$HARD/Select.connect("pressed",self,"tg",[Globals.DIFF_HARD])
	$LOGIC/Select.connect("pressed",self,"tg",[Globals.DIFF_LOGIC])
	$AMOGUS/Select.connect("pressed",self,"tg",[Globals.DIFF_AMOGUS])
	G.connect("search_updated",self,"upd")
	upd()

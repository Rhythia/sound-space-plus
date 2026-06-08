extends CheckBox

func _pressed():
	get_parent().get_parent().get_node("S/G").update_search_flip_name(
		!get_parent().get_parent().get_node("S/G").flip_name
	)
	Rhythia.last_search_flip_name_sort = pressed

func _ready():
	pressed = Rhythia.last_search_flip_name_sort
	get_parent().get_parent().get_node("S/G").update_search_flip_name(
		Rhythia.last_search_flip_name_sort
	)

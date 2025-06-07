extends Node

var final_score: int = 0
var high_score: int = 0

func _ready():
	load_high_score()

func load_high_score():
	if FileAccess.file_exists("user://highscore.save"):
		var file = FileAccess.open("user://highscore.save", FileAccess.READ)
		high_score = file.get_32()
		file.close()

func save_high_score():
	if final_score > high_score:
		high_score = final_score
		var file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
		file.store_32(high_score)
		file.close()

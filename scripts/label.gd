extends Label

var score :int = 0

func update_score(points:int):
	score +=points
	print("Updating points ", score)
	text = "Score \n%d" %score

extends Node
func _ready():
	var bad := 0
	var dirs := ["res://scripts"]
	while dirs.size() > 0:
		var d: String = dirs.pop_back()
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd"):
				var s = load(d + "/" + f)
				if s == null or not (s as Script).can_instantiate() and not f.begins_with("strings") and not f.begins_with("story_data"):
					print("FAIL ", d + "/" + f)
					bad += 1
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
	print("PARSE_DONE bad=", bad)
	get_tree().quit()

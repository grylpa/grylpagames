@tool
extends EditorScript

func _run():
		var project_paths = [
			#"res://deliverem/",
			#"res://delemfp/",
			#"res://guidem/",
			#"res://movingcards/",
			#"res://pneumo/",
			"res://matchws/",
		]
		
		for project_path in project_paths:
				print("Processing project: ", project_path)
				process_directory(project_path)
		
		print("✅ UID conflicts resolved! Restart Godot to apply changes.")

func process_directory(directory_path: String):
		var dir = DirAccess.open(directory_path)
		if not dir:
				print("❌ Error: Could not open directory: ", directory_path)
				return

		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
				var file_path = directory_path + file_name

				if dir.current_is_dir():
						process_directory(file_path + "/")  # Recursively process subdirectories
				elif file_name.ends_with(".tscn") or file_name.ends_with(".tres"):
						update_uids(file_path)
				
				file_name = dir.get_next()

func update_uids(file_path: String):
		var file = FileAccess.open(file_path, FileAccess.READ)
		if not file:
				print("❌ Error: Could not open file: ", file_path)
				return
		
		var content = file.get_as_text()
		file.close()

		# New regex to match Godot 4.3 UIDs (uid://<some_string>)
		var uid_regex = RegEx.new()
		uid_regex.compile('uid://([a-zA-Z0-9]+)')

		var matches = uid_regex.search_all(content)
		if not matches:
				print("⚠ No UIDs found in:", file_path)
				return  # Skip writing if no changes are needed

		var new_content = content
		for match in matches:
				var old_uid = match.get_string(1)  # Capture group 1 (actual UID)
				var new_uid = generate_uid()
				new_content = new_content.replace('uid://%s' % old_uid, 'uid://%s' % new_uid)

		if new_content != content:  # Only write if changes were made
				var write_file = FileAccess.open(file_path, FileAccess.WRITE)
				if not write_file:
						print("❌ Error: Could not write to file:", file_path)
						return
				write_file.store_string(new_content)
				write_file.close()
				print("✔ Updated UIDs in:", file_path)

func generate_uid() -> String:
		# Generate a random UID similar to Godot's uid:// format
		return "%s%s" % [generate_random_string(8), generate_random_string(8)]

func generate_random_string(length: int) -> String:
		var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
		var random_str = ""
		for i in range(length):
				random_str += chars[randi() % chars.length()]
		return random_str

import re
import uuid
import os
import sys

def fix_godot_uids_for_file(filepath, output_filepath):
    """
    Reads a Godot scene file, replaces all ext_resource UIDs with new ones,
    and writes the updated content to a specified output file.
    
    Args:
        filepath (str): The path to the Godot .tscn or .tres file.
        output_filepath (str): The path where the updated file will be saved.
    """
    if not os.path.exists(filepath):
        print(f"Error: File not found at {filepath}")
        return

    # Use a dictionary to map old UID values to new UID values
    uid_map = {}
    
    updated_lines = []
    
    # Regex to find and capture the full UID string inside the quotes,
    # including the "uid://", for a safe replacement.
    uid_pattern = re.compile(r'(uid=")(uid:\/\/[\w\d]+)(")')
    
    print(f"Processing file: {filepath}")

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            # We use re.sub with a lambda function for a safe replacement.
            # This ensures we only replace the UID value and nothing else.
            def replacer_lambda(match):
                prefix = match.group(1)
                old_uid = match.group(2)
                suffix = match.group(3)

                if old_uid not in uid_map:
                    # Dynamically get the length of the UID's alphanumeric part
                    # and generate a new one of the same length.
                    uid_len = len(old_uid) - len("uid://")
                    new_uid_value = uuid.uuid4().hex[:uid_len]
                    
                    new_uid = "uid://" + new_uid_value
                    uid_map[old_uid] = new_uid
                    print(f"Found old UID: {old_uid}, Generated new UID: {new_uid}")

                return prefix + uid_map[old_uid] + suffix

            new_line = re.sub(uid_pattern, replacer_lambda, line)
            updated_lines.append(new_line)

    # Ensure the output directory exists
    output_dir = os.path.dirname(output_filepath)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    print(f"\nWriting updated file to: {output_filepath}")

    with open(output_filepath, 'w', encoding='utf-8') as f:
        f.writelines(updated_lines)

def process_directory(dir_path):
    """
    Traverses a directory and processes all .tscn files.
    """
    print(f"Processing directory: {dir_path}")
    
    output_dir = dir_path
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        print(f"Created output directory: {output_dir}")

    for root, dirs, files in os.walk(dir_path):
        for file in files:
            if file.endswith(".tscn"):
                file_path = os.path.join(root, file)
                
                # Calculate the relative path from the input directory
                rel_path = os.path.relpath(file_path, dir_path)
                
                # Construct the output path inside the new folder
                output_filepath = os.path.join(output_dir, rel_path)

                fix_godot_uids_for_file(file_path, output_filepath)

    print("\nAll .tscn files in the directory have been processed.")
    print(f"Please check the '{output_dir}' folder for the updated files.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_godot_uids.py <path_to_scene_file_or_directory>")
        sys.exit(1)
    
    input_path = sys.argv[1]

    if os.path.isdir(input_path):
        process_directory(input_path)
    elif os.path.isfile(input_path) and input_path.endswith(".tscn"):
        filename, ext = os.path.splitext(input_path)
        output_path = f"{filename}_updated{ext}"
        fix_godot_uids_for_file(input_path, output_path)
        print("\nUID replacement complete. Please check the new file.")
        print("You can now safely rename the new file and delete the original.")
    else:
        print("Error: The provided path is not a valid directory or a .tscn file.")
        sys.exit(1)

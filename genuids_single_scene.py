import re
import uuid
import os
import sys

def fix_godot_uids(filepath):
    """
    Reads a Godot scene file, replaces all ext_resource UIDs with new ones,
    and writes the updated content to a new file.
    
    Args:
        filepath (str): The path to the Godot .tscn or .tres file.
    """
    if not os.path.exists(filepath):
        print(f"Error: File not found at {filepath}")
        return

    # Use a dictionary to map old UID values to new UID values
    uid_map = {}
    
    updated_lines = []
    
    # Regex to find and capture the full UID string inside the quotes,
    # including the "uid://", for a safe replacement.
    # This pattern is more specific to avoid errors.
    uid_pattern = re.compile(r'(uid=")(uid:\/\/[\w\d]+)(")')
    
    print(f"Processing file: {filepath}")

    with open(filepath, 'r', encoding='utf-8') as f:
        for line in f:
            # We use re.sub with a lambda function for a safe replacement.
            # This ensures we only replace the UID value and nothing else.
            def replacer_lambda(match):
                prefix = match.group(1)  # e.g., 'uid="'
                old_uid = match.group(2) # e.g., 'uid://dc310tolxset0'
                suffix = match.group(3)  # e.g., '"'

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

    # Construct the output filename
    filename, ext = os.path.splitext(filepath)
    new_filepath = f"{filename}_updated{ext}"
    
    print(f"\nWriting updated file to: {new_filepath}")

    with open(new_filepath, 'w', encoding='utf-8') as f:
        f.writelines(updated_lines)

    print("\nUID replacement complete. Please check the new file.")
    print("You can now safely rename the new file and delete the original.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python fix_godot_uids.py <path_to_scene_file>")
        sys.exit(1)
    
    input_file = sys.argv[1]
    fix_godot_uids(input_file)

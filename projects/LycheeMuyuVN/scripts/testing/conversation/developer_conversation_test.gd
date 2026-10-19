extends Control

## Choose a conversation JSON file in the Inspector.
@export_file("*.json") var dialogue_file: String = \
	"res://data/dialogue/testing/developer_conversation_test.json"

@export var start_on_ready: bool = true

@onready var conversation_panel = $ConversationPanel

@onready var character_image_slots: Dictionary = {
	"left": $Developer01Image,
	"right": $Developer02Image
}


func _ready() -> void:
	_connect_conversation_signals()

	if start_on_ready:
		load_conversation(dialogue_file)


# ============================================================
# SIGNALS
# ============================================================

func _connect_conversation_signals() -> void:
	if not conversation_panel.conversation_finished.is_connected(
		_on_conversation_finished
	):
		conversation_panel.conversation_finished.connect(
			_on_conversation_finished
		)

	if not conversation_panel.choice_selected.is_connected(
		_on_choice_selected
	):
		conversation_panel.choice_selected.connect(
			_on_choice_selected
		)

	if not conversation_panel.book_requested.is_connected(
		_on_book_requested
	):
		conversation_panel.book_requested.connect(
			_on_book_requested
		)

	if not conversation_panel.phone_requested.is_connected(
		_on_phone_requested
	):
		conversation_panel.phone_requested.connect(
			_on_phone_requested
		)


# ============================================================
# LOAD JSON
# ============================================================

func load_conversation(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Conversation JSON does not exist: " + path)
		return

	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Unable to open conversation JSON: " + path)
		return

	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)

	if not parsed is Dictionary:
		push_error("Conversation JSON root must be an object.")
		return

	var conversation_data: Dictionary = parsed

	if not conversation_data.has("entries"):
		push_error("Conversation JSON is missing 'entries'.")
		return

	var raw_entries: Variant = conversation_data["entries"]

	if not raw_entries is Array:
		push_error("'entries' must be an array.")
		return

	var entries: Array[Dictionary] = []

	for item in raw_entries:
		if item is Dictionary:
			entries.append(item)
		else:
			push_warning("Skipping an invalid dialogue entry.")

	_load_characters(
		conversation_data.get("characters", [])
	)

	print(
		"Loaded conversation: ",
		conversation_data.get("id", "unnamed")
	)

	print("Dialogue entries: ", entries.size())

	conversation_panel.start_conversation(entries)


# ============================================================
# CHARACTER IMAGES
# ============================================================

func _load_characters(characters: Variant) -> void:
	for slot_name in character_image_slots:
		var image_node: TextureRect = character_image_slots[slot_name]
		image_node.texture = null
		image_node.hide()

	if not characters is Array:
		push_warning("'characters' must be an array.")
		return

	for character in characters:
		if not character is Dictionary:
			continue

		var slot_name: String = str(
			character.get("slot", "")
		)

		if not character_image_slots.has(slot_name):
			push_warning("Unknown character slot: " + slot_name)
			continue

		var image_path: String = str(
			character.get("image", "")
		)

		if image_path.is_empty():
			continue

		if not ResourceLoader.exists(image_path):
			push_warning("Character image does not exist: " + image_path)
			continue

		var image_texture: Texture2D = load(image_path) as Texture2D

		if image_texture == null:
			push_warning("Failed to load image: " + image_path)
			continue

		var image_node: TextureRect = character_image_slots[slot_name]
		image_node.texture = image_texture
		image_node.show()


# ============================================================
# CONVERSATION EVENTS
# ============================================================

func _on_choice_selected(choice_id: String) -> void:
	print("Selected dialogue choice: ", choice_id)


func _on_conversation_finished() -> void:
	print("Conversation finished.")


func _on_book_requested() -> void:
	print("Book UI requested.")

	# When the actual book UI is integrated, pause the conversation
	# before opening it. Resume only after the book UI closes.
	#
	# Example:
	# conversation_panel.pause_conversation()


func _on_phone_requested() -> void:
	print("Phone UI requested.")

	# Integrate the phone UI here later.
	# Pause before opening it and resume when it closes.

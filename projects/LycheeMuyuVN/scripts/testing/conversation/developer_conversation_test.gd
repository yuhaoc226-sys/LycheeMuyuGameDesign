extends Control

## Choose a conversation JSON file in the Inspector.
@export_file("*.json") var dialogue_file: String = \
	"res://data/dialogue/testing/developer_conversation_test.json"
##declare a var that store the path toward the json, 
##use the @export_file to allow Inspector, which is an outside signal. to select the signal

@export var start_on_ready: bool = true
##a boolean that allows the conversation start automatically when the scene initialized
@onready var conversation_panel = $ConversationPanel
# conversationPanel is the child node of this script's node, that represent the actual dialog
# onready mean: tell godot to automatically initialize this variable ONLY after that node is loaded. 
## prevent bug
## can do stuffs like conversation_panel.hide(), 
## Or access its signals: conversation_panel.conversation_finished
## or call a method in that child node 
@onready var character_image_slots: Dictionary = {
	"left": $Developer01Image,
	"right": $Developer02Image
}
# a Dictionary is a data that stored a pair of keys and values. 
# it is like a input map like up down left right, in the inputs of the project setting. 
# in this case left and right is 2 string of path, instead vector value (1,0) or (-1,0)
# i can search the corresponding key like :
## var a = character_image_slots["left"]
## right_image = character_image_slots["right"]
# this is equivilent as:
## @onready var left_image = $Developer01Image
## @onready var right_image = $Developer02Image
# but use Dictionary is convinence, like an array, i can do (for i in "character_image_slots"):
#and easy to oraganize if i want to add 3rd value for this Dictionary array. 
#but why? :
## the dialog json file contain such: 
#{
	#"characters": [
		#{
			#"slot": "left",
			#"image": "res://assets/characters/developer.png"
		#}
	#],
	#"entries": []
#}
## the script down will read and place the image on the left. 


func _ready() -> void:
	_connect_conversation_signals()
	if start_on_ready:
		load_conversation(dialogue_file)
## when the startOnReady is true, the script load the conversation, conversly. and controllable by signal
## allows conditions like: 
### Automatically starting a conversation when entering a scene.
### Waiting until the player interacts with an NPC.
### Loading a conversation after a cutscene.
### Starting a conversation after another event occurs.

# ============================================================
# SIGNALS 接下来这一堆雷霆信号会很疯狂
# ============================================================
 
#notes for signal:
# 	signal conversation_finished --> declare a signal
#	conversation_finished.emit()  --> boradcast a signal
#let's deconstruct:
"conversation_panel.conversation_finished.connect(
    _on_conversation_finished
)"
#conversation_panel. --> expected signal source node
# .conversation_finished --> expected signal to be recieved from that node emmitted.
# .connected: --> wait until this singla is recieved, and if it is recieved, do:
#Call function _on_conversation_finished()

# is_connected() is a one time use boolean, it check if the func is actually connected, 
#	if not it it will creat an connection,
#	if connection exist it will revent repeat call for this func

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
# LOAD JSON 孩子们我写了一堆注释然后没保存我曹啊
# ============================================================

func load_conversation(path: String) -> void:
	if not FileAccess.file_exists(path):
		push_error("Conversation JSON does not exist: " + path)
		return
#accept a path for String, check if the path exist
	var file := FileAccess.open(path, FileAccess.READ)

	if file == null:
		push_error("Unable to open conversation JSON: " + path)
		return
#FileAcess.READ wont change the content of the file. 
#check if the file is openable Json, and check if it is empty
	var json_text: String = file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(json_text)
# parse the content to String, and add to parsed. 
# Variant variables can store Array, boolean, godot reffrence, or even dogot readable outside source. 
	if not parsed is Dictionary:
		push_error("Conversation JSON root must be an object.")
		return
# check if the content is Dictionary. 
# the diction include the universal tags, like speaker: muyu
# text: 114514
# those will be take as input later so the script can run
	var conversation_data: Dictionary = parsed

	if not conversation_data.has("entries"):
		push_error("Conversation JSON is missing 'entries'.")
		return
# in my dialog Json files, an entries is an Array of dictionaries, and
# each dictionary contains like the things mentioned in the comment in above section
	var raw_entries: Variant = conversation_data["entries"]

	if not raw_entries is Array:
		push_error("'entries' must be an array.")
		return
# check if the entries is functionable and correct in syntax. 

	var entries: Array[Dictionary] = []

	for item in raw_entries:
		if item is Dictionary:
			entries.append(item)
		else:
			push_warning("Skipping an invalid dialogue entry.")
# take the Dictionaries (which is basically each line of dialog) and store in list
# will skip a wrong data type, like a wrong written dialog. 
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

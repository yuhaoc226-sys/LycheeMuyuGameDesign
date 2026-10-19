extends Control

signal conversation_finished
signal choice_selected(choice_id: String)
signal book_requested
signal phone_requested

@export var typewriter_speed: float = 0.035

@onready var speaker_name: Label = $DialogueArea/DialogueLayout/SpeakerName
@onready var dialogue_text: RichTextLabel = $DialogueArea/DialogueLayout/DialogueText
@onready var continue_button: Button = $DialogueArea/DialogueLayout/ContinueButton
@onready var choice_area: PanelContainer = $ChoiceArea
@onready var choice_list: VBoxContainer = $ChoiceArea/ChoiceList
@onready var book_button: Button = $BookButton
@onready var phone_button: Button = $PhoneButton
@onready var system_message: Label = $SystemMessage

var dialogue_entries: Array[Dictionary] = []
var current_entry_index: int = 0

var is_typing: bool = false
var is_paused: bool = false
var is_conversation_active: bool = false

# Tracks each interface or system that has paused the conversation.
# The dialogue resumes only after every pause reason is removed.
var pause_reasons: Dictionary = {}

# Invalidates old asynchronous typewriter operations.
var typing_generation: int = 0


func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	book_button.pressed.connect(_on_book_pressed)
	phone_button.pressed.connect(_on_phone_pressed)

	speaker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker_name.add_theme_font_size_override("font_size", 28)

	dialogue_text.bbcode_enabled = true
	dialogue_text.scroll_active = false
	dialogue_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_text.add_theme_font_size_override("normal_font_size", 23)

	system_message.text = ""

	continue_button.hide()
	choice_area.hide()


# ============================================================
# PUBLIC API
# ============================================================

func start_conversation(entries: Array[Dictionary]) -> void:
	typing_generation += 1

	is_typing = false
	is_paused = false
	pause_reasons.clear()
	is_conversation_active = true

	dialogue_entries = entries.duplicate(true)
	current_entry_index = 0
	system_message.text = ""

	continue_button.disabled = false

	if dialogue_entries.is_empty():
		_finish_conversation()
		return

	_display_current_entry()


func pause_conversation(reason: String = "external") -> void:
	if not is_conversation_active:
		return

	if reason.is_empty():
		push_warning("Pause reason cannot be empty.")
		return

	# Dictionary keys prevent duplicate pause requests from the same source.
	pause_reasons[reason] = true
	_update_pause_state()


func resume_conversation(reason: String = "external") -> void:
	if not is_conversation_active:
		return

	if reason.is_empty():
		push_warning("Pause reason cannot be empty.")
		return

	# Removing one reason must not override another active pause.
	pause_reasons.erase(reason)
	_update_pause_state()


func _update_pause_state() -> void:
	is_paused = not pause_reasons.is_empty()

	continue_button.disabled = is_paused

	# Choices cannot be used while paused or while text is typing.
	for child in choice_list.get_children():
		if child is Button:
			child.disabled = is_paused or is_typing


func is_conversation_paused() -> bool:
	return is_paused


func is_conversation_running() -> bool:
	return is_conversation_active


func get_current_entry_id() -> String:
	if current_entry_index < 0:
		return ""

	if current_entry_index >= dialogue_entries.size():
		return ""

	return str(
		dialogue_entries[current_entry_index].get("id", "")
	)


# ============================================================
# DISPLAY DIALOGUE
# ============================================================

func _display_current_entry() -> void:
	typing_generation += 1
	var generation: int = typing_generation

	is_typing = false

	_clear_choices()

	choice_area.hide()
	continue_button.hide()

	if current_entry_index >= dialogue_entries.size():
		_finish_conversation()
		return

	var entry: Dictionary = dialogue_entries[current_entry_index]

	speaker_name.text = str(entry.get("speaker", ""))
	dialogue_text.text = str(entry.get("text", ""))
	dialogue_text.visible_characters = 0

	var choices: Array = entry.get("choices", [])

	if choices.is_empty():
		continue_button.show()
	else:
		_display_choices(choices)

	is_typing = true
	_type_text(generation)


func _type_text(generation: int) -> void:
	var total_characters: int = dialogue_text.get_total_character_count()

	dialogue_text.visible_characters = 0

	for character_index in range(total_characters):
		if generation != typing_generation:
			return

		# Wait here while a book, phone, or another interface is open.
		# The current character is preserved.
		while is_paused:
			if generation != typing_generation:
				return

			await get_tree().process_frame

		if generation != typing_generation:
			return

		dialogue_text.visible_characters = character_index + 1

		await get_tree().create_timer(
			maxf(typewriter_speed, 0.001)
		).timeout

	if generation != typing_generation:
		return

	# Also wait if the interface opened while the final character
	# was being displayed.
	while is_paused:
		if generation != typing_generation:
			return

		await get_tree().process_frame

	if generation != typing_generation:
		return

	dialogue_text.visible_characters = -1
	is_typing = false

	# Enable choices only after the sentence has finished typing.
	for child in choice_list.get_children():
		if child is Button:
			child.disabled = false


# ============================================================
# CHOICES
# ============================================================

func _display_choices(choices: Array) -> void:
	choice_area.show()

	for item in choices:
		if not item is Dictionary:
			continue

		var choice: Dictionary = item

		var button := Button.new()
		button.text = str(choice.get("text", "Continue"))
		button.custom_minimum_size = Vector2(0, 38)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.disabled = true

		var id: String = str(choice.get("id", ""))

		button.pressed.connect(
			_on_choice_pressed.bind(id)
		)

		choice_list.add_child(button)


func _on_choice_pressed(id: String) -> void:
	if is_paused:
		return

	if not is_conversation_active:
		return

	if is_typing:
		return

	choice_selected.emit(id)

	current_entry_index += 1
	_display_current_entry()


func _clear_choices() -> void:
	for child in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()


# ============================================================
# CONTINUE / FINISH
# ============================================================

func _on_continue_pressed() -> void:
	if is_paused:
		return

	if not is_conversation_active:
		return

	if is_typing:
		# First click: reveal the complete sentence.
		typing_generation += 1
		is_typing = false
		dialogue_text.visible_characters = -1

		return

	# Second click: advance to the next dialogue entry.
	current_entry_index += 1
	_display_current_entry()


func _finish_conversation() -> void:
	typing_generation += 1

	is_typing = false
	is_paused = false
	pause_reasons.clear()
	is_conversation_active = false

	continue_button.disabled = false
	continue_button.hide()
	choice_area.hide()

	speaker_name.text = ""
	dialogue_text.text = ""

	conversation_finished.emit()


# ============================================================
# BOOK / PHONE REQUESTS
# ============================================================

# These methods emit requests only.
# The caller decides when to open an interface and pause/resume
# the conversation. No interface is opened by this script yet.

func _on_book_pressed() -> void:
	if not is_conversation_active:
		return

	book_requested.emit()


func _on_phone_pressed() -> void:
	if not is_conversation_active:
		return

	phone_requested.emit()

extends Control

var current_page: BookPage = BookPage.CHARACTER

enum BookPage {
	CHARACTER,
	INVENTORY,
	FREENOTE,
	ACHIEVEMENTS
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	position = Vector2(0, 0)
	size = get_viewport_rect().size
	$NavigationButtons/FlipNext.pressed.connect(_on_flip_next_pressed)
	$NavigationButtons/FlipCharacter.pressed.connect(_on_flip_character_pressed)
	$NavigationButtons/FlipInventory.pressed.connect(_on_flip_inventory_pressed)
	$NavigationButtons/FlipFreenote.pressed.connect(_on_flip_freenote_pressed)
	$NavigationButtons/FlipAchievements.pressed.connect(_on_flip_achievements_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func open_page(page: BookPage) -> void:
	if current_page == page:
		return
	current_page = page
	print("Switching to page: ", BookPage.keys()[current_page])
	
func _on_flip_character_pressed() -> void:
	open_page(BookPage.CHARACTER)
func _on_flip_inventory_pressed() -> void:
	open_page(BookPage.INVENTORY)
func _on_flip_freenote_pressed() -> void:
	open_page(BookPage.FREENOTE)
func _on_flip_achievements_pressed() -> void:
	open_page(BookPage.ACHIEVEMENTS)
func _on_flip_next_pressed() -> void:
	open_page(BookPage.CHARACTER)
	

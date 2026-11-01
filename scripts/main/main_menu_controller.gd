class_name MainMenuController
extends Control
## Lists the available test levels and loads the chosen one via LevelLoader.

const LEVEL_DATA_PATHS: Array[String] = [
	"res://resources/levels/level_01_data.tres",
	"res://resources/levels/level_02_data.tres",
	"res://resources/levels/level_03_data.tres",
	"res://resources/levels/level_04_data.tres",
	"res://resources/levels/level_05_data.tres",
	"res://resources/levels/level_06_data.tres",
	"res://resources/levels/level_07_data.tres",
]

@onready var _button_container: VBoxContainer = $CenterContainer/VBoxContainer


func _ready() -> void:
	for path in LEVEL_DATA_PATHS:
		var level_data: LevelData = load(path)
		var button := Button.new()
		button.text = level_data.level_name
		button.pressed.connect(_on_level_button_pressed.bind(level_data))
		_button_container.add_child(button)


func _on_level_button_pressed(level_data: LevelData) -> void:
	LevelLoader.load_level(level_data)

extends Node2D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _on_video_stream_player_finished() -> void:
	get_tree().change_scene_to_file("res://filling-a-sorrow_menu/titulo.tscn")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

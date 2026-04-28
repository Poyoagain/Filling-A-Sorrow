extends Control



func _on_começar_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/topdown_world.tscn")


func _on_creditos_pressed() -> void:
	get_tree().change_scene_to_file("res://cenas/scroll_container.tscn")

func _on_sair_pressed() -> void:
	get_tree().quit() 

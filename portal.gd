extends Area2D
class_name Portal

@export var proxima_cena: String = "res://fim.tscn"

func _ready():
	visible = false  # Começa invisível
	monitoring = false
	body_entered.connect(_on_body_entered)

func aparecer():
	visible = true
	monitoring = true
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)

func _on_body_entered(body: Node2D):
	if body.is_in_group("player"):
		get_tree().change_scene_to_file(proxima_cena)

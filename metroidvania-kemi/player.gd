extends CharacterBody2D

var input
@export var speed = 400.0
@export var gravity = 10

#variavel de pulo
@export var jump_force = 500

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	moviment(delta)
	
func moviment(delta):
	input = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	
	if input != 0: 
		if input > 0:
			velocity.x += speed * delta
			velocity.x = clamp(speed, 400.0, speed)
			$AnimatedSprite2D.scale.x = 1
			$AnimatedSprite2D.play("walk")
		if input < 0:
			velocity.x -= speed * delta
			velocity.x = clamp(-speed, 400.0, -speed)
			$AnimatedSprite2D.scale.x = -1
			$AnimatedSprite2D.play("walk")
	
	if input == 0:
		velocity.x = 0
		$AnimatedSprite2D.play("idle")
#código do pulo
	if !is_on_floor():
		if velocity.y < 0:
			$AnimatedSprite2D.play("jump")
		if velocity.y > 0:
			$AnimatedSprite2D.play("fall")
			
	if Input.is_action_pressed("ui_accept") && is_on_floor():
		velocity.y -= jump_force
		velocity.x = input
	
	
	if !is_on_floor() && Input.is_action_just_released("ui_accept"):
		velocity.y = gravity
		velocity.x = input
		
	gravity_force()
	move_and_slide()

func gravity_force():
	velocity.y += gravity
	

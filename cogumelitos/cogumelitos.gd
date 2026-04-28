extends CharacterBody2D

enum State { PATROL, CHASE, DEAD }
var current_state: State = State.PATROL

@export var patrol_speed: float = 60.0
@export var chase_speed: float = 120.0
@export var gravity: float = 900.0
@export var damage: int = 1
@export var patrol_range: float = 160.0

var start_x: float
var direction: int = 1
var player: CharacterBody2D = null

# --- Nós ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea
@onready var damage_area: Area2D = $DamageArea
@onready var damage_timer: Timer = $DamageCooldown

func _ready():
	# Adiciona o inimigo ao grupo "enemies" para o player detectar
	add_to_group("enemies")
	
	start_x = global_position.x
	
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)
	damage_area.body_entered.connect(_on_damage_area_body_entered)

func _physics_process(delta):
	# Se estiver morto, não faz nada
	if current_state == State.DEAD:
		return
		
	# Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		velocity.y = 0

	# Máquina de Estados
	match current_state:
		State.PATROL:
			_patrol_behavior(delta)
		State.CHASE:
			_chase_behavior()

	# Atualiza direção visual
	_update_facing_direction()
	
	# Aplica movimento
	move_and_slide()
	
	# Atualiza animação
	_update_animation()

# --- Função para receber dano (chamada pelo player) ---
func take_damage(damage_amount: int):
	# Ignora se já estiver morto
	if current_state == State.DEAD:
		return
	
	print("Inimigo foi atingido e morreu!")
	_die()

func _die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	
	# Desativa todas as colisões
	$CollisionShape2D.disabled = true
	if detection_area: 
		detection_area.monitoring = false
	if damage_area: 
		damage_area.monitoring = false
	
	# Efeito visual de morte
	if animated_sprite:
		# Pisca vermelho rapidamente
		animated_sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		
		# Toca animação de morte se existir
		if animated_sprite.sprite_frames.has_animation("dead"):
			animated_sprite.play("dead")
			await animated_sprite.animation_finished
		else:
			# Se não tem animação, faz um fade out simples
			var tween = create_tween()
			tween.tween_property(self, "modulate:a", 0.0, 0.3)
			await tween.finished
	
	queue_free() # Remove o inimigo da cena

# --- Comportamentos de Patrulha e Perseguição ---
func _patrol_behavior(_delta):
	velocity.x = direction * patrol_speed
	
	var left_limit = start_x - patrol_range / 2
	var right_limit = start_x + patrol_range / 2
	
	if global_position.x <= left_limit:
		direction = 1
	elif global_position.x >= right_limit:
		direction = -1

func _chase_behavior():
	if player == null:
		current_state = State.PATROL
		return
	
	var dir_to_player = sign(player.global_position.x - global_position.x)
	if dir_to_player != 0:
		direction = dir_to_player
	
	velocity.x = direction * chase_speed

# --- Dano ao Player ---
func _on_damage_area_body_entered(body):
	# Não causa dano se estiver morto
	if current_state == State.DEAD:
		return
		
	if body.is_in_group("player") and damage_timer.is_stopped():
		if body.has_method("take_damage"):
			body.take_damage(damage)
			damage_timer.start()

# --- Detecção do Player ---
func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player = body
		if current_state != State.DEAD:
			current_state = State.CHASE

func _on_detection_area_body_exited(body):
	if body.is_in_group("player"):
		player = null
		if current_state != State.DEAD:
			current_state = State.PATROL

# --- Funções Auxiliares ---

func _update_facing_direction():
	if animated_sprite:
		animated_sprite.flip_h = direction < 0

func _update_animation():
	if not animated_sprite or current_state == State.DEAD:
		return
		
	if current_state == State.CHASE:
		if animated_sprite.sprite_frames.has_animation("chase"):
			animated_sprite.play("chase")
		else:
			animated_sprite.play("walk")
	elif current_state == State.PATROL:
		if abs(velocity.x) > 10.0:
			animated_sprite.play("walk")
		elif animated_sprite.sprite_frames.has_animation("idle"):
			animated_sprite.play("idle")

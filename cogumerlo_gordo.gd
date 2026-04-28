extends CharacterBody2D

# Configurações do inimigo kamikaze
@export var speed = 120.0
@export var direction = 1
@export var patrol_distance = 250
@export var attack_damage = 2
@export var attack_delay = 1.0

enum enemy_states {PATROL, ATTACKING, DEAD}
var current_state = enemy_states.PATROL

var start_position = Vector2.ZERO
var player_ref = null
var is_attacking = false
var attack_position = Vector2.ZERO

# Referências
@onready var animated_sprite = $SpriteContainer/AnimatedSprite2D  # Caminho atualizado
@onready var sprite_container = $SpriteContainer  # Container do sprite
@onready var detection_area = $Area2D
@onready var attack_area = $AttackArea
@onready var collision_shape = $CollisionShape2D
@onready var attack_timer = $Timer

# Variável para controlar se o player está na área de ataque
var player_in_attack_area = false

func _ready():
	start_position = global_position
	
	if animated_sprite:
		# Agora inverte o container inteiro em vez do sprite
		sprite_container.scale.x = -direction
		
		if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk"):
			animated_sprite.play("walk")
	
	# Conecta os sinais
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_entered)
		detection_area.body_exited.connect(_on_detection_area_exited)
	
	if attack_area:
		attack_area.body_entered.connect(_on_attack_area_entered)
		attack_area.body_exited.connect(_on_attack_area_exited)
	
	if attack_timer:
		attack_timer.one_shot = true
		attack_timer.wait_time = attack_delay
		attack_timer.timeout.connect(_on_attack_timer_timeout)
	
	current_state = enemy_states.PATROL

func _physics_process(delta):
	match current_state:
		enemy_states.PATROL:
			patrol_state(delta)
		enemy_states.ATTACKING:
			attacking_state(delta)
		enemy_states.DEAD:
			dead_state(delta)
	
	move_and_slide()

func patrol_state(delta):
	velocity.x = speed * direction
	
	# Atualiza a direção do container baseado no movimento
	if sprite_container and velocity.x != 0:
		sprite_container.scale.x = -sign(velocity.x)
	
	if animated_sprite and animated_sprite.sprite_frames and velocity.x != 0:
		if animated_sprite.sprite_frames.has_animation("walk"):
			if animated_sprite.animation != "walk":
				animated_sprite.play("walk")
	
	if direction > 0 and global_position.x >= start_position.x + patrol_distance:
		change_direction()
	elif direction < 0 and global_position.x <= start_position.x - patrol_distance:
		change_direction()

func attacking_state(delta):
	if player_ref and is_instance_valid(player_ref):
		var direction_to_player = sign(player_ref.global_position.x - global_position.x)
		velocity.x = speed * 1.5 * direction_to_player
		
		# Atualiza a direção do container
		if sprite_container and velocity.x != 0:
			sprite_container.scale.x = -sign(velocity.x)
		
		if animated_sprite and animated_sprite.sprite_frames and velocity.x != 0 and not is_attacking:
			if animated_sprite.sprite_frames.has_animation("walk"):
				if animated_sprite.animation != "walk":
					animated_sprite.play("walk")
		
		if not is_attacking and player_in_attack_area:
			print("Player está na área de ataque! Iniciando ataque!")
			attack_position = global_position
			start_attack()
	else:
		set_state(enemy_states.PATROL)

func dead_state(delta):
	velocity = Vector2.ZERO
	
	if animated_sprite and animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("dead"):
		if animated_sprite.animation != "dead":
			animated_sprite.play("dead")
			await animated_sprite.animation_finished
	
	queue_free()

func change_direction():
	direction *= -1

func start_attack():
	is_attacking = true
	velocity = Vector2.ZERO
	
	print("START_ATTACK - Inimigo parou para atacar!")
	
	if animated_sprite and animated_sprite.sprite_frames:
		if animated_sprite.sprite_frames.has_animation("attack"):
			animated_sprite.play("attack")
		else:
			animated_sprite.modulate = Color(1, 0.5, 0.5)
	
	attack_timer.start()

func _on_attack_timer_timeout():
	print("TIMER FINALIZOU - Executando ataque!")
	
	if current_state == enemy_states.ATTACKING:
		var hit_success = false
		
		if player_ref and is_instance_valid(player_ref) and player_in_attack_area:
			print("Player ainda está na área de ataque! Causando dano!")
			
			if player_ref.has_method("take_damage"):
				player_ref.take_damage(attack_damage)
				hit_success = true
				print("DANO CAUSADO! Dano: ", attack_damage)
			else:
				print("ERRO: Player não tem método take_damage!")
		else:
			print("Player não está mais na área de ataque! Ataque falhou!")
		
		if hit_success:
			print("ATAQUE ACERTOU! Inimigo morrendo...")
			set_state(enemy_states.DEAD)
		else:
			print("ATAQUE FALHOU! Inimigo voltando a patrulhar...")
			set_state(enemy_states.PATROL)

func _on_detection_area_entered(body):
	print("ÁREA DE DETECÇÃO - Algo entrou: ", body.name)
	
	if body.is_in_group("player") or body.has_method("take_damage"):
		player_ref = body
		print("PLAYER DETECTADO! Mudando para estado ATTACKING")
		set_state(enemy_states.ATTACKING)

func _on_detection_area_exited(body):
	if body == player_ref and current_state == enemy_states.ATTACKING and not is_attacking:
		player_ref = null
		set_state(enemy_states.PATROL)
		print("Player saiu da área de detecção!")

func _on_attack_area_entered(body):
	if body == player_ref or body.is_in_group("player") or body.has_method("take_damage"):
		player_in_attack_area = true
		print("Player entrou na ÁREA DE ATAQUE!")

func _on_attack_area_exited(body):
	if body == player_ref or body.is_in_group("player") or body.has_method("take_damage"):
		player_in_attack_area = false
		print("Player saiu da ÁREA DE ATAQUE!")

func set_state(new_state):
	print("Mudando estado de ", current_state, " para ", new_state)
	current_state = new_state
	
	match new_state:
		enemy_states.PATROL:
			is_attacking = false
			player_in_attack_area = false
			if animated_sprite:
				animated_sprite.modulate = Color(1, 1, 1)
				if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("walk"):
					animated_sprite.play("walk")
		enemy_states.ATTACKING:
			pass
		enemy_states.DEAD:
			collision_shape.disabled = true
			if detection_area:
				detection_area.get_child(0).disabled = true
			if attack_area:
				attack_area.get_child(0).disabled = true

extends CharacterBody2D

var input
@export var speed = 700.0
@export var gravity = 10

#variavel de pulo
@export var jump_force = 800

# Sistema de ataque
@export var attack_damage = 2
@export var attack_cooldown = 0.5
@export var attack_duration = 0.3
var can_attack = true
var attack_timer = 0.0
var is_attacking = false

# HP variables
@export var max_hp = 8
var current_hp = 8
@export var invincibility_duration = 1.0
var is_invincible = false
var invincible_timer = 0.0

#state machine
var current_state = player_states.MOVE
enum player_states {MOVE, ATTACK, DEAD, HURT}

# Referências para a HUD de corações
@onready var heart_container = $CanvasLayer/Control/HBoxContainer
@onready var attack_area = $attack/attack_collider
@onready var attack_collision_shape = $attack/attack_collider/CollisionShape2D
@onready var animated_sprite = $AnimatedSprite2D

# Referências de áudio
@onready var walk_audio = $WalkAudio
@onready var attack_audio = $AttackAudio
@onready var hit_audio = $HitAudio
@onready var damage_audio = $DamageAudio

# Variáveis para controle do áudio de passos
var walk_timer = 0.0
var walk_interval = 0.4  # Intervalo entre os sons de passo

# Texturas dos corações
var heart_textures = {
	"full": preload("res://HUD/hearts/heart_full.webp"),
	"half": preload("res://HUD/hearts/heart_half.webp"),
	"empty": preload("res://HUD/hearts/hearth_empty.png")
}

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	
	if attack_collision_shape:
		attack_collision_shape.disabled = true
	else:
		attack_area.monitoring = false
		attack_area.monitorable = false
	
	current_hp = max_hp
	add_to_group("player")
	
	attack_area.body_entered.connect(_on_attack_hit)
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	if heart_container:
		setup_hearts()
		update_hearts()
	else:
		print("ERRO: heart_container não encontrado!")
	
	attack_area.add_to_group("player_attack")

func _on_animation_finished():
	if current_state == player_states.ATTACK:
		if attack_collision_shape:
			attack_collision_shape.disabled = true
		else:
			attack_area.monitoring = false
			attack_area.monitorable = false
		
		current_state = player_states.MOVE
		is_attacking = false

func _on_attack_hit(body):
	if body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(attack_damage)
			print("Inimigo atingido! Dano causado: ", attack_damage)
			
			# TOCA SOM DE ATAQUE NO INIMIGO
			play_hit_sound()
			
			hit_effect(body)

# VERSÃO SIMPLES: Tocar som de quando atinge inimigo
func play_hit_sound():
	if hit_audio:
		hit_audio.stop()
		hit_audio.play()

# VERSÃO SIMPLES: Tocar som de passos
func play_walk_sound():
	if walk_audio:
		walk_audio.stop()
		walk_audio.play()

# VERSÃO SIMPLES: Tocar som de ataque
func play_attack_sound():
	if attack_audio:
		attack_audio.stop()
		attack_audio.play()

# VERSÃO SIMPLES: Tocar som de dano
func play_damage_sound():
	if damage_audio:
		damage_audio.stop()
		damage_audio.play()

func hit_effect(enemy):
	if enemy.has_node("AnimatedSprite2D"):
		var enemy_sprite = enemy.get_node("AnimatedSprite2D")
		enemy_sprite.modulate = Color.RED
		await get_tree().create_timer(0.1).timeout
		enemy_sprite.modulate = Color.WHITE

func setup_hearts():
	for child in heart_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	var total_hearts = max_hp / 2
	print("Criando ", total_hearts, " corações")
	
	for i in range(total_hearts):
		var heart = TextureRect.new()
		heart.texture = heart_textures["full"]
		heart.expand = true
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(32, 32)
		heart.name = "Heart_" + str(i + 1)
		heart_container.add_child(heart)
	
	await get_tree().process_frame

func update_hearts():
	if not heart_container:
		print("ERRO: heart_container não existe!")
		return
	
	var hearts = heart_container.get_children()
	
	if hearts.size() == 0:
		print("ERRO: Nenhum coração encontrado!")
		return
	
	print("Atualizando ", hearts.size(), " corações. HP atual: ", current_hp)
	
	for i in range(hearts.size()):
		var heart_hp_value = (i + 1) * 2
		
		if current_hp >= heart_hp_value:
			hearts[i].texture = heart_textures["full"]
		elif current_hp >= heart_hp_value - 1:
			hearts[i].texture = heart_textures["half"]
		else:
			hearts[i].texture = heart_textures["empty"]

func _physics_process(delta):
	if not can_attack:
		attack_timer += delta
		if attack_timer >= attack_cooldown:
			can_attack = true
			attack_timer = 0.0
	
	match current_state:
		player_states.MOVE:
			moviment(delta)
		player_states.ATTACK:
			pass
		player_states.HURT:
			hurt_state(delta)
		player_states.DEAD:
			dead_state()
	
	if is_invincible:
		invincible_timer += delta
		if invincible_timer >= invincibility_duration:
			is_invincible = false
			invincible_timer = 0.0
			modulate.a = 1.0

func moviment(delta):
	input = Input.get_action_strength("right") - Input.get_action_strength("left")
	
	if not is_attacking:
		if input != 0: 
			if input > 0:
				velocity.x += speed * delta
				velocity.x = clamp(speed, 400.0, speed)
				animated_sprite.scale.x = 1
				$attack.position.x = 0
				animated_sprite.play("walk")
			if input < 0:
				velocity.x -= speed * delta
				velocity.x = clamp(-speed, 400.0, -speed)
				animated_sprite.scale.x = -1
				$attack.position.x = -725
				animated_sprite.play("walk")
			
			# SOM DE PASSOS CONTROLADO POR TIMER
			walk_timer += delta
			if walk_timer >= walk_interval:
				walk_timer = 0.0
				play_walk_sound()
		else:
			# PARA O SOM DE PASSOS E RESETA TUDO QUANDO PARA
			velocity.x = 0
			animated_sprite.play("idle")
			walk_timer = 0.0
			if walk_audio and walk_audio.playing:
				walk_audio.stop()
	else:
		# Durante o ataque, para o som de passos também
		velocity.x = lerp(velocity.x, 0.0, 0.2)
		walk_timer = 0.0
		if walk_audio and walk_audio.playing:
			walk_audio.stop()
	
	#código do pulo
	if !is_on_floor():
		# Para o som de passos quando está no ar
		if walk_audio and walk_audio.playing:
			walk_audio.stop()
		
		if velocity.y < 0:
			animated_sprite.play("jump")
		if velocity.y > 0:
			animated_sprite.play("fall")
			
	if Input.is_action_pressed("ui_accept") && is_on_floor() and not is_attacking:
		velocity.y -= jump_force
		velocity.x = input
	
	if !is_on_floor() && Input.is_action_just_released("ui_accept"):
		velocity.y = gravity
		velocity.x = input
	else:
		gravity_force()
	
	# Verifica se pode atacar
	if Input.is_action_just_pressed("attack") and can_attack and current_state == player_states.MOVE:
		# Para o som de passos quando ataca
		if walk_audio and walk_audio.playing:
			walk_audio.stop()
		start_attack()
	
	gravity_force()
	move_and_slide()

func start_attack():
	current_state = player_states.ATTACK
	can_attack = false
	is_attacking = true
	attack_timer = 0.0
	
	# TOCA SOM DE ATAQUE
	play_attack_sound()
	
	# Ativa o monitoramento de colisão
	if attack_collision_shape:
		attack_collision_shape.disabled = false
	else:
		attack_area.monitoring = true
		attack_area.monitorable = true
	
	animated_sprite.play("attack")
	
	await get_tree().create_timer(attack_duration).timeout
	
	if current_state == player_states.ATTACK:
		if attack_collision_shape:
			attack_collision_shape.disabled = true
		else:
			attack_area.monitoring = false
			attack_area.monitorable = false
		
		current_state = player_states.MOVE
		is_attacking = false
		
		if input == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("walk")

func gravity_force():
	velocity.y += gravity

func take_damage(damage_amount):
	if current_state == player_states.DEAD:
		return
	
	if is_invincible:
		return
	
	# TOCA SOM DE DANO AO RECEBER DANO
	play_damage_sound()
	
	# Para o som de passos quando toma dano
	if walk_audio and walk_audio.playing:
		walk_audio.stop()
	
	if current_state == player_states.ATTACK:
		if attack_collision_shape:
			attack_collision_shape.disabled = true
		else:
			attack_area.monitoring = false
			attack_area.monitorable = false
		is_attacking = false
	
	current_hp -= damage_amount
	current_hp = max(0, current_hp)
	
	update_hearts()
	
	modulate.a = 0.5
	is_invincible = true
	invincible_timer = 0.0
	
	if current_hp <= 0:
		current_hp = 0
		current_state = player_states.DEAD
		print("Player morreu!")
	else:
		current_state = player_states.HURT

func heal(heal_amount):
	if current_state != player_states.DEAD:
		current_hp = min(current_hp + heal_amount, max_hp)
		update_hearts()
		print("Curado! HP atual: ", current_hp)

func hurt_state(delta):
	if animated_sprite.sprite_frames.has_animation("hurt"):
		animated_sprite.play("hurt")
	else:
		animated_sprite.play("idle")
	
	var knockback_direction = -1 if animated_sprite.scale.x > 0 else 1
	velocity.x = knockback_direction * 200
	velocity.y = -300
	
	move_and_slide()
	
	await get_tree().create_timer(0.2).timeout
	current_state = player_states.MOVE

func dead_state():
	# Para qualquer som quando morre
	if walk_audio and walk_audio.playing:
		walk_audio.stop()
	
	velocity = Vector2.ZERO
	
	if animated_sprite.sprite_frames.has_animation("dead"):
		animated_sprite.play("dead")
	else:
		animated_sprite.play("idle")
	
	$CollisionShape2D.disabled = true
	
	if attack_collision_shape:
		attack_collision_shape.disabled = true
	else:
		attack_area.monitoring = false
		attack_area.monitorable = false
	
	get_tree().change_scene_to_file("res://game_over.tscn")

func get_current_hp():
	return current_hp

func get_max_hp():
	return max_hp

func is_dead():
	return current_state == player_states.DEAD

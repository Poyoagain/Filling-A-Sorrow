extends CharacterBody2D

# Configurações do inimigo
@export var explosion_radius = 1800.0  # Raio da explosão (opcional)
@export var explosion_delay = 1  # Tempo entre detectar o player e explodir
@export var explosion_damage = 3  # Dano de 3 HP (1 coração e meio)
@export var explosion_knockback = 500  # Força do knockback

# Estados do inimigo
enum enemy_states {IDLE, EXPLODING, DEAD}
var current_state = enemy_states.IDLE

# Referências
@onready var detection_area = $Area2D
@onready var explosion_timer = $Timer
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D
@onready var audio_player = $AudioStreamPlayer2D  # Opcional

# Referência para o player (será encontrada quando entrar na área)
var player = null
var explosion_position = Vector2.ZERO  # Guarda a posição onde a explosão vai ocorrer

# Called when the node enters the scene tree for the first time.
func _ready():
	# Conecta os sinais da área de detecção
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	
	# Conecta o timer
	explosion_timer.timeout.connect(_on_explosion_timer_timeout)
	
	# Configura o timer com o delay
	explosion_timer.wait_time = explosion_delay
	explosion_timer.one_shot = true  # Executa apenas uma vez
	
	# Inicia no estado IDLE
	set_state(enemy_states.IDLE)

# Called every frame
func _physics_process(delta):
	match current_state:
		enemy_states.IDLE:
			idle_state(delta)
		enemy_states.EXPLODING:
			exploding_state(delta)
		enemy_states.DEAD:
			dead_state(delta)

# Estado IDLE - inimigo parado esperando o player
func idle_state(delta):
	# Se tiver animação idle, toca
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
		if animated_sprite.animation != "idle":
			animated_sprite.play("idle")
	
	# Não se move
	velocity = Vector2.ZERO
	
	# Se detectou o player e não está explodindo, começa a contagem
	if player and current_state == enemy_states.IDLE:
		start_explosion()

# Estado EXPLODING - preparando para explodir
func exploding_state(delta):
	# Toca animação de alerta/preparação
	if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("alert"):
		if animated_sprite.animation != "alert":
			animated_sprite.play("alert")
	else:
		# Se não tiver animação, pode piscar
		modulate.a = 0.7 + sin(Time.get_ticks_msec() * 0.01) * 0.3
	
	# Inimigo fica parado
	velocity = Vector2.ZERO

# Estado DEAD - inimigo morto/explodido
func dead_state(delta):
	# Remove o inimigo imediatamente
	queue_free()

# Função para iniciar a explosão
func start_explosion():
	if current_state == enemy_states.IDLE:
		# Guarda a posição atual para a explosão
		explosion_position = global_position
		set_state(enemy_states.EXPLODING)
		explosion_timer.start()  # Inicia o timer para explodir

# Função que é chamada quando o timer termina (explode)
func _on_explosion_timer_timeout():
	if current_state == enemy_states.EXPLODING:
		explode()

# Função de explosão
func explode():
	# Toca som de explosão (se tiver)
	if audio_player and audio_player.stream:
		audio_player.play()
	
	# Verifica se o player ainda existe (mesmo se saiu da área)
	if player and is_instance_valid(player):
		# Calcula a distância entre a posição da explosão e o player
		var distance = player.global_position.distance_to(explosion_position)
		
		# Se o player estiver dentro do raio de explosão, causa dano
		if distance <= explosion_radius:
			# Causa dano ao player
			if player.has_method("take_damage"):
				player.take_damage(explosion_damage)
				
				# Aplica knockback no player
				var knockback_direction = (player.global_position - explosion_position).normalized()
				player.velocity = knockback_direction * explosion_knockback
		else:
			print("Player escapou da explosão! Distância: ", distance)
	else:
		print("Player não encontrado no momento da explosão")
	
	# Marca como morto e remove
	set_state(enemy_states.DEAD)

# Detecta quando o player entra na área
func _on_body_entered(body):
	# Verifica se o corpo que entrou é o player
	if (body.is_in_group("player") or body.has_method("take_damage")) and current_state == enemy_states.IDLE:
		player = body
		start_explosion()

# Detecta quando o player sai da área
func _on_body_exited(body):
	# Se o player saiu da área, apenas removemos a referência
	# MAS NÃO CANCELAMOS A EXPLOSÃO
	if body == player:
		player = null
		print("Player saiu da área, mas a explosão continuará!")

# Função auxiliar para mudar estado
func set_state(new_state):
	current_state = new_state
	
	# Reseta o modulate se voltar ao idle
	if new_state == enemy_states.IDLE:
		modulate = Color(1, 1, 1, 1)

# Função para desenhar o raio de explosão no editor (opcional)
func _draw():
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, explosion_radius, Color(1, 0, 0, 0.3))

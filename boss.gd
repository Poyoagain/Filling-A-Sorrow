extends CharacterBody2D
class_name VengeflyBoss

# ============================================
# CONFIGURAÇÕES DE MOVIMENTO
# ============================================
@export var velocidade_subida: float = 400.0
@export var velocidade_mergulho: float = 500.0
@export var altura_fora_da_tela: float = 600.0
@export var altura_minima: float = 100.0
@export var altura_padrao: float = 400.0
@export var pausa_entre_mergulhos: float = 0.2
@export var pausa_entre_ciclos: float = 2.0

# ============================================
# CONFIGURAÇÕES DE DETECÇÃO
# ============================================
@export var distancia_deteccao: float = 300.0

# ============================================
# SISTEMA DE VIDA DO BOSS
# ============================================
@export var max_hp: int = 40
var current_hp: int
@export var invincibility_duration: float = 0.5
var is_invincible: bool = false
var invincible_timer: float = 0.0

# ============================================
# REFERÊNCIAS
# ============================================
var player: CharacterBody2D = null
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox_area: Area2D = $Hurtbox
@onready var hitbox_area: Area2D = $HitboxDano
@onready var detection_area: Area2D = $DetectionArea

# ============================================
# ESTADOS DO BOSS
# ============================================
enum EstadoBoss {
	OCIOSO,
	ACORDANDO,
	MERGULHANDO,
	ATORDOADO,
	MORTO
}

var estado_atual: EstadoBoss = EstadoBoss.OCIOSO
var mergulhos_restantes: int = 0
var combate_ativo: bool = false
var player_detectado: bool = false

# Limites da tela
var largura_tela: float
var altura_tela: float
var camera: Camera2D

# Controle de dano
var pode_causar_dano: bool = false
var dano_causado_recentemente: Dictionary = {}

# Posição inicial
var posicao_inicial: Vector2

# ============================================
# INICIALIZAÇÃO
# ============================================
func _ready():
	current_hp = max_hp
	posicao_inicial = global_position
	
	_encontrar_player()
	
	camera = get_viewport().get_camera_2d()
	
	if camera:
		var viewport_size = get_viewport().get_visible_rect().size
		largura_tela = viewport_size.x / 2
		altura_tela = viewport_size.y / 2
	else:
		largura_tela = 640
		altura_tela = 360
	
	_configurar_sinais()
	
	add_to_group("enemies")
	
	if animated_sprite:
		animated_sprite.play("fly")

func _configurar_sinais():
	if detection_area:
		detection_area.body_entered.connect(_on_player_entrou_area)
		detection_area.body_exited.connect(_on_player_saiu_area)
		
		var collision_shape = detection_area.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape is CircleShape2D:
			collision_shape.shape.radius = distancia_deteccao
	
	if hurtbox_area:
		hurtbox_area.area_entered.connect(_on_hurtbox_area_entered)
		hurtbox_area.body_entered.connect(_on_hurtbox_body_entered)
		
		hurtbox_area.monitoring = true
		hurtbox_area.monitorable = true
	
	if hitbox_area:
		hitbox_area.body_entered.connect(_on_hitbox_body_entered)
		
		hitbox_area.monitoring = true
		hitbox_area.monitorable = true

func _encontrar_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ============================================
# PROCESSAMENTO PRINCIPAL
# ============================================
func _physics_process(delta):
	if estado_atual == EstadoBoss.MORTO:
		return
	
	if not player:
		_encontrar_player()
		return
	
	if is_invincible:
		invincible_timer += delta
		if invincible_timer >= invincibility_duration:
			is_invincible = false
			invincible_timer = 0.0
			modulate.a = 1.0
	
	if estado_atual == EstadoBoss.OCIOSO:
		var distancia = global_position.distance_to(player.global_position)
		if distancia <= distancia_deteccao and not player_detectado:
			player_detectado = true
			_ativar_boss()
	
	dano_causado_recentemente.clear()
	
	if animated_sprite and estado_atual != EstadoBoss.MORTO:
		if animated_sprite.animation != "fly":
			animated_sprite.play("fly")
	
	if estado_atual == EstadoBoss.OCIOSO:
		_flutuacao_ociosa(delta)

func _flutuacao_ociosa(delta):
	global_position.y = posicao_inicial.y + sin(Time.get_ticks_msec() * 0.002) * 10
	
	if animated_sprite:
		animated_sprite.flip_h = global_position.x < player.global_position.x

# ============================================
# DETECÇÃO DO PLAYER
# ============================================
func _on_player_entrou_area(body: Node2D):
	if not body.is_in_group("player"):
		return
	
	if estado_atual == EstadoBoss.OCIOSO:
		player_detectado = true
		_ativar_boss()

func _on_player_saiu_area(body: Node2D):
	if not body.is_in_group("player"):
		return
	
	player_detectado = false

func _ativar_boss():
	if estado_atual != EstadoBoss.OCIOSO:
		return
	
	estado_atual = EstadoBoss.ACORDANDO
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.3)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2)
	
	await get_tree().create_timer(0.8).timeout
	
	combate_ativo = true
	_iniciar_combate()

func _iniciar_combate():
	while combate_ativo and estado_atual != EstadoBoss.MORTO:
		if estado_atual == EstadoBoss.MERGULHANDO or estado_atual == EstadoBoss.ACORDANDO:
			await _executar_ciclo_mergulho_triplo()
		await get_tree().process_frame

# ============================================
# ATAQUE PRINCIPAL - MERGULHO TRIPLO
# ============================================
func _executar_ciclo_mergulho_triplo():
	mergulhos_restantes = 3
	estado_atual = EstadoBoss.MERGULHANDO
	
	while mergulhos_restantes > 0 and estado_atual != EstadoBoss.MORTO and combate_ativo:
		pode_causar_dano = false
		
		var posicao_x_alvo = global_position.x
		if player:
			posicao_x_alvo = player.global_position.x
		
		var posicao_alvo = Vector2(posicao_x_alvo, altura_fora_da_tela)
		
		while global_position.distance_to(posicao_alvo) > 10.0:
			var direcao = (posicao_alvo - global_position).normalized()
			global_position += direcao * velocidade_subida * get_process_delta_time()
			
			if animated_sprite:
				animated_sprite.flip_h = global_position.x < player.global_position.x
			
			await get_tree().process_frame
		
		await get_tree().create_timer(pausa_entre_mergulhos).timeout
		
		pode_causar_dano = true
		
		var posicao_player = player.global_position if player else Vector2(global_position.x, altura_minima)
		var posicao_mergulho = Vector2(posicao_player.x, altura_minima)
		
		while global_position.distance_to(posicao_mergulho) > 10.0:
			var direcao = (posicao_mergulho - global_position).normalized()
			global_position += direcao * velocidade_mergulho * get_process_delta_time()
			
			if animated_sprite:
				animated_sprite.flip_h = global_position.x < player.global_position.x
			
			await get_tree().process_frame
		
		await get_tree().create_timer(0.15).timeout
		
		pode_causar_dano = false
		
		mergulhos_restantes -= 1
		
		if mergulhos_restantes > 0:
			await get_tree().create_timer(pausa_entre_mergulhos).timeout
	
	var posicao_normal = Vector2(global_position.x, altura_padrao)
	while global_position.distance_to(posicao_normal) > 10.0:
		var direcao = (posicao_normal - global_position).normalized()
		global_position += direcao * velocidade_subida * get_process_delta_time()
		
		if animated_sprite:
			animated_sprite.flip_h = global_position.x < player.global_position.x
		
		await get_tree().process_frame
	
	await get_tree().create_timer(pausa_entre_ciclos).timeout

# ============================================
# SISTEMA DE COLISÃO
# ============================================
func _on_hurtbox_area_entered(area: Area2D):
	if "attack" in area.name.to_lower():
		_take_damage(2)
		return
	
	if area.is_in_group("player_attack"):
		_take_damage(2)
		return
	
	var parent = area.get_parent()
	if parent and parent.is_in_group("player"):
		_take_damage(2)
		return

func _on_hurtbox_body_entered(body: Node2D):
	pass

func _on_hitbox_body_entered(body: Node2D):
	if not body.is_in_group("player"):
		return
	
	if not pode_causar_dano:
		return
	
	var player_id = body.get_instance_id()
	if dano_causado_recentemente.has(player_id):
		return
	
	dano_causado_recentemente[player_id] = true
	
	if body.has_method("take_damage"):
		body.take_damage(1)
		
		var direcao_knockback = (body.global_position - global_position).normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(direcao_knockback * 300)

# ============================================
# SISTEMA DE DANO
# ============================================
func take_damage(damage_amount: int):
	_take_damage(damage_amount)

func _take_damage(damage_amount: int):
	if estado_atual == EstadoBoss.MORTO:
		return
	
	if is_invincible:
		return
	
	if estado_atual == EstadoBoss.OCIOSO:
		_ativar_boss()
	
	current_hp -= damage_amount
	
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	
	is_invincible = true
	invincible_timer = 0.0
	modulate.a = 0.7
	
	if current_hp <= 0:
		_morrer()
		return
	
	if damage_amount > 5:
		_ficar_atordoado()

func _ficar_atordoado():
	estado_atual = EstadoBoss.ATORDOADO
	combate_ativo = false
	pode_causar_dano = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.5, 0.2)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	tween.set_loops(4)
	
	await get_tree().create_timer(2.0).timeout
	
	combate_ativo = true
	estado_atual = EstadoBoss.MERGULHANDO

func _morrer():
	
	# Ativa o portal (procura pelo nome)
	var portal = get_tree().get_first_node_in_group("portal")
	if portal == null:
		portal = get_parent().get_node_or_null("Portal")
	
	if portal and portal.has_method("aparecer"):
		portal.aparecer()
	
	estado_atual = EstadoBoss.MORTO
	combate_ativo = false
	pode_causar_dano = false
	
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(self, "scale", Vector2(0, 0), 1.0)
	
	if hurtbox_area:
		hurtbox_area.monitoring = false
		hurtbox_area.monitorable = false
	
	if hitbox_area:
		hitbox_area.monitoring = false
		hitbox_area.monitorable = false
	
	if detection_area:
		detection_area.monitoring = false
	
	await get_tree().create_timer(1.5).timeout
	queue_free()

# ============================================
# FUNÇÕES AUXILIARES
# ============================================
func get_current_hp() -> int:
	return current_hp

func get_max_hp() -> int:
	return max_hp

func is_dead() -> bool:
	return estado_atual == EstadoBoss.MORTO

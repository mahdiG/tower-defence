extends StaticBody3D

@export var attack_damage: float = 10.0
@export var attack_interval: float = 1.0
@export var max_health: float = 100.0
@export var turn_to_face_target: bool = true
@export var projectile_scene: PackedScene

@onready var attack_area: Area3D = $AttackArea
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var projectile_spawn_point: Marker3D = $ProjectileSpawnPoint

var isAttackOnCooldown := false
var health := 100.0
var current_target: Node3D = null
var enemies_in_range: Array[Node3D] = []


func _ready() -> void:
	health = max_health

	attack_area.body_entered.connect(_on_enemy_entered_range)
	attack_area.body_exited.connect(_on_enemy_left_range)

	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = maxf(attack_interval, 0.01)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)


func _process(_delta: float) -> void:
	_update_target()
	_face_target()
	attack()


func _update_target() -> void:
	enemies_in_range = enemies_in_range.filter(is_instance_valid)

	# Keep attacking the current target until it dies or leaves the range.
	if is_instance_valid(current_target) and current_target in enemies_in_range:
		return

	current_target = _find_closest_enemy()


func _find_closest_enemy() -> Node3D:
	var closest_enemy: Node3D = null
	var closest_distance := INF

	for enemy in enemies_in_range:
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_enemy = enemy

	return closest_enemy


func _face_target() -> void:
	if not turn_to_face_target or not current_target:
		return

	var direction := current_target.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _on_enemy_entered_range(enemy: Node3D) -> void:
	if enemy in enemies_in_range:
		return

	enemies_in_range.append(enemy)

	# The first enemy that enters becomes the target.
	if not is_instance_valid(current_target):
		current_target = enemy


func _on_enemy_left_range(enemy: Node3D) -> void:
	enemies_in_range.erase(enemy)


func attack() -> void:
	if not is_instance_valid(current_target) or isAttackOnCooldown or not projectile_scene:
		return

	var projectile := projectile_scene.instantiate()
	get_parent().add_child(projectile)
	projectile.global_position = projectile_spawn_point.global_position
	projectile.shoot(current_target, attack_damage)

	isAttackOnCooldown = true
	attack_cooldown_timer.start()


func _on_attack_cooldown_timer_timeout() -> void:
	isAttackOnCooldown = false


func take_damage(amount: float) -> void:
	health -= amount
	if health <= 0.0:
		die()


func die() -> void:
	queue_free()

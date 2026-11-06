extends StaticBody3D

signal died()

enum AttackType { MELEE, RANGED }

const ANIMATION_LIBRARY_PATH := "res://assets/troops/animations/adventurer_1_0.res"

@export_group("Combat")
@export var max_health := 100.0
@export var attack_damage := 10.0
@export var attack_interval := 1.0
@export var attack_type: AttackType = AttackType.MELEE
@export var turn_to_face_target := true
@export var projectile_scene: PackedScene
@export var projectile_spawn_height := 1.2
@export var projectile_spawn_forward := 0.6

@export_group("Animation")
@export var idle_animation := "Idle"
@export var combat_idle_animation := "Idle"
@export var attack_animation := "1H_Melee_Attack_Chop"
@export var death_animation := "Death_A"
@export var animation_blend_time := 0.2
@export var attack_blend_time := 0.1

@export_group("Weapons")
@export var right_hand_weapon: PackedScene
@export var right_hand_weapon_rotation := Vector3.ZERO
@export var right_hand_weapon_offset := Vector3.ZERO
@export var left_hand_weapon: PackedScene
@export var left_hand_weapon_rotation := Vector3.ZERO
@export var left_hand_weapon_offset := Vector3.ZERO
@export var back_accessory: PackedScene
@export var back_accessory_bone := "chest"
@export var back_accessory_rotation := Vector3.ZERO
@export var back_accessory_offset := Vector3.ZERO

@onready var attack_area: Area3D = $AttackArea
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var projectile_spawn_point: Node3D = get_node_or_null("ProjectileSpawnPoint") as Node3D

var model: Node3D
var skeleton: Skeleton3D
var animation_player: AnimationPlayer
var is_preview := false
var health := 0.0
var current_target: Node3D = null
var enemies_in_range: Array[Node3D] = []
var isAttackOnCooldown := false
var is_dead := false


func _ready() -> void:
	health = max_health
	_setup_character()

	if is_preview:
		_play_animation(idle_animation)
		return

	attack_area.body_entered.connect(_on_enemy_entered_range)
	attack_area.body_exited.connect(_on_enemy_left_range)
	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = maxf(attack_interval, 0.01)
	attack_cooldown_timer.timeout.connect(_on_attack_cooldown_timer_timeout)
	_setup_looping_animations()
	_play_animation(idle_animation)


func _process(_delta: float) -> void:
	if is_preview:
		return

	_update_target()
	_face_target()
	_attack()
	_update_animation()


func _setup_character() -> void:
	model = get_node_or_null("Model") as Node3D
	if not model:
		push_warning("%s: no Model node found" % name)
		return

	skeleton = _find_skeleton(model)
	if not skeleton:
		push_warning("%s: no Skeleton3D found under Model" % name)
		return

	_setup_animation_player()
	_attach_weapons()


func _setup_animation_player() -> void:
	var existing := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if existing:
		animation_player = existing
	else:
		animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		skeleton.get_parent().add_child(animation_player)

	var library := load(ANIMATION_LIBRARY_PATH) as AnimationLibrary
	if library and not animation_player.has_animation_library(""):
		animation_player.add_animation_library("", library)

	animation_player.playback_default_blend_time = animation_blend_time


func _update_target() -> void:
	enemies_in_range = enemies_in_range.filter(is_instance_valid)

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
	if not turn_to_face_target or not is_instance_valid(current_target):
		return

	var direction := current_target.global_position - global_position
	direction.y = 0.0

	if direction.length_squared() > 0.001:
		look_at(global_position + direction, Vector3.UP)


func _attack() -> void:
	if not is_instance_valid(current_target) or isAttackOnCooldown:
		return

	if attack_type == AttackType.RANGED:
		_shoot(current_target)
	elif current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)

	_play_one_shot(attack_animation, attack_blend_time)
	isAttackOnCooldown = true
	attack_cooldown_timer.start()


func _shoot(target: Node3D) -> void:
	if not projectile_scene:
		push_warning("%s: ranged troop has no projectile scene" % name)
		return

	if not is_instance_valid(target):
		return

	var projectile := projectile_scene.instantiate()
	if not projectile is Node3D:
		push_warning("%s: projectile scene root is not a Node3D" % name)
		projectile.queue_free()
		return

	get_parent().add_child(projectile)
	if projectile_spawn_point:
		projectile.global_position = projectile_spawn_point.global_position
	else:
		var forward := -global_transform.basis.z
		projectile.global_position = global_position + Vector3.UP * projectile_spawn_height + forward * projectile_spawn_forward

	if projectile.has_method("shoot"):
		projectile.shoot(target, attack_damage)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	if health <= 0.0:
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	died.emit()
	set_process(false)
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	attack_area.set_deferred("monitoring", false)

	if _play_one_shot(death_animation, attack_blend_time):
		await animation_player.animation_finished

	queue_free()


func _setup_looping_animations() -> void:
	if not animation_player:
		return

	var animation_names: Array[String] = [idle_animation, combat_idle_animation]
	for animation_name in animation_names:
		if animation_name.is_empty():
			continue

		var animation := animation_player.get_animation(animation_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _attach_weapons() -> void:
	_attach_weapon(skeleton, "handslot.r", right_hand_weapon, right_hand_weapon_rotation, right_hand_weapon_offset, "WeaponAttachment_R")
	_attach_weapon(skeleton, "handslot.l", left_hand_weapon, left_hand_weapon_rotation, left_hand_weapon_offset, "WeaponAttachment_L")
	_attach_weapon(skeleton, back_accessory_bone, back_accessory, back_accessory_rotation, back_accessory_offset, "WeaponAttachment_Back")


func _attach_weapon(skeleton_node: Skeleton3D, bone_name: String, weapon_scene: PackedScene, rotation: Vector3, offset: Vector3, attachment_name: String) -> void:
	if not weapon_scene:
		return

	if bone_name.is_empty() or skeleton_node.find_bone(bone_name) == -1:
		push_warning("%s: bone '%s' not found; skipping %s" % [name, bone_name, attachment_name])
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	skeleton_node.add_child(attachment)
	attachment.bone_name = bone_name

	var weapon := weapon_scene.instantiate()
	if weapon is Node3D:
		weapon.rotation_degrees = rotation
		weapon.position = offset

	attachment.add_child(weapon)


func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node

	for child in node.get_children():
		var skeleton_node := _find_skeleton(child)
		if skeleton_node:
			return skeleton_node

	return null


func _update_animation() -> void:
	if is_instance_valid(current_target):
		_play_combat_animation()
	else:
		_play_animation(idle_animation)


func _play_animation(animation_name: String, blend_time := -1.0) -> void:
	if not animation_player or animation_name.is_empty():
		return

	if animation_player.current_animation == animation_name:
		return

	if not animation_player.has_animation(animation_name):
		return

	var blend := blend_time if blend_time >= 0.0 else animation_blend_time
	animation_player.play(animation_name, blend)


func _play_one_shot(animation_name: String, blend_time := -1.0) -> bool:
	if not animation_player or animation_name.is_empty():
		return false

	if not animation_player.has_animation(animation_name):
		return false

	var blend := blend_time if blend_time >= 0.0 else animation_blend_time
	animation_player.play(animation_name, blend)
	return true


func _play_combat_animation() -> void:
	if animation_player and animation_player.current_animation == attack_animation and animation_player.is_playing():
		return

	if animation_player and not combat_idle_animation.is_empty() and animation_player.has_animation(combat_idle_animation):
		_play_animation(combat_idle_animation)
	else:
		_play_animation(idle_animation)


func _on_enemy_entered_range(enemy: Node3D) -> void:
	if enemy in enemies_in_range:
		return

	enemies_in_range.append(enemy)

	if not is_instance_valid(current_target):
		current_target = enemy


func _on_enemy_left_range(enemy: Node3D) -> void:
	enemies_in_range.erase(enemy)


func _on_attack_cooldown_timer_timeout() -> void:
	isAttackOnCooldown = false

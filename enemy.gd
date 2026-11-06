extends CharacterBody3D

signal died()

enum AttackType { MELEE, RANGED }

@export_group("Movement")
@export var speed := 6.0

@export_group("Combat")
@export var max_health := 100.0
@export var basic_attack_damage := 10.0
@export var attack_interval := 1.0
@export var attack_type: AttackType = AttackType.MELEE
@export var projectile_scene: PackedScene
@export var projectile_spawn_height := 1.2
@export var projectile_spawn_forward := 0.6

@export_group("Animation")
@export var walk_animation := "Walking_A"
@export var idle_animation := "Idle"
@export var combat_idle_animation := "Idle_Combat"
@export var attack_animation := "1H_Melee_Attack_Slice_Diagonal"
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

@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var attack_cooldown_timer: Timer = $AttackCooldownTimer
@onready var attack_area: Area3D = $AttackArea
@onready var model: Node3D = get_node_or_null("Model") as Node3D
@onready var animation_player: AnimationPlayer = get_node_or_null("Model/AnimationPlayer") as AnimationPlayer

var health := 0.0
var shrine: StaticBody3D = null
var current_target: Node3D = null
var targets_in_range: Array[Node3D] = []
var isAttackOnCooldown := false
var is_dead := false


func _ready() -> void:
	health = max_health

	attack_area.body_entered.connect(_on_target_entered_range)
	attack_area.body_exited.connect(_on_target_left_range)

	attack_cooldown_timer.one_shot = true
	attack_cooldown_timer.wait_time = maxf(attack_interval, 0.01)

	if animation_player:
		animation_player.playback_default_blend_time = animation_blend_time

	_setup_looping_animations()
	_attach_weapons()
	_play_animation(idle_animation)


func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	_update_target()

	if is_instance_valid(current_target):
		look_at(current_target.global_position)
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		attack(current_target)
		_play_combat_animation()
		return

	_play_animation(walk_animation)
	_move_to_shrine()


func _update_target() -> void:
	targets_in_range = targets_in_range.filter(is_instance_valid)

	# Keep attacking the current target until it dies or leaves the range.
	if is_instance_valid(current_target) and current_target in targets_in_range:
		return

	current_target = _find_closest_target()


func _find_closest_target() -> Node3D:
	var closest_target: Node3D = null
	var closest_distance := INF

	for target in targets_in_range:
		var distance := global_position.distance_squared_to(target.global_position)
		if distance < closest_distance:
			closest_distance = distance
			closest_target = target

	return closest_target


func _move_to_shrine() -> void:
	if not is_instance_valid(shrine):
		return

	look_at(shrine.global_position)
	navigation_agent.target_position = shrine.global_position

	var next_position := navigation_agent.get_next_path_position()
	var new_velocity := global_position.direction_to(next_position) * speed

	if navigation_agent.avoidance_enabled:
		# This only works if avoidance is enabled in the navigation agent.
		navigation_agent.set_velocity(new_velocity)
	else:
		velocity = new_velocity

	move_and_slide()


func initialize(spawn_position: Vector3, initial_target: StaticBody3D) -> void:
	shrine = initial_target
	position = spawn_position


func attack(target: Node3D) -> void:
	if isAttackOnCooldown:
		return

	if attack_type == AttackType.RANGED:
		_shoot(target)
	elif target.has_method("take_damage"):
		target.take_damage(basic_attack_damage)

	_play_one_shot(attack_animation, attack_blend_time)
	isAttackOnCooldown = true
	attack_cooldown_timer.start()


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
	set_physics_process(false)
	velocity = Vector3.ZERO
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	attack_area.set_deferred("monitoring", false)

	if _play_one_shot(death_animation, attack_blend_time):
		await animation_player.animation_finished

	queue_free()


func _shoot(target: Node3D) -> void:
	if not projectile_scene:
		push_warning("%s: ranged enemy has no projectile scene" % name)
		return

	if not is_instance_valid(target):
		return

	var projectile := projectile_scene.instantiate()
	if not projectile is Node3D:
		push_warning("%s: projectile scene root is not a Node3D" % name)
		projectile.queue_free()
		return

	get_parent().add_child(projectile)
	var forward := -global_transform.basis.z
	projectile.global_position = global_position + Vector3.UP * projectile_spawn_height + forward * projectile_spawn_forward

	if projectile.has_method("shoot"):
		projectile.shoot(target, basic_attack_damage)


func _setup_looping_animations() -> void:
	if not animation_player:
		push_warning("%s: no AnimationPlayer found under Model" % name)
		return

	for animation_name in [walk_animation, idle_animation, combat_idle_animation]:
		if animation_name.is_empty():
			continue

		var animation := animation_player.get_animation(animation_name)
		if animation:
			animation.loop_mode = Animation.LOOP_LINEAR


func _attach_weapons() -> void:
	if not model:
		push_warning("%s: no Model node found" % name)
		return

	var skeleton := _find_skeleton(model)
	if not skeleton:
		push_warning("%s: no Skeleton3D found under Model" % name)
		return

	_attach_weapon(skeleton, "handslot.r", right_hand_weapon, right_hand_weapon_rotation, right_hand_weapon_offset, "WeaponAttachment_R")
	_attach_weapon(skeleton, "handslot.l", left_hand_weapon, left_hand_weapon_rotation, left_hand_weapon_offset, "WeaponAttachment_L")
	_attach_weapon(skeleton, back_accessory_bone, back_accessory, back_accessory_rotation, back_accessory_offset, "WeaponAttachment_Back")


func _attach_weapon(skeleton: Skeleton3D, bone_name: String, weapon_scene: PackedScene, rotation: Vector3, offset: Vector3, attachment_name: String) -> void:
	if not weapon_scene:
		return

	if bone_name.is_empty() or skeleton.find_bone(bone_name) == -1:
		push_warning("%s: bone '%s' not found; skipping %s" % [name, bone_name, attachment_name])
		return

	var attachment := BoneAttachment3D.new()
	attachment.name = attachment_name
	skeleton.add_child(attachment)
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
		var skeleton := _find_skeleton(child)
		if skeleton:
			return skeleton

	return null


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


func _on_target_entered_range(target: Node3D) -> void:
	if target in targets_in_range:
		return

	targets_in_range.append(target)

	# The first target that enters becomes the attack target.
	if not is_instance_valid(current_target):
		current_target = target


func _on_target_left_range(target: Node3D) -> void:
	targets_in_range.erase(target)


func _on_navigation_agent_velocity_computed(safe_velocity: Vector3) -> void:
	velocity = safe_velocity


func _on_attack_cooldown_timer_timeout() -> void:
	isAttackOnCooldown = false

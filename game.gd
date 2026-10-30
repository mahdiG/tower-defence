extends Node3D

signal game_over()

@export var enemy_scene: PackedScene
@export var max_enemies := 10

@onready var enemy_spawn_timer: Timer = $EnemySpawnTimer
@onready var enemy_target: StaticBody3D = $Shrine
@onready var enemy_spawn_location: PathFollow3D = $SpawnPath/SpawnLocation

@onready var fps_label: Label = $DebugStats/DebugContainer/FpsLabel
@onready var health_label: Label = $DebugStats/DebugContainer/HealthLabel
@onready var big_center_label: Label = $CenterContainer/BigCenterLabel
@onready var big_center_label_timer: Timer = $BigCenterLabelTimer
@onready var placer: Node3D = $Placer

var is_game_over := false
var enemies_spawned := 0
var enemies_dead := 0
var current_round := 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	#player.died.connect(_on_player_died)
	#start_round()
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			placer.select_troop()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
	#fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	
func start_round() -> void:
	big_center_label.text = "Round %d" % current_round
	big_center_label.visible = true
	big_center_label_timer.start()
	enemies_spawned = 0
	enemies_dead = 0
	max_enemies += 10
	enemy_spawn_timer.start()

func spawn_enemy() -> void:
	print("spawn enemy: ", enemies_spawned)
	var enemy := enemy_scene.instantiate()
	
	# And give it a random offset.
	enemy_spawn_location.progress_ratio = randf()
	enemy.initialize(enemy_spawn_location.position, enemy_target)
	# call _on_enemy_died function when enemy's died signal is emitted
	#enemy.died.connect(_on_enemy_died)
	
	add_child(enemy)
	
	
func _on_enemy_spawn_timer_timeout() -> void:
	print("timer")
	if enemies_spawned >= max_enemies:
		enemy_spawn_timer.stop()
		return
		
	spawn_enemy()
	enemies_spawned += 1

extends CharacterBody2D

const SPEED = 40.0
const GRAVITY = 980.0

@export var damage := 1
@export var patrol_distance := 30.0
@export var patrol_speed := 40.0

var spawn_position: Vector2
var patrol_direction := 1

@onready var detection = $DetectionArea
@onready var damage_area = $DamageArea
@onready var sprite = $AnimatedSprite2D


var player = null
var chasing := false

func _ready():
	spawn_position = global_position
	
	detection.body_entered.connect(_on_detection_entered)
	detection.body_exited.connect(_on_detection_exited)
	damage_area.body_entered.connect(_on_damage_entered)

func _physics_process(delta):

	if !is_on_floor():
		velocity.y += GRAVITY * delta

	if chasing and player:
		var dir = sign(player.global_position.x - global_position.x)

		velocity.x = dir * SPEED

		sprite.flip_h = dir > 0
	else:
		if global_position.x >= spawn_position.x + patrol_distance:
				patrol_direction = -1

		elif global_position.x <= spawn_position.x - patrol_distance:
			patrol_direction = 1

	velocity.x = patrol_direction * patrol_speed

	sprite.flip_h = patrol_direction > 0

	move_and_slide()

func _on_detection_entered(body):
	if body.has_method("take_damage"):
		player = body
		chasing = true

func _on_detection_exited(body):
	if body == player:
		player = null
		chasing = false

func _on_damage_entered(body):
	if body == player:
		body.take_damage(damage, global_position)

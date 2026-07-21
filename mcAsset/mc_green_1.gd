extends CharacterBody2D

# BASIC MOVEMENT
const SPEED = 200.0
const JUMP_VELOCITY = -300.0

# HP POTION
const POTION_MAX_COUNT = 5
const POTION_HEAL_PERCENT = 0.25
const POTION_CONSUME_DURATION = 1.0
const POTION_TRIGGER_CD = 5.0

@onready var health: Health = $Health

# DASHING
const DASH_SPEED = 600.0
const DASH_DURATION = 0.2
const DASH_TRIGGER_CD = 0.6
const DASH_RECOVERY_CD = 1.5
const DASH_IFRAMES = 0.3
const DASH_HOVER_DURATION = 0.15

@export var max_dash_count: int = 3 # CHANGE DASH COUNT HERE

# JUMPING
const JUMP_TRIGGER_CD = 0.3

@export var max_jump_count: int = 2 # CHANGE JUMP COUNT HERE

var dash_count: int
var jump_count: int
var potion_count: int
var is_dashing: bool = false
var is_hovering: bool = false
var is_healing: bool = false
var dash_timer: float = 0.0
var hover_timer: float = 0.0
var potion_timer: float = 0.0
var dash_trigger_timer: float = 0.0
var dash_charges_owed: int = 0
var dash_recovery_timer: float = 0.0
var jump_trigger_timer: float = 0.0
var potion_trigger_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var is_invulnerable: bool = false

func _ready() -> void:
	dash_count = max_dash_count
	jump_count = max_jump_count
	potion_count = POTION_MAX_COUNT
	health.died.connect(_on_died)

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor() and not is_dashing and not is_hovering:
		velocity += get_gravity() * delta
		
	if is_hovering:
		hover_timer -= delta
		if hover_timer <= 0.0 or is_on_floor():
			is_hovering = false
		
	# Dash charges only recover on the ground
	if is_on_floor() and dash_charges_owed > 0:
		dash_recovery_timer -= delta
		if dash_recovery_timer <= 0.0:
			dash_count = min(dash_count + 1, max_dash_count)
			dash_charges_owed -= 1
			dash_recovery_timer = DASH_RECOVERY_CD if dash_charges_owed > 0 else 0.0
			
	if is_on_floor():
		jump_count = max_jump_count
	
	if dash_trigger_timer > 0.0:
		dash_trigger_timer -= delta
		
	if jump_trigger_timer > 0.0:
		jump_trigger_timer -= delta
		
	if potion_trigger_timer > 0.0:
		potion_trigger_timer -= delta

	var direction := Input.get_axis("mcLeft", "mcRight")
	if direction != 0:
		facing_direction = sign(direction)
 
	if Input.is_action_just_pressed("mcDash") and can_dash():
		start_dash(direction)
		
	if Input.is_action_just_pressed("mcPotion") and can_use_potion():
		start_potion()
		
	if is_healing:
		velocity.x = 0.0
		potion_timer -= delta
		var movement_pressed := direction != 0 \
			or Input.is_action_just_pressed("mcJump") \
			or Input.is_action_just_pressed("mcDash")
		if movement_pressed:
			cancel_potion()
		elif potion_timer <= 0.0:
			finish_potion()
	elif is_dashing:
		dash_timer -= delta
		velocity = dash_direction * DASH_SPEED
		if dash_timer <= 0.0:
			end_dash()
	else:
		if Input.is_action_just_pressed("mcJump") and can_jump():
			do_jump()
 
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
 
	move_and_slide()
 
func can_dash() -> bool:
	return dash_count > 0 and dash_trigger_timer <= 0.0 and not is_dashing and not is_healing

func can_jump() -> bool:
	return jump_count > 0 and jump_trigger_timer <= 0.0 and not is_healing
	
func can_use_potion() -> bool:
	return potion_count > 0 and potion_trigger_timer <= 0.0 and not is_healing \
		and not is_dashing and not health.is_dead and not is_full_health()
	
func do_jump() -> void:
	jump_count -= 1
	jump_trigger_timer = JUMP_TRIGGER_CD
	is_hovering = false
	velocity.y = JUMP_VELOCITY
 
func start_dash(input_direction: float) -> void:
	is_dashing = true
	is_hovering = false
	dash_timer = DASH_DURATION
	dash_trigger_timer = DASH_TRIGGER_CD
	dash_count -= 1
	dash_charges_owed += 1
	if dash_recovery_timer <= 0.0:
		dash_recovery_timer = DASH_RECOVERY_CD
 
	var dir_x := input_direction if input_direction != 0 else float(facing_direction)
	dash_direction = Vector2(dir_x, 0).normalized()
 
	set_invulnerable(true)
	get_tree().create_timer(DASH_IFRAMES).timeout.connect(func(): set_invulnerable(false))
	# TODO: animation
 
func end_dash() -> void:
	is_dashing = false
	velocity.x = dash_direction.x * SPEED
	velocity.y = 0.0
	is_hovering = true
	hover_timer = DASH_HOVER_DURATION
	
func start_potion() -> void:
	is_healing = true
	potion_timer = POTION_CONSUME_DURATION
	
func cancel_potion() -> void:
	is_healing = false
	
func finish_potion() -> void:
	is_healing = false
	potion_count -= 1
	potion_trigger_timer = POTION_TRIGGER_CD
	health.heal_percent(POTION_HEAL_PERCENT)
	
func restock_potions() -> void:
	potion_count = POTION_MAX_COUNT
	
func _on_died() -> void:
	is_dashing = false
	is_healing = false
	velocity = Vector2.ZERO
	
func is_full_health() -> bool:
	if (health.current_hp >= health.max_hp):
		return true
	else:
		return false
		
func is_injured() -> bool:
	if (health.current_hp < health.max_hp):
		return true
	else:
		return false
 
func set_invulnerable(value: bool) -> void:
	is_invulnerable = value
	# TODO: hurtbox

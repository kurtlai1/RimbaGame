extends CharacterBody2D

@onready var animated_sprite = $AnimatedSprite2D

# BASIC MOVEMENT
const SPEED = 200.0
const JUMP_VELOCITY = -300.0
const GRAVITY = 980.0

# HP POTION
const POTION_MAX_COUNT = 5
const POTION_HEAL_PERCENT = 0.25
const POTION_CONSUME_DURATION = 1.0
const POTION_TRIGGER_CD = 5.0

@onready var health = $Health

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

# ATK STAT
@export var base_atk: int = 2 # ATK at Level 0
@export var atk_per_level: int = 2

# NORMAL ATTACK
const ATTACK_DAMAGE_PERCENT = 1.0 # 100% of ATK
const ATTACK_ACTIVE_DURATION = 0.15 # how long the hitbox is actually live
const ATTACK_HOVER_DURATION = 0.15 # mid-air Normal Attack: how long gravity is suspended for (mirrors the swing animation length)
const ATTACK_TRIGGER_CD = 0.5
const MELEE_HITBOX_OFFSET_X = 14.0 # distance in front of the character

# CHARGED ATTACK
# Same mcAttack button as Normal Attack: release before CHARGE_TAP_THRESHOLD
# = Normal Attack (tap), release after it = Charged Attack (hold).
const CHARGE_TAP_THRESHOLD = 0.3 # holds shorter than this count as a tap
const CHARGE_MAX_DURATION = 3.0 # holding longer than this doesn't add more damage
const CHARGED_DAMAGE_MIN_PERCENT = 1.5 # 150% of ATK at minimum charge
const CHARGED_DAMAGE_MAX_PERCENT = 3 # 300% of ATK at max charge
const CHARGED_RESOLVE_DURATION = 0.2 # the swing itself, after release - movement locked for this long
const CHARGED_ATTACK_TRIGGER_CD = 1.0

@onready var melee_hitbox: Hitbox = $MeleeHitbox
@onready var charged_hitbox: Hitbox = $ChargedHitbox
@onready var normal_attack_vfx: AnimatedSprite2D = $NormalAttackVFX
@onready var charge_attack_vfx: AnimatedSprite2D = $ChargeAttackVFX

var atk: int
var dash_count: int
var jump_count: int
var potion_count: int
var is_dashing: bool = false
var is_hovering: bool = false
var is_healing: bool = false
var is_attacking: bool = false
var is_air_attack_locked: bool = false
var is_holding_attack: bool = false # mcAttack is held, outcome (tap vs charge) not decided yet
var is_charging: bool = false # past the tap threshold - a Charged Attack is being wound up
var is_charge_resolving: bool = false # the swing itself, right after release
var dash_timer: float = 0.0
var hover_timer: float = 0.0
var potion_timer: float = 0.0
var attack_timer: float = 0.0
var dash_trigger_timer: float = 0.0
var dash_charges_owed: int = 0
var dash_recovery_timer: float = 0.0
var jump_trigger_timer: float = 0.0
var potion_trigger_timer: float = 0.0
var attack_trigger_timer: float = 0.0
var attack_hold_timer: float = 0.0 # counts UP while mcAttack is held, drives charge %
var charge_resolve_timer: float = 0.0
var charged_attack_trigger_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO
var facing_direction: int = 1
var is_invulnerable: bool = false

func _ready() -> void:
	dash_count = max_dash_count
	jump_count = max_jump_count
	potion_count = POTION_MAX_COUNT
	recalculate_atk()
	health.died.connect(_on_died)
	normal_attack_vfx.visible = false
	normal_attack_vfx.animation_finished.connect(func(): normal_attack_vfx.visible = false)
	charge_attack_vfx.visible = false
	charge_attack_vfx.animation_finished.connect(func(): charge_attack_vfx.visible = false)

func recalculate_atk() -> void:
	atk = base_atk + (health.level * atk_per_level)

func _physics_process(delta: float) -> void:
	# print("physics working")
	# Add the gravity.
	if !is_on_floor() and !is_dashing and !is_hovering:
		velocity.y += GRAVITY * delta
		
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
		is_air_attack_locked = false
	
	if dash_trigger_timer > 0.0:
		dash_trigger_timer -= delta
		
	if jump_trigger_timer > 0.0:
		jump_trigger_timer -= delta
		
	if potion_trigger_timer > 0.0:
		potion_trigger_timer -= delta

	if attack_trigger_timer > 0.0:
		attack_trigger_timer -= delta

	if charged_attack_trigger_timer > 0.0:
		charged_attack_trigger_timer -= delta

	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			end_attack()

	if is_charge_resolving:
		charge_resolve_timer -= delta
		if charge_resolve_timer <= 0.0:
			end_charged_attack()

	var direction := Input.get_axis("mcLeft", "mcRight")
	# for action in ["mcLeft", "mcRight", "mcJump", "mcDash", "mcPotion", "mcAttack"]:
	#	if Input.is_action_pressed(action):
	#		print(action)
	if direction != 0:
		facing_direction = sign(direction)
		animated_sprite.flip_h = facing_direction < 0
		melee_hitbox.position.x = MELEE_HITBOX_OFFSET_X * facing_direction
		normal_attack_vfx.position.x = MELEE_HITBOX_OFFSET_X * facing_direction
 
	if Input.is_action_just_pressed("mcDash") and can_dash():
		start_dash(direction)
		
	if Input.is_action_just_pressed("mcPotion") and can_use_potion():
		start_potion()

	if Input.is_action_just_pressed("mcAttack") and can_start_attack_input():
		is_holding_attack = true
		attack_hold_timer = 0.0

	if is_holding_attack:
		attack_hold_timer = min(attack_hold_timer + delta, CHARGE_MAX_DURATION)
		if attack_hold_timer >= CHARGE_TAP_THRESHOLD:
			is_charging = true

	if Input.is_action_just_released("mcAttack") and is_holding_attack:
		if attack_hold_timer < CHARGE_TAP_THRESHOLD:
			start_attack() # tap = Normal Attack
		else:
			start_charged_attack() # held past the threshold = Charged Attack
		is_holding_attack = false
		is_charging = false
		attack_hold_timer = 0.0
		
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
 
		if is_air_attack_locked or is_charge_resolving:
			velocity.x = 0.0
		elif direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)
 
	move_and_slide()
	update_animation()
 
func can_dash() -> bool:
	return dash_count > 0 and dash_trigger_timer <= 0.0 and not is_dashing and not is_healing

func can_jump() -> bool:
	return jump_count > 0 and jump_trigger_timer <= 0.0 and not is_healing
	
func can_use_potion() -> bool:
	return potion_count > 0 and potion_trigger_timer <= 0.0 and not is_healing \
		and not is_dashing and not health.is_dead and not is_full_health()

func can_start_attack_input() -> bool:
	return attack_trigger_timer <= 0.0 and charged_attack_trigger_timer <= 0.0 \
		and not is_attacking and not is_charge_resolving and not is_holding_attack \
		and not is_healing and not is_dashing and not health.is_dead

func start_attack() -> void:
	is_attacking = true
	attack_timer = ATTACK_ACTIVE_DURATION
	attack_trigger_timer = ATTACK_TRIGGER_CD
	var attack_damage := int(round(atk * ATTACK_DAMAGE_PERCENT))
	melee_hitbox.activate(attack_damage)
	normal_attack_vfx.visible = true
	normal_attack_vfx.flip_h = facing_direction < 0
	normal_attack_vfx.play("attack")

	# Mid-air Normal Attack grants a temporary hover: the player holds
	# their vertical position for the duration of the swing instead of
	# falling through it. Reuses the same is_hovering/hover_timer the
	# dash-landing hover uses - gravity is already skipped whenever
	# is_hovering is true (see the top of _physics_process).
	#
	# It also locks horizontal movement for the WHOLE airborne trip,
	# not just the swing itself - is_air_attack_locked only clears once
	# is_on_floor() is true again (see the floor check further down),
	# unlike is_attacking/is_hovering which end after ATTACK_HOVER_DURATION.
	if not is_on_floor():
		is_hovering = true
		hover_timer = ATTACK_HOVER_DURATION
		velocity.y = 0.0
		is_air_attack_locked = true
	# TODO: animation

func end_attack() -> void:
	is_attacking = false
	melee_hitbox.deactivate()

func start_charged_attack() -> void:
	is_charge_resolving = true
	charge_resolve_timer = CHARGED_RESOLVE_DURATION
	charged_attack_trigger_timer = CHARGED_ATTACK_TRIGGER_CD

	# Scale 150% ATK at zero charge up to 450% ATK at CHARGE_MAX_DURATION.
	var charge_percent := CHARGED_DAMAGE_MIN_PERCENT + \
		(CHARGED_DAMAGE_MAX_PERCENT - CHARGED_DAMAGE_MIN_PERCENT) \
		* (attack_hold_timer / CHARGE_MAX_DURATION)
	var attack_damage := int(round(atk * charge_percent))
	charged_hitbox.activate(attack_damage)
	charge_attack_vfx.visible = true
	charge_attack_vfx.flip_h = facing_direction < 0
	charge_attack_vfx.play("chargeAttack")
	

func end_charged_attack() -> void:
	is_charge_resolving = false
	charged_hitbox.deactivate()

func do_jump() -> void:
	if is_attacking:
		end_attack() # Jump interrupts Normal Attack
	if is_holding_attack:
		is_holding_attack = false
		is_charging = false
		attack_hold_timer = 0.0 # Jump interrupts a Charged Attack still winding up
	if is_charge_resolving:
		end_charged_attack() # Jump interrupts the Charged Attack swing itself
	jump_count -= 1
	jump_trigger_timer = JUMP_TRIGGER_CD
	is_hovering = false
	velocity.y = JUMP_VELOCITY
 
func start_dash(input_direction: float) -> void:
	if is_attacking:
		end_attack() # Dash interrupts Normal Attack
	if is_holding_attack:
		is_holding_attack = false
		is_charging = false
		attack_hold_timer = 0.0 # Dash interrupts a Charged Attack still winding up
	if is_charge_resolving:
		end_charged_attack() # Dash interrupts the Charged Attack swing itself
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
	await get_tree().create_timer(DASH_IFRAMES).timeout
	set_invulnerable(false)
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
	if is_attacking:
		end_attack()
	if is_holding_attack:
		is_holding_attack = false
		is_charging = false
		attack_hold_timer = 0.0
	if is_charge_resolving:
		end_charged_attack()
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

func play_animation(animName: String) -> void:
	if animated_sprite.animation != animName:
		animated_sprite.play(animName)

func update_animation() -> void:
	if health.is_dead:
		return
	
	if is_dashing:
		play_animation("dash")
	# TODO: play_animation("attack") once an attack SpriteFrames animation
	# exists - is_attacking is intentionally excluded from the floor/move
	# checks below since Normal Attack allows walking while active.
	elif not is_on_floor():
		play_animation("jump")
	elif abs(velocity.x) > 0:
		play_animation("move")
	else:
		play_animation("idle")

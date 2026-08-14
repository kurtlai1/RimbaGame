extends Area2D
class_name Hurtbox

## The "can receive damage" half of the combat system.
## Attach this to ANY entity that has a Health node (player, common
## enemy, mini-boss, final boss). Give it the right team and a Hitbox
## on the opposing team will damage it automatically - no per-entity
## combat code needed.

@export var team: Hitbox.Team = Hitbox.Team.ENEMY
## Where to find this entity's Health node. Defaults to a sibling
## node named "Health", matching the existing mc_green_1.gd setup.
@export var health_path: NodePath = ^"../Health"

var health: Health

## Emitted whenever a hit lands, before damage is applied - useful for
## hurt-flash VFX, hit-stop, camera shake, etc, without coupling this
## script to any of that.
signal hurt(damage: int, knockback: Vector2)

func _ready() -> void:
	monitoring = false
	monitorable = true
	health = get_node_or_null(health_path) as Health
	if health == null:
		push_warning("%s: no Health node found at '%s'" % [owner.name if owner else name, health_path])

func receive_hit(damage: int, knockback: Vector2 = Vector2.ZERO) -> void:
	if health == null or health.is_dead:
		return
	hurt.emit(damage, knockback)
	health.take_damage(damage)
	# Knockback is intentionally NOT applied here - a Hurtbox shouldn't
	# reach into the owning body's movement code. Whoever owns this
	# node listens to `hurt` and applies knockback/hitstun themselves.

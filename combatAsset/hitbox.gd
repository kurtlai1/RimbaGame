extends Area2D
class_name Hitbox

## The "can deal damage" half of the combat system.
## Attach this to ANY attack (player normal attack, enemy melee swing,
## boss slash, etc). It doesn't know or care who owns it - it just
## damages Hurtboxes on the opposing team while it's active.
##
## Usage: keep it disabled by default, call activate(damage) on the
## attack's active frames, call deactivate() when the swing ends.

enum Team { PLAYER, ENEMY }

@export var team: Team = Team.PLAYER
@export var damage: int = 0
## Optional push applied to whatever gets hit. 0 = no knockback.
@export var knockback_force: float = 0.0

## Emitted every time this hitbox actually lands on something.
signal hit_target(hurtbox: Hurtbox)

# Everything already hit during the current activation, so a single
# swing can't tick the same target multiple times while it overlaps.
var _hit_this_activation: Array[Hurtbox] = []

func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)

## Turns the hitbox on for one attack. Pass a damage value to override
## whatever is currently set (so callers can scale it per-hit, e.g.
## Charged Attack at 150%-450% of ATK).
func activate(attack_damage: int = -1) -> void:
	if attack_damage >= 0:
		damage = attack_damage
	_hit_this_activation.clear()
	monitoring = true

func deactivate() -> void:
	monitoring = false

func _on_area_entered(area: Area2D) -> void:
	if not (area is Hurtbox):
		return

	var hurtbox := area as Hurtbox
	if hurtbox.team == team:
		return # no friendly fire

	if hurtbox in _hit_this_activation:
		return # already damaged this swing

	_hit_this_activation.append(hurtbox)

	var knockback := Vector2.ZERO
	if knockback_force > 0.0:
		knockback = (hurtbox.global_position - global_position).normalized() * knockback_force

	hurtbox.receive_hit(damage, knockback)
	hit_target.emit(hurtbox)

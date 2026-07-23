extends Node
class_name Health

signal health_changed(current: int, max: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export var base_max_hp: int = 10
@export var hp_per_level: int = 2

var level: int = 0
var max_hp: int
var current_hp: int
var is_dead: bool = false


func _ready() -> void:
	recalculate_max_hp()
	current_hp = max_hp


func recalculate_max_hp() -> void:
	var old_max := max_hp
	max_hp = base_max_hp + (level * hp_per_level)
	if old_max > 0:
		current_hp = current_hp + (max_hp - old_max)   # preserve the HP delta, don't multiply
	else:
		current_hp = max_hp
	current_hp = clamp(current_hp, 0, max_hp)
	health_changed.emit(current_hp, max_hp)


func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = max(current_hp - amount, 0)
	damaged.emit(amount)
	health_changed.emit(current_hp, max_hp)
	if current_hp == 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	current_hp = min(current_hp + amount, max_hp)
	healed.emit(amount)
	health_changed.emit(current_hp, max_hp)


func heal_percent(percent: float) -> void:
	# delegate to heal() instead of duplicating the clamp/signal logic —
	# percent must stay a float (0.25, not 0) or the amount truncates to 0
	heal(int(round(max_hp * percent)))


func set_level(new_level: int) -> void:
	level = new_level
	recalculate_max_hp()

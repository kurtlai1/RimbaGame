extends Control
 
@export var player_path: NodePath
var player: CharacterBody2D
 
# Dash indicators
@onready var dash_pips: HBoxContainer = $MarginContainer/VBoxContainer/DashPips
@onready var dash_trigger_bar: ProgressBar = $MarginContainer/VBoxContainer/DashTriggerBar
@onready var dash_recovery_bar: ProgressBar = $MarginContainer/VBoxContainer/DashRecoveryBar
 
# Jump indicators
@onready var jump_pips: HBoxContainer = $MarginContainer/VBoxContainer/JumpPips
@onready var jump_trigger_bar: ProgressBar = $MarginContainer/VBoxContainer/JumpTriggerBar

# HP indicators
@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPValueLabel

# Potion indicators
@onready var potion_pips: HBoxContainer = $MarginContainer/VBoxContainer/PotionPips
@onready var potion_trigger_bar: ProgressBar = $MarginContainer/VBoxContainer/PotionTriggerBar
 
const PIP_SIZE = Vector2(16, 16)
const PIP_GAP = 4
 
 
func _ready() -> void:
	player = get_node(player_path)
	
	hp_bar.min_value = 0.0
 
	dash_trigger_bar.min_value = 0.0
	dash_trigger_bar.max_value = player.DASH_TRIGGER_CD
	dash_recovery_bar.min_value = 0.0
	dash_recovery_bar.max_value = player.DASH_RECOVERY_CD
 
	jump_trigger_bar.min_value = 0.0
	jump_trigger_bar.max_value = player.JUMP_TRIGGER_CD
	
	potion_trigger_bar.min_value = 0.0
	potion_trigger_bar.max_value = player.POTION_TRIGGER_CD
 
	_build_pips(dash_pips, player.max_dash_count)
	_build_pips(jump_pips, player.max_jump_count)
	_build_pips(potion_pips, player.POTION_MAX_COUNT)
	
	player.health.health_changed.connect(_on_health_changed)
	_on_health_changed(player.health.current_hp, player.health.max_hp)
 
 
func _process(_delta: float) -> void:
	_update_pips(dash_pips, player.dash_count, player.max_dash_count)
	_update_pips(jump_pips, player.jump_count, player.max_jump_count)
	_update_pips(potion_pips, player.potion_count, player.POTION_MAX_COUNT)
	_update_dash_bars()
	_update_jump_bar()
	_update_potion_bar()
 
func _on_health_changed(current: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current
	hp_label.text = "%d / %d" % [current, max_hp]
 
func _build_pips(container: HBoxContainer, count: int) -> void:
	for child in container.get_children():
		child.queue_free()
 
	container.add_theme_constant_override("separation", PIP_GAP)
 
	for i in count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		container.add_child(pip)
 
 
func _update_pips(container: HBoxContainer, count: int, max_count: int) -> void:
	if container.get_child_count() != max_count:
		_build_pips(container, max_count)
 
	var pips := container.get_children()
	for i in pips.size():
		pips[i].color = Color.WHITE if i < count else Color(0.25, 0.25, 0.25)
 
 
func _update_dash_bars() -> void:
	dash_trigger_bar.value = player.DASH_TRIGGER_CD - player.dash_trigger_timer
	dash_trigger_bar.visible = player.dash_trigger_timer > 0.0
 
	dash_recovery_bar.visible = player.dash_count < player.max_dash_count
	if dash_recovery_bar.visible:
		dash_recovery_bar.value = player.DASH_RECOVERY_CD - player.dash_recovery_timer
 
 
func _update_jump_bar() -> void:
	jump_trigger_bar.value = player.JUMP_TRIGGER_CD - player.jump_trigger_timer
	jump_trigger_bar.visible = player.jump_trigger_timer > 0.0

func _update_potion_bar() -> void:
	potion_trigger_bar.value = player.POTION_TRIGGER_CD - player.potion_trigger_timer
	potion_trigger_bar.visible = player.potion_trigger_timer > 0.0

extends Control
 
@export var player_path: NodePath
var player: mcGreen1
 
@onready var pips_container: HBoxContainer = $DashPips
@onready var trigger_bar: ProgressBar = $TriggerBar
@onready var recovery_bar: ProgressBar = $RecoveryBar
 
const PIP_SIZE = Vector2(16, 16)
const PIP_GAP = 4
 
 
func _ready() -> void:
	player = get_node(player_path)
 
	trigger_bar.min_value = 0.0
	trigger_bar.max_value = player.DASH_TRIGGER_CD
	recovery_bar.min_value = 0.0
	recovery_bar.max_value = player.DASH_RECOVERY
 
	_build_pips()
 
 
func _process(_delta: float) -> void:
	_update_pips()
	_update_bars()
 
 
func _build_pips() -> void:
	for child in pips_container.get_children():
		child.queue_free()
 
	pips_container.add_theme_constant_override("separation", PIP_GAP)
 
	for i in player.max_dash_count:
		var pip := ColorRect.new()
		pip.custom_minimum_size = PIP_SIZE
		pips_container.add_child(pip)
 
 
func _update_pips() -> void:
	# rebuild if max charges changed (e.g. player levelled up mid-run)
	if pips_container.get_child_count() != player.max_dash_count:
		_build_pips()
 
	var pips := pips_container.get_children()
	for i in pips.size():
		pips[i].color = Color.WHITE if i < player.dash_count else Color(0.25, 0.25, 0.25)
 
 
func _update_bars() -> void:
	# Trigger cooldown: counts DOWN from DASH_TRIGGER_CD to 0, so show it filling UP
	trigger_bar.value = player.DASH_TRIGGER_CD - player.dash_trigger_timer
	trigger_bar.visible = player.dash_trigger_timer > 0.0
 
	# Recovery: only meaningful while under max charges
	recovery_bar.visible = player.dash_count < player.max_dash_count
	if recovery_bar.visible:
		recovery_bar.value = player.DASH_RECOVERY - player.dash_recovery_timer

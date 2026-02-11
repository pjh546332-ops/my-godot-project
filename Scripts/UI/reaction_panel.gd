class_name ReactionPanel
extends Control
## 리액션 선택 패널. choose_reaction(attacker, target)로 공격 직전 호출 후 await로 선택값 반환.

signal reaction_choice_made

var _chosen_reaction: ReactionTypes.Reaction = ReactionTypes.Reaction.NO_REACTION

@onready var btn_hold: Button = $HBox/Hold
@onready var btn_dodge: Button = $HBox/Dodge
@onready var btn_block: Button = $HBox/Block
@onready var btn_counter: Button = $HBox/Counter
@onready var label_desc: Label = $Desc

func _ready() -> void:
	if btn_hold:
		btn_hold.pressed.connect(_on_hold_pressed)
	if btn_dodge:
		btn_dodge.pressed.connect(_on_dodge_pressed)
	if btn_block:
		btn_block.pressed.connect(_on_block_pressed)
	if btn_counter:
		btn_counter.pressed.connect(_on_counter_pressed)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()

func setup(_p_battle_manager: BattleManager) -> void:
	hide()

func choose_reaction(attacker: BattleUnit, target: BattleUnit) -> ReactionTypes.Reaction:
	if target.reaction_used_this_round:
		return ReactionTypes.Reaction.NO_REACTION
	if target.default_reaction != ReactionTypes.Reaction.NO_REACTION:
		target.reaction_used_this_round = true
		return target.default_reaction
	if label_desc:
		label_desc.text = "%s is attacking %s. Choose reaction." % [attacker.unit_name, target.unit_name]
	mouse_filter = Control.MOUSE_FILTER_STOP
	show()
	_chosen_reaction = ReactionTypes.Reaction.NO_REACTION
	await reaction_choice_made
	if _chosen_reaction == ReactionTypes.Reaction.DODGE or _chosen_reaction == ReactionTypes.Reaction.GUARD or _chosen_reaction == ReactionTypes.Reaction.COUNTER:
		target.reaction_used_this_round = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()
	return _chosen_reaction

func _on_hold_pressed() -> void:
	_chosen_reaction = ReactionTypes.Reaction.NO_REACTION
	reaction_choice_made.emit()

func _on_dodge_pressed() -> void:
	_chosen_reaction = ReactionTypes.Reaction.DODGE
	reaction_choice_made.emit()

func _on_block_pressed() -> void:
	_chosen_reaction = ReactionTypes.Reaction.GUARD
	reaction_choice_made.emit()

func _on_counter_pressed() -> void:
	_chosen_reaction = ReactionTypes.Reaction.COUNTER
	reaction_choice_made.emit()

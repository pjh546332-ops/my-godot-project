class_name StatsPanel
extends Control
## 우측 상단 스탯 패널. update(unit)으로 표시 갱신.

@onready var title_label: Label = $VBox/Title
@onready var stats_label: Label = $VBox/Stats

func update(unit: BattleUnit) -> void:
	if not unit:
		return
	if title_label:
		title_label.text = unit.unit_name
	if stats_label:
		stats_label.text = (
			"STR %d  AGI %d  INT %d  VIT %d\n"
			+ "ATK %d  DEF %d  Speed %d  HP %d/%d"
		) % [
			unit.strength, unit.agility, unit.intelligence, unit.vitality,
			unit.attack, unit.defense, unit.speed, unit.hp, unit.max_hp
		]

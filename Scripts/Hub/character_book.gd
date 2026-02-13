extends Control
## 캐릭터 관리 UI (펼친 책 한 페이지). 전투 UI와 분리된 허브 전용 씬.

signal request_back_to_hub

const ROSTER_PATH := "/root/AllyRoster"

@onready var character_list: ItemList = $BookHBox/PagesHBox/LeftPage/Margin/VBox/CharacterList
@onready var portrait_rect: TextureRect = $BookHBox/PagesHBox/LeftPage/Margin/VBox/Portrait
@onready var sprite_rect: TextureRect = $BookHBox/PagesHBox/LeftPage/Margin/VBox/Sprite
@onready var name_label: Label = $BookHBox/PagesHBox/RightPage/Margin/VBox/NameLabel
@onready var stats_grid: GridContainer = $BookHBox/PagesHBox/RightPage/Margin/VBox/StatsGrid
@onready var equipment_section: VBoxContainer = $BookHBox/PagesHBox/RightPage/Margin/VBox/EquipmentSection
@onready var skills_section: VBoxContainer = $BookHBox/PagesHBox/RightPage/Margin/VBox/SkillsSection
@onready var back_button: Button = $BookHBox/TopBar/BackButton

var _roster: Node = null
var _current_id: String = ""


func _ready() -> void:
	_roster = get_node_or_null(ROSTER_PATH)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	if character_list:
		character_list.item_selected.connect(_on_character_selected)
	_populate_character_list()
	if character_list and character_list.item_count > 0:
		character_list.select(0)
		_on_character_selected(0)


func _populate_character_list() -> void:
	if not character_list or not _roster:
		return
	if not _roster.has_method("get_roster_ally_ids"):
		return
	character_list.clear()
	var ids: Array = _roster.get_roster_ally_ids()
	for i in range(ids.size()):
		var id_str: String = ids[i]
		var def = _roster.get_definition(id_str)
		var display: String = id_str
		if def and def.display_name != "":
			display = def.display_name
		character_list.add_item(display, null)
		character_list.set_item_metadata(i, id_str)


func _on_character_selected(index: int) -> void:
	if not character_list or index < 0 or index >= character_list.item_count:
		return
	var id_str: String = character_list.get_item_metadata(index)
	if id_str == null or id_str == "":
		id_str = character_list.get_item_text(index)
	show_character(id_str)


func show_character(id: String) -> void:
	_current_id = id
	if not _roster:
		return

	var def = _roster.get_definition(id)
	var prog = _roster.get_progress(id) if _roster.has_method("get_progress") else null

	if name_label:
		name_label.text = id
		if def and def.display_name != "":
			name_label.text = def.display_name

	if portrait_rect:
		if def and def.portrait:
			portrait_rect.texture = def.portrait
			portrait_rect.visible = true
		else:
			portrait_rect.texture = null
			portrait_rect.visible = false

	if sprite_rect:
		if def and def.sprite_3d:
			sprite_rect.texture = def.sprite_3d
			sprite_rect.visible = true
		else:
			sprite_rect.texture = null
			sprite_rect.visible = false

	# 스탯 그리드: 자식 라벨 순서대로 STR/VIT/AGI/Level/EXP 등
	_update_stats_grid(def, prog)

	# 장비: 미구현
	_update_equipment_section()

	# 스킬
	_update_skills_section(def)


func _update_stats_grid(def, prog) -> void:
	if not stats_grid:
		return
	var strength: int = 0
	var vitality: int = 0
	var agility: int = 0
	var level: int = 1
	var exp_val: int = 0
	if def:
		strength = def.base_strength
		vitality = def.base_vitality
		agility = def.base_agility
	if prog:
		strength += prog.bonus_strength
		vitality += prog.bonus_vitality
		agility += prog.bonus_agility
		level = prog.level
		exp_val = prog.exp

	var max_hp: int = vitality * 10
	var str_val: Label = stats_grid.get_node_or_null("STRValue")
	var vit_val: Label = stats_grid.get_node_or_null("VITValue")
	var agi_val: Label = stats_grid.get_node_or_null("AGIValue")
	var lv_val: Label = stats_grid.get_node_or_null("LevelExpValue")
	var hp_val: Label = stats_grid.get_node_or_null("MaxHPValue")
	if str_val:
		str_val.text = str(strength)
	if vit_val:
		vit_val.text = str(vitality)
	if agi_val:
		agi_val.text = str(agility)
	if lv_val:
		lv_val.text = "%d / %d" % [level, exp_val]
	if hp_val:
		hp_val.text = str(max_hp)


func _update_equipment_section() -> void:
	if not equipment_section:
		return
	var lbl: Label = equipment_section.get_node_or_null("PlaceholderLabel")
	if lbl:
		lbl.text = "장비 (미구현)"


func _update_skills_section(def) -> void:
	if not skills_section:
		return
	for c in skills_section.get_children():
		if c is Label and c.name != "SkillsTitle":
			c.queue_free()
	var title: Label = skills_section.get_node_or_null("SkillsTitle")
	if not title:
		title = Label.new()
		title.name = "SkillsTitle"
		title.text = "스킬"
		skills_section.add_child(title)
		skills_section.move_child(title, 0)

	if def and def.skills.size() > 0:
		for sk in def.skills:
			var line := Label.new()
			line.text = sk.display_name if sk.display_name != "" else sk.id
			skills_section.add_child(line)
	else:
		var line := Label.new()
		line.text = "(없음)"
		skills_section.add_child(line)


func _on_back_pressed() -> void:
	request_back_to_hub.emit()

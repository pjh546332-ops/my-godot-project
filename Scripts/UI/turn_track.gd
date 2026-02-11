class_name TurnTrack
extends Control
## 고정 슬롯(13개). 가장 빠른 유닛이 중앙, 다음이 중앙 오른쪽·왼쪽… 순으로 배치. 나머지 슬롯은 숨김.

var battle_manager: BattleManager
var _track_items: Dictionary = {}  # BattleUnit -> PanelContainer
var _active_unit: BattleUnit = null
var _slots: Array[Control] = []  # 고정 슬롯 13개 (인덱스 0=왼끝, 6=중앙, 12=오른끝)
var _slots_container: HBoxContainer = null

const PORTRAIT_SIZE := 24
const SLOT_COUNT := 13
const CENTER_SLOT_INDEX := 6  # 0-based, 13개면 6이 중앙

func set_active_unit_by_ref(unit: BattleUnit) -> void:
	_apply_highlight(_active_unit, false)
	_active_unit = unit
	_apply_highlight(unit, true)

func set_active_unit(unit_id: int) -> void:
	pass

func setup(p_battle_manager: BattleManager) -> void:
	battle_manager = p_battle_manager
	_build_fixed_slots()
	if battle_manager:
		battle_manager.state_changed.connect(_refresh)
		battle_manager.resolve_done.connect(_refresh)
		battle_manager.current_planning_unit_changed.connect(set_active_unit_by_ref)
	_refresh()

func _build_fixed_slots() -> void:
	# 기존 자식 제거 후 단일 HBoxContainer + 13 슬롯 생성
	for c in get_children():
		c.queue_free()
	_slots.clear()
	_slots_container = HBoxContainer.new()
	_slots_container.name = "SlotsContainer"
	_slots_container.add_theme_constant_override("separation", 4)
	_slots_container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots_container)
	for i in SLOT_COUNT:
		var slot: Control = PanelContainer.new()
		slot.name = "Slot_%d" % i
		slot.custom_minimum_size = Vector2(PORTRAIT_SIZE + 28, PORTRAIT_SIZE + 4)
		slot.visible = false
		_slots_container.add_child(slot)
		_slots.append(slot)

func _refresh(_arg: Variant = null) -> void:
	if not battle_manager or _slots.is_empty():
		return
	_track_items.clear()
	# 모든 슬롯 비우고 숨김
	for slot in _slots:
		for c in slot.get_children():
			c.queue_free()
		slot.visible = false
		_set_panel_style(slot as PanelContainer, false)
	# 전체 유닛을 speed 내림차순(가장 빠른 것 먼저)
	var units: Array[BattleUnit] = []
	for u in battle_manager.ally_units_sorted:
		if u.is_alive():
			units.append(u)
	for u in battle_manager.enemy_units:
		if u.is_alive():
			units.append(u)
	units.sort_custom(func(a: BattleUnit, b: BattleUnit) -> bool:
		if a.speed != b.speed:
			return a.speed > b.speed
		return a.name < b.name
	)
	# 배치 순서: 중앙 → 오른쪽 → 왼쪽 → … (인덱스: 6, 7, 5, 8, 4, 9, 3, 10, 2, 11, 1, 12, 0)
	var slot_order: Array[int] = [6, 7, 5, 8, 4, 9, 3, 10, 2, 11, 1, 12, 0]
	for i in range(units.size()):
		if i >= SLOT_COUNT:
			break
		var slot_idx: int = slot_order[i]
		var u: BattleUnit = units[i]
		var panel: PanelContainer = _make_track_item(u)
		_track_items[u] = panel
		var slot: Control = _slots[slot_idx]
		slot.add_child(panel)
		slot.visible = true
	set_active_unit_by_ref(battle_manager._current_planning_unit())

func _make_track_item(u: BattleUnit) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "Track_%s" % u.name
	panel.custom_minimum_size = Vector2(PORTRAIT_SIZE + 28, PORTRAIT_SIZE + 4)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var rect := ColorRect.new()
	rect.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	rect.color = Color.DARK_GREEN if u.is_ally() else Color.DARK_RED
	box.add_child(rect)
	var lbl := Label.new()
	lbl.text = "%s(%d)" % [u.name, u.speed]
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	panel.add_child(box)
	_set_panel_style(panel, false)
	return panel

func _set_panel_style(panel: PanelContainer, active: bool) -> void:
	if not panel:
		return
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.35, 0.35, 0.2, 0.9)
		style.border_color = Color(1.0, 0.9, 0.3)
		style.set_border_width_all(2)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	else:
		style.bg_color = Color(0.2, 0.2, 0.2, 0.6)
		style.set_border_width_all(0)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_right = 4
		style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)

func _apply_highlight(unit: BattleUnit, active: bool) -> void:
	if not unit:
		return
	var item: PanelContainer = _track_items.get(unit)
	if is_instance_valid(item):
		_set_panel_style(item, active)

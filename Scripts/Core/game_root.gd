extends Node
## 메인 루트. ModeHost 아래에서 Explore/Hub/Battle/Dialogue 씬을 인스턴스 교체로 전환.

const DungeonMapState = preload("res://Scripts/Explore/Map/dungeon_map_state.gd")
enum GameMode {
	EXPLORE,
	HUB,
	DUNGEON_PREP,
	BATTLE,
	DIALOGUE
}

const HUB_SCENE := "res://Scenes/Hub/HubScene.tscn"
const CHARACTER_BOOK_SCENE := "res://Scenes/Hub/CharacterBook.tscn"
const PREP_SCENE := "res://Scenes/DungeonPrep/DungeonPrepScene.tscn"
const EXPLORE_SCENE := "res://Scenes/Explore/ExploreScene.tscn"
const FIRST_PERSON_ROOM_SCENE := "res://Scenes/Explore/FirstPersonRoom.tscn"
const DEV_MENU_SCENE := "res://Scenes/Dev/DevMenuScene.tscn"
const BATTLE_SCENE_3D := "res://Scenes/_Archive/BattleLegacy/BattleScene3D.tscn"

const MODE_SCENES: Dictionary = {
	GameMode.EXPLORE: EXPLORE_SCENE,
	GameMode.HUB: HUB_SCENE,
	GameMode.DUNGEON_PREP: PREP_SCENE,
	GameMode.BATTLE: HUB_SCENE,  # 레거시 전투 비활성화: 호출 시 허브로. 복구 시 _Archive/BattleLegacy 경로로 교체
	GameMode.DIALOGUE: "res://Scenes/Dialogue/DialogueScene.tscn",
}

var _current_mode: GameMode = GameMode.HUB
var _current_scene: Node = null
var _door_side: String = "RIGHT"
var _is_fading: bool = false
var _dungeon_map: DungeonMapState = null

@onready var mode_host: Node = $ModeHost
@onready var title_screen: Control = $CanvasLayer/TitleScreen
@onready var fade_rect: ColorRect = $CanvasLayer/FadeRect


func _clear_mode_host() -> void:
	if not mode_host:
		return
	for c in mode_host.get_children():
		c.queue_free()
	_current_scene = null


func _ready() -> void:
	if not mode_host:
		return
	# 기본 모드로 허브 씬을 미리 로드하되, UI는 감춰둔다.
	switch_mode(GameMode.HUB)
	if _current_scene:
		_current_scene.visible = false

	# 타이틀 화면에서 "새 게임" 요청 시 허브 UI를 보여준다.
	if title_screen and title_screen.has_signal("new_game_requested"):
		title_screen.new_game_requested.connect(_on_new_game_requested)

	if fade_rect:
		fade_rect.visible = false
		var c := fade_rect.modulate
		c.a = 0.0
		fade_rect.modulate = c

	_dungeon_map = DungeonMapState.new()
	_dungeon_map.init_grid()


## 모드 전환. ModeHost 자식을 해당 씬 인스턴스로 교체.
func switch_mode(mode: GameMode) -> void:
	var path: String = MODE_SCENES.get(mode, "")
	if path.is_empty():
		push_error("GameRoot: Unknown mode %s" % mode)
		return

	_current_mode = mode
	switch_to(path)


## 경로 기반 전환. ModeHost 자식을 전부 비우고 새 씬을 로드/연결.
func switch_to(path: String) -> void:
	if mode_host:
		print("[GameRoot] switch_to(%s) - 기존 자식 수: %d" % [path, mode_host.get_child_count()])
		for child in mode_host.get_children():
			child.queue_free()
		_current_scene = null

	var packed: Resource = load(path) as PackedScene
	if not packed:
		push_error("GameRoot: Failed to load %s" % path)
		return

	var inst: Node = packed.instantiate()
	mode_host.add_child(inst)
	_current_scene = inst
	print("[GameRoot] switch_to(%s) - 새 자식 수: %d" % [path, mode_host.get_child_count()])

	# ExploreScene door_side 전달 (set_start_side 우선)
	if path == EXPLORE_SCENE:
		if inst.has_method("set_start_side"):
			inst.set_start_side(_door_side)
		elif "door_side" in inst:
			inst.door_side = _door_side

	# 맵 상태 주입 (ExploreScene, FirstPersonRoom 등)
	if _dungeon_map and inst.has_method("set_map_state"):
		inst.set_map_state(_dungeon_map)

	if GameState:
		GameState.current_mode = _mode_to_game_state_enum(_current_mode)

	# Hub/DungeonPrep/Explore 등 씬별 신호 연결
	if inst.has_signal("request_dungeon_prep"):
		inst.request_dungeon_prep.connect(go_to_prep)

	if inst.has_signal("request_explore_start"):
		inst.request_explore_start.connect(go_to_explore)

	if inst.has_signal("request_back_to_hub"):
		inst.request_back_to_hub.connect(go_to_hub)
	if inst.has_signal("request_character_book"):
		inst.request_character_book.connect(_on_request_character_book)

	# Dev 메뉴에서 테스트 씬 요청 신호 연결
	if inst.has_signal("request_test_battle_3d"):
		inst.request_test_battle_3d.connect(_on_request_test_battle_3d)
	if inst.has_signal("request_test_first_person_room"):
		inst.request_test_first_person_room.connect(_on_request_test_first_person_room)
	if inst.has_signal("request_test_hub"):
		inst.request_test_hub.connect(_on_request_test_hub)
	if inst.has_signal("request_test_explore_2d"):
		inst.request_test_explore_2d.connect(_on_request_test_explore_2d)

	# ExploreScene / FirstPersonRoom 루프 신호 연결
	if inst.has_signal("request_enter_room"):
		inst.request_enter_room.connect(_on_request_enter_room)

	if inst.has_signal("request_exit_room"):
		inst.request_exit_room.connect(_on_request_exit_room)

	if _current_mode == GameMode.BATTLE:
		var bm: Node = inst.get_node_or_null("BattleManager")
		if bm and bm.has_signal("battle_ended"):
			bm.battle_ended.connect(_on_battle_ended)


func _mode_to_game_state_enum(mode: GameMode) -> GameState.GameMode:
	match mode:
		GameMode.EXPLORE: return GameState.GameMode.EXPLORE
		GameMode.HUB: return GameState.GameMode.HUB
		GameMode.DUNGEON_PREP: return GameState.GameMode.HUB
		GameMode.BATTLE: return GameState.GameMode.BATTLE
		GameMode.DIALOGUE: return GameState.GameMode.DIALOGUE
	return GameState.GameMode.HUB


## 외부에서 호출: 전투 시작 등
func goto_battle() -> void:
	switch_mode(GameMode.BATTLE)


func goto_hub() -> void:
	switch_mode(GameMode.HUB)


func goto_explore() -> void:
	switch_mode(GameMode.EXPLORE)


## Hub/DungeonPrep/Explore 전용 래퍼 (씬 신호에서 호출)
func go_to_hub() -> void:
	goto_hub()


func _on_request_character_book() -> void:
	switch_to(CHARACTER_BOOK_SCENE)


func go_to_prep() -> void:
	switch_mode(GameMode.DUNGEON_PREP)


func go_to_explore() -> void:
	goto_explore()


func goto_dialogue() -> void:
	switch_mode(GameMode.DIALOGUE)


## 새 게임 시작: 프롤로그 인트로 → 전투 → 승리 후 대화 → 허브
func start_new_game() -> void:
	print("[GameRoot] start_new_game")

	# 기본 상태 초기화
	_door_side = "RIGHT"
	if _dungeon_map:
		_dungeon_map.init_grid()

	_start_dev_menu()


func _start_dev_menu() -> void:
	print("[GameRoot] Start DevMenu")
	_current_mode = GameMode.HUB  # Dev 메뉴는 HUB와 유사한 상태로 취급
	if GameState:
		GameState.current_mode = _mode_to_game_state_enum(_current_mode)
	_fade_and_switch_to(DEV_MENU_SCENE)


func _start_prologue_intro() -> void:
	print("[GameRoot] Prologue: start intro dialogue")
	_clear_mode_host()

	_current_mode = GameMode.DIALOGUE
	if GameState:
		GameState.current_mode = _mode_to_game_state_enum(_current_mode)

	var dlg_packed: PackedScene = preload("res://Scenes/Dialogue/DialogueScene.tscn")
	if not dlg_packed:
		push_error("GameRoot: DialogueScene 프리로드 실패 (prologue intro)")
		return

	var dlg: Node = dlg_packed.instantiate()
	if "dialogue_file_path" in dlg:
		dlg.dialogue_file_path = "res://Data/Dialogue/intro.json"
	else:
		push_error("GameRoot: DialogueScene에 dialogue_file_path 프로퍼티가 없습니다.")

	if dlg.has_signal("dialogue_finished"):
		dlg.dialogue_finished.connect(_on_prologue_intro_finished)
	else:
		push_error("GameRoot: DialogueScene에 dialogue_finished 시그널이 없습니다.")

	mode_host.add_child(dlg)
	_current_scene = dlg


func _on_prologue_intro_finished() -> void:
	print("[GameRoot] Prologue: intro finished -> battle")
	_clear_mode_host()

	_current_mode = GameMode.BATTLE
	if GameState:
		GameState.current_mode = _mode_to_game_state_enum(_current_mode)

	var battle_packed: PackedScene = preload("res://Scenes/_Archive/BattleLegacy/BattleScene.tscn")
	if not battle_packed:
		push_error("GameRoot: BattleScene 프리로드 실패 (prologue)")
		return

	var battle: Node = battle_packed.instantiate()
	# BattleScene에서 승패 시그널을 재전달하도록 기대한다.
	if battle.has_signal("battle_finished"):
		battle.battle_finished.connect(_on_prologue_battle_finished)
	else:
		push_error("GameRoot: BattleScene에 battle_finished 시그널이 없습니다.")

	# 기존 BattleManager → GameState 기록 흐름도 유지
	var bm: Node = battle.get_node_or_null("BattleManager")
	if bm and bm.has_signal("battle_ended"):
		bm.battle_ended.connect(_on_battle_ended)

	mode_host.add_child(battle)
	_current_scene = battle


func _on_prologue_battle_finished(victory: bool) -> void:
	print("[GameRoot] Prologue: battle finished, victory=", victory)
	if victory:
		_start_prologue_after_dialogue()
	else:
		# MVP: 패배하면 전투 재시작 (인트로는 스킵하고 전투만 재시작)
		_on_prologue_intro_finished()


func _start_prologue_after_dialogue() -> void:
	print("[GameRoot] Prologue: start after-win dialogue")
	_clear_mode_host()

	_current_mode = GameMode.DIALOGUE
	if GameState:
		GameState.current_mode = _mode_to_game_state_enum(_current_mode)

	var dlg_packed: PackedScene = preload("res://Scenes/Dialogue/DialogueScene.tscn")
	if not dlg_packed:
		push_error("GameRoot: DialogueScene 프리로드 실패 (prologue after)")
		return

	var dlg: Node = dlg_packed.instantiate()
	if "dialogue_file_path" in dlg:
		dlg.dialogue_file_path = "res://Data/Dialogue/prologue_after_win.json"
	else:
		push_error("GameRoot: DialogueScene에 dialogue_file_path 프로퍼티가 없습니다.")

	if dlg.has_signal("dialogue_finished"):
		dlg.dialogue_finished.connect(_on_prologue_after_finished)
	else:
		push_error("GameRoot: DialogueScene에 dialogue_finished 시그널이 없습니다.")

	mode_host.add_child(dlg)
	_current_scene = dlg


func _on_prologue_after_finished() -> void:
	print("[GameRoot] Prologue: after dialogue finished -> hub")
	# 허브 모드로 전환 (기존 허브 흐름/시그널 연결 재사용)
	goto_hub()


func _on_battle_ended(ally_won: bool) -> void:
	if not GameState:
		return
	var rounds: int = 0
	if _current_scene:
		var bm: Node = _current_scene.get_node_or_null("BattleManager")
		if bm and "current_round" in bm:
			rounds = bm.current_round
	GameState.set_battle_result(ally_won, rounds)


func _on_request_test_battle_3d() -> void:
	print("[GameRoot] DevMenu: Test Battle 3D")
	_current_mode = GameMode.BATTLE
	_fade_and_switch_to(BATTLE_SCENE_3D)


func _on_request_test_first_person_room() -> void:
	print("[GameRoot] DevMenu: Test First Person Room")
	_current_mode = GameMode.EXPLORE
	_fade_and_switch_to(FIRST_PERSON_ROOM_SCENE)


func _on_request_test_hub() -> void:
	print("[GameRoot] DevMenu: Test Hub")
	_current_mode = GameMode.HUB
	_fade_and_switch_to(HUB_SCENE)


func _on_request_test_explore_2d() -> void:
	print("[GameRoot] DevMenu: Test Explore 2D")
	_current_mode = GameMode.EXPLORE
	_fade_and_switch_to(EXPLORE_SCENE)


func _on_new_game_requested() -> void:
	# 타이틀 숨기기
	if title_screen:
		title_screen.visible = false

	# 새 게임 플로우 시작: 인트로 대화 → 허브
	start_new_game()


func _fade_and_switch_to(path: String) -> void:
	if not fade_rect:
		switch_to(path)
		return
	if _is_fading:
		return
	_is_fading = true

	fade_rect.visible = true
	var c := fade_rect.modulate
	c.a = 0.0
	fade_rect.modulate = c

	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.3)
	tween.finished.connect(func() -> void:
		switch_to(path)
		var tween_in := create_tween()
		tween_in.tween_property(fade_rect, "modulate:a", 0.0, 0.3)
		tween_in.finished.connect(func() -> void:
			fade_rect.visible = false
			_is_fading = false
		)
	)


func _on_request_enter_room(door_side: String) -> void:
	_door_side = door_side
	print("[GameRoot] request_enter_room side=", door_side)
	_fade_and_switch_to(FIRST_PERSON_ROOM_SCENE)


func _on_request_exit_room(door_side: String) -> void:
	_door_side = door_side
	print("[GameRoot] request_exit_room side=", door_side)
	_fade_and_switch_to(EXPLORE_SCENE)

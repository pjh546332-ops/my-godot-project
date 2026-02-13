extends Node2D
## 허브 모드 씬. GameRoot에서 ModeHost로 로드됨.

signal menu_selected(menu_id: String, display_name: String)
signal request_dungeon_prep
signal request_character_book

const GARDEN_VIEW_SCENE: PackedScene = preload("res://Scenes/Hub/Views/GardenView.tscn")
const LIBRARY_VIEW_SCENE: PackedScene = preload("res://Scenes/Hub/Views/LibraryView.tscn")

@onready var sub_view_host: Control = $"HubUI/RootHBox/ContentPanel/ContentMargin/SubViewHost"

@onready var dungeon_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/DungeonButton"
@onready var hub_party_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/HubPartyButton"
@onready var shop_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/ShopButton"
@onready var management_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/ManagementButton"
@onready var garden_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/GardenButton"
@onready var library_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/LibraryButton"
@onready var rest_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/RestButton"
@onready var storage_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/StorageButton"
@onready var characters_button: Button = $"HubUI/RootHBox/SideMenuPanel/SideMargin/SideVBox/CharactersButton"


func _ready() -> void:
	_connect_menu_buttons()
	# 초기 상태에서는 허브/던전 등 기본 텍스트만 사용하고, 서브 뷰는 비워둔다.
	_on_menu_selected("dungeon", "던전")


func _connect_menu_buttons() -> void:
	dungeon_button.pressed.connect(_on_dungeon_button_pressed)
	hub_party_button.pressed.connect(func() -> void: _on_menu_selected("hub_party", "거점/파티"))
	if characters_button:
		characters_button.pressed.connect(_on_characters_pressed)
	shop_button.pressed.connect(func() -> void: _on_menu_selected("shop", "상점"))
	management_button.pressed.connect(func() -> void: _on_menu_selected("management", "관리"))
	garden_button.pressed.connect(func() -> void: _on_menu_selected("garden", "정원"))
	library_button.pressed.connect(func() -> void: _on_menu_selected("library", "도서관"))
	rest_button.pressed.connect(func() -> void: _on_menu_selected("rest", "휴식"))
	storage_button.pressed.connect(func() -> void: _on_menu_selected("storage", "창고"))


func _on_menu_selected(menu_id: String, display_name: String) -> void:
	_update_main_title(display_name)

	# 정원/도서관의 경우 서브 뷰를 로드하고, 그 외 메뉴는 서브 뷰를 비운다.
	match menu_id:
		"garden":
			_show_sub_view(GARDEN_VIEW_SCENE)
		"library":
			_show_sub_view(LIBRARY_VIEW_SCENE)
		_:
			_clear_sub_view()

	print("[HubScene] 메뉴 선택: ", menu_id, " (", display_name, ")")
	menu_selected.emit(menu_id, display_name)


func _on_dungeon_button_pressed() -> void:
	_on_menu_selected("dungeon", "던전")
	request_dungeon_prep.emit()


func _on_characters_pressed() -> void:
	request_character_book.emit()


func _update_main_title(text: String) -> void:
	# 현재는 메인 타이틀 텍스트를 별도 라벨에 표시하지 않지만,
	# 향후 상단 바 등을 추가할 경우를 대비해 분리해 둔다.
	pass


func _clear_sub_view() -> void:
	if not sub_view_host:
		return
	for child in sub_view_host.get_children():
		child.queue_free()


func _show_sub_view(scene: PackedScene) -> void:
	if not sub_view_host or not scene:
		return
	_clear_sub_view()
	var inst := scene.instantiate()
	if inst:
		sub_view_host.add_child(inst)

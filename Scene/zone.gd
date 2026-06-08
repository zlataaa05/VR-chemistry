extends Node3D

# Ссылки
@onready var label_task = $"../Screen_learn/SubViewport/UI/Pars_tasks"
@onready var label_result = $"../Screen_learn/SubViewport/UI/Pars_result"
@onready var label_info = $"../Screen_learn/SubViewport/UI/Pars_info"
@onready var label_mol = $"../Screen_learn/SubViewport/UI/TextureButton"
@onready var area_zone: Area3D = $MeshInstance3D5/Area_zone
@onready var area_button = $"../Button/MeshInstance3D2/Area_button"

# Флаги
var is_button_hovered: bool = false

func _ready():
	if not area_button:
		print("Кнопка не найдена")
	# Настройка сигналов
	_setup_button_signals()
	_setup_zone_signals()
	
func _setup_button_signals():
	# Подключаем сигналы для кнопки
	if area_button:
		area_button.area_entered.connect(_on_button_area_entered)
		area_button.area_exited.connect(_on_button_area_exited)
		print("Сигналы кнопки подключены")
	else:
		print("area_button не найден")

func _setup_zone_signals():
	# Подключаем сигналы для зоны проверки
	if area_zone:
		area_zone.area_entered.connect(_on_zone_area_entered)
		print("Сигналы зоны подключены")
	else:
		print("area_zone не найден")

func _is_hand(node: Node) -> bool:
	if node.name.to_lower().contains("hand"):
		print("Это рука 1")
		return true
	
	if node.is_class("XRToolsHand") or node.get_script() == preload("res://addons/godot-xr-tools/hands/hand.gd"):
		print("Это рука 2")
		return true
	
	# Проверяем родителя
	var parent = node.get_parent()
	if parent and (parent.name.to_lower().contains("hand") or parent.is_class("XRToolsHand")):
		print("Это рука 3")
		return true
	
	return false

func _on_button_area_entered(area: Area3D):
	# Проверяем, что вошедшая Area - это рука
	if _is_hand(area):
		print("Рука вошла")
		is_button_hovered = true
		# Очищаем label_task, label_info, label_mol
		if label_task:
			label_task.text = ""
		if label_info:
			label_info.text = ""
		
		# Выводим надпись в label_result
		if label_result:
			label_result.text = "Задание выполнено"

func _on_button_area_exited(area: Area3D):
	print("Рука вышла")
	is_button_hovered = false

func _on_zone_area_entered(area: Area3D):
	# Проверяем, что вошедшая Area - это область флага
	if area.name.to_lower().contains("flag"):
		print("Flag вошел в зону: ", area.name)
		
		# Получаем корневой узел флага (родительский узел Area)
		var flag_root = area.get_parent()
		
		print("Дочерние узлы флага (атомы и связи):")
		_print_children(flag_root, 0)

func _print_children(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	
	for child in node.get_children():
		_print_children(child, indent_level + 1)

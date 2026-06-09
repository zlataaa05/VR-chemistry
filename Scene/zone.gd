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
var main_node: Node = null  # Ссылка на main.gd (из MAIN_LEARN)

func _ready():
	# Ищем main_node (скрипт main.gd) в дереве сцены
	_find_main_node()
	
	_setup_button_signals()
	_setup_zone_signals()
	
func _find_main_node():
	# Ищем любой узел, у которого есть метод check_molecule_structure (это main.gd)
	main_node = _find_node_with_method(get_tree().root, "check_molecule_structure")
	
	if main_node:
		print("Найден main_node с методом check_molecule_structure: ", main_node.name)
		print("Путь к узлу: ", main_node.get_path())
	else:
		print("main_node с методом check_molecule_structure НЕ НАЙДЕН")
		print("Дерево сцены:")
		_print_tree(get_tree().root, 0)

func _find_node_with_method(root: Node, method_name: String) -> Node:
	if root.has_method(method_name):
		return root
	for child in root.get_children():
		var result = _find_node_with_method(child, method_name)
		if result:
			return result
	return null

func _print_tree(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree(child, indent_level + 1)

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
		return true
	
	if node.is_class("XRToolsHand") or node.get_script() == preload("res://addons/godot-xr-tools/hands/hand.gd"):
		return true
	
	var parent = node.get_parent()
	if parent and (parent.name.to_lower().contains("hand") or parent.is_class("XRToolsHand")):
		return true
	
	return false

func _on_button_area_entered(area: Area3D):
	if _is_hand(area):
		print("Рука вошла в кнопку")
		is_button_hovered = true
		if label_task:
			label_task.text = ""
		if label_info:
			label_info.text = ""

func _on_button_area_exited(area: Area3D):
	print("Рука вышла из кнопки")
	is_button_hovered = false

func _on_zone_area_entered(area: Area3D):
	if area.name.to_lower().contains("flag"):
		print("Flag вошел в зону: ", area.name)
		var flag_root = area.get_parent()
		
		# Ожидаемая структура для H2O
		var expected_h2o = {
			"atoms": ["H", "H", "O"],
			"bonds": [["H", "O"], ["H", "O"]]
		}
		
		if main_node and main_node.has_method("check_molecule_structure"):
			var is_correct = main_node.check_molecule_structure(flag_root, expected_h2o)
			print("Результат проверки: ", is_correct)
			if is_correct:
				if label_result:
					label_result.text = "Задание выполнено"
			else:
				if label_result:
					label_result.text = "Неправильная структура"
		else:
			print("main_node не найден или метод check_molecule_structure отсутствует")
			if label_result:
				label_result.text = "Ошибка проверки"

func _print_children(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_children(child, indent_level + 1)

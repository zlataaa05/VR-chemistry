extends Node3D

# Ссылки для задания 1
@onready var label_task_1 = $"../Screen_learn/SubViewport/UI/Pars_task1"
@onready var label_mol_1 = $"../Screen_learn/SubViewport/UI/TextureButton1"

# Ссылки для задания 2
@onready var label_task_2 = $"../Screen_learn/SubViewport/UI/Pars_task2"
@onready var label_mol_2 = $"../Screen_learn/SubViewport/UI/TextureButton2"

# Ссылки для задания 3
@onready var label_task_3 = $"../Screen_learn/SubViewport/UI/Pars_task3"
@onready var label_mol_3 = $"../Screen_learn/SubViewport/UI/TextureButton3"

@onready var label_result = $"../Screen_learn/SubViewport/UI/Pars_result"
@onready var area_zone: Area3D = $MeshInstance3D5/Area_zone
@onready var area_button = $"../Button/MeshInstance3D2/Area_button"

# Ссылки на теоретические label
@onready var label_info_1 = $"../Screen_info/SubViewport/UI/Label_info1"
@onready var label_info_2 = $"../Screen_info/SubViewport/UI/Label_info2"
@onready var label_info_3 = $"../Screen_info/SubViewport/UI/Label_info3"


# Ссылки на справочные label
@onready var label_header = $"../Screen_info/SubViewport/UI/Label"
@onready var label_pointer = $"../Screen_info/SubViewport/UI/Label4"
@onready var label_des_pointer = $"../Screen_info/SubViewport/UI/Label2"
@onready var label_atoms = $"../Screen_info/SubViewport/UI/Label5"
@onready var label_des_atoms = $"../Screen_info/SubViewport/UI/Label3"
@onready var label_flag = $"../Screen_info/SubViewport/UI/Label6"
@onready var label_des_flag = $"../Screen_info/SubViewport/UI/Label7"

# Флаги
var is_button_hovered: bool = false
var main_node: Node = null  # Ссылка на main.gd (из MAIN_LEARN)
var current_task: int = 1  # Текущее задание (1, 2 или 3)
var task_completed: bool = false  # Флаг, что задание уже выполнено
var current_flag_root: Node3D = null  # Текущий флаг в зоне

func _ready():
	# Ищем main_node (скрипт main.gd) в дереве сцены
	_find_main_node()
	_setup_button_signals()
	_setup_zone_signals()
	_update_task_visibility()

# Обновляем видимость элементов UI в зависимости от текущего задания
func _update_task_visibility():
	match current_task:
		1:
			if label_task_1: label_task_1.visible = true
			if label_mol_1: label_mol_1.visible = true
			if label_task_2: label_task_2.visible = false
			if label_mol_2: label_mol_2.visible = false
			if label_task_3: label_task_3.visible = false
			if label_mol_3: label_mol_3.visible = false
			
			# Показываем справочные label, скрываем теоретические
			_show_reference_labels(true)
			if label_info_1: label_info_1.visible = false
			if label_info_2: label_info_2.visible = false
			if label_info_3: label_info_3.visible = false
			
		2:
			if label_task_1: label_task_1.visible = false
			if label_mol_1: label_mol_1.visible = false
			if label_task_2: label_task_2.visible = true
			if label_mol_2: label_mol_2.visible = true
			if label_task_3: label_task_3.visible = false
			if label_mol_3: label_mol_3.visible = false
			
			# Показываем теоретический label_info_1, скрываем справочные
			_show_reference_labels(false)
			if label_info_1: label_info_1.visible = true
			if label_info_2: label_info_2.visible = false
			if label_info_3: label_info_3.visible = false
			
		3:
			if label_task_1: label_task_1.visible = false
			if label_mol_1: label_mol_1.visible = false
			if label_task_2: label_task_2.visible = false
			if label_mol_2: label_mol_2.visible = false
			if label_task_3: label_task_3.visible = true
			if label_mol_3: label_mol_3.visible = true
			
			# Показываем теоретический label_info_2, скрываем остальные
			_show_reference_labels(false)
			if label_info_1: label_info_1.visible = false
			if label_info_2: label_info_2.visible = true
			if label_info_3: label_info_3.visible = false

# Показываем/скрываем все справочные label
func _show_reference_labels(show: bool):
	if label_header: label_header.visible = show
	if label_pointer: label_pointer.visible = show
	if label_des_pointer: label_des_pointer.visible = show
	if label_atoms: label_atoms.visible = show
	if label_des_atoms: label_des_atoms.visible = show
	if label_flag: label_flag.visible = show
	if label_des_flag: label_des_flag.visible = show

# Ищем любой узел, у которого есть метод check_molecule_structure (это main.gd)
func _find_main_node():
	main_node = _find_node_with_method(get_tree().root, "check_molecule_structure")
	if main_node:
		print("Найден main_node с методом check_molecule_structure: ", main_node.name)
		print("Путь к узлу: ", main_node.get_path())
	else:
		print("main_node с методом check_molecule_structure НЕ НАЙДЕН")
		print("Дерево сцены:")
		_print_tree(get_tree().root, 0)

# Ищем узел с указанным методом
func _find_node_with_method(root: Node, method_name: String) -> Node:
	if root.has_method(method_name):
		return root
	for child in root.get_children():
		var result = _find_node_with_method(child, method_name)
		if result:
			return result
	return null

# Выводим дерево узлов в консоль (отладка)
func _print_tree(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree(child, indent_level + 1)

# Подключаем сигналы area_entered и area_exited для кнопки
func _setup_button_signals():
	# Подключаем сигналы для кнопки
	if area_button:
		area_button.area_entered.connect(_on_button_area_entered)
		area_button.area_exited.connect(_on_button_area_exited)
		#print("Сигналы кнопки подключены")
	else:
		print("area_button не найден")

# Подключаем сигнал area_entered для зоны проверки
func _setup_zone_signals():
	# Подключаем сигналы для зоны проверки
	if area_zone:
		area_zone.area_entered.connect(_on_zone_area_entered)
		#print("Сигналы зоны подключены")
	else:
		print("area_zone не найден")

# Проверяем, является ли вошедший объект рукой
func _is_hand(node: Node) -> bool:
	if node.name.to_lower().contains("hand"):
		return true
	
	if node.is_class("XRToolsHand") or node.get_script() == preload("res://addons/godot-xr-tools/hands/hand.gd"):
		return true
	
	var parent = node.get_parent()
	if parent and (parent.name.to_lower().contains("hand") or parent.is_class("XRToolsHand")):
		return true
	
	return false

# Удаляем флаг и все его дочерние узлы (атомы и связи)
func _delete_flag_with_molecule(flag_root: Node3D):
	# Удаляем флаг со всеми дочерними узлами (атомами и связями)
	if flag_root and is_instance_valid(flag_root):
		#print("Удаление флага с молекулой: ", flag_root.name)
		flag_root.queue_free()

# Обработчик входа руки в зону кнопки (удаляем молекулу и переключаем задание)
func _on_button_area_entered(area: Area3D):
	if _is_hand(area) and task_completed:
		#print("Рука вошла в кнопку")
		is_button_hovered = true
		
		# Удаляем текущую молекулу из сцены
		if current_flag_root:
			_delete_flag_with_molecule(current_flag_root)
			current_flag_root = null
		
		# Переход к следующему заданию
		if current_task < 3:
			current_task += 1
			task_completed = false
			_update_task_visibility()
			if label_result:
				label_result.text = ""
		elif current_task == 3:
			# После 3 задания выводим сообщение об успехе
			if label_result:
				label_result.text = "Обучение успешно пройдено!"
			if label_info_2:
				label_info_2.visible = false
			if label_info_3:
				label_info_3.visible = true
			task_completed = false

# Обработчик выхода руки из зоны кнопки
func _on_button_area_exited(area: Area3D):
	if _is_hand(area):
		#print("Рука вышла из кнопки")
		is_button_hovered = false

# Обработчик входа флага в зону проверки и корректности молекулы
func _on_zone_area_entered(area: Area3D):
	if area.name.to_lower().contains("flag"):
		#print("Flag вошел в зону: ", area.name)
		var flag_root = area.get_parent()
		current_flag_root = flag_root  # Сохраняем ссылку на флаг в зоне
		
		# Определяем ожидаемую структуру в зависимости от текущего задания
		var expected_structure = {}
		
		if current_task == 1:
			# H2O
			expected_structure = {
				"atoms": ["H", "H", "O"],
				"bonds": [["H", "O"], ["H", "O"]]
			}
		elif current_task == 2:
			# Zn(OH)2
			expected_structure = {
				"atoms": ["Zn", "O", "H", "O", "H"],
				"bonds": [["Zn", "O"], ["O", "H"], ["Zn", "O"], ["O", "H"]]
			}
		elif current_task == 3:
			# H3BO3
			expected_structure = {
				"atoms": ["B", "O", "H", "O", "H", "O", "H"],
				"bonds": [["B", "O"], ["O", "H"], ["B", "O"], ["O", "H"], ["B", "O"], ["O", "H"]]
			}
		
		if main_node and main_node.has_method("check_molecule_structure"):
			var is_correct = main_node.check_molecule_structure(flag_root, expected_structure)
			#print("Результат проверки задания ", current_task, ": ", is_correct)
			if is_correct:
				if label_result:
					label_result.text = "Задание выполнено!"
				task_completed = true
			else:
				if label_result:
					label_result.text = "Задание выполнено неверно!"
				task_completed = false
		else:
			print("main_node не найден или метод check_molecule_structure отсутствует")
			if label_result:
				label_result.text = "Ошибка проверки"

# Выводим все дочерние узлы (отладка)
func _print_children(node: Node, indent_level: int):
	var indent = ""
	for i in range(indent_level):
		indent += "  "
	print(indent + "- " + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_children(child, indent_level + 1)

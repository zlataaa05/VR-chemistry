extends Node3D

# Ссылки
@onready var table = $Tabl_Mendeleeva2
@export var atom_scene: PackedScene = preload("res://Scene/ATOM.tscn")
@export var link: PackedScene = preload("res://Scene/LINK.tscn")
# Ссылка на указку и контроллер
@onready var raycast = $Pointer/RayCast3D
@onready var pointer = $Pointer

@export var link_length: float = 0.5  # Длина связи

var atoms: Array = []  # Список всех атомов
var links: Dictionary = {}  # Словарь существующих связей (ключ: "id1_id2")

var is_aiming_at_table_cell: bool = false	# флаг - наведена ли указка на таблицу
var current_hit_cell: Area3D = null  # текущая ячейка, на которую наведена указка
var current_hit_point: Vector3 = Vector3.ZERO	# текущая точка попадания указки, по умолчанию ноль

# Данные об атомах из JSON
var atoms_data: Dictionary = {}  # id -> данные атома

func _ready():
	# Загружаем данные об атомах
	_load_atoms_data()
	
	print("Доступные ID в JSON: ", atoms_data.keys())
	
	if not table:
		print("Таблица не найдена")
		return
	
	# Подключаем сигналы от указки (XRToolsPickable)
	if pointer:
		# Сигнал когда указку взяли в руку
		if pointer.has_signal("picked_up"):
			pointer.picked_up.connect(_on_pointer_picked_up)
		
		# Сигнал когда указку отпустили
		if pointer.has_signal("dropped"):
			pointer.dropped.connect(_on_pointer_dropped)
		
		# Сигнал нажатия action кнопки
		if pointer.has_signal("action_pressed"):
			pointer.action_pressed.connect(_on_pointer_action_pressed)
	
	print("Система готова")
	
func _load_atoms_data():
	# Открываем JSON файл
	var file = FileAccess.open("res://data/atoms.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(content)
		if parse_result == OK:
			var data = json.data
			if data is Array:
				for atom in data:
					atoms_data[atom["id"]] = atom
				print("Загружено ", atoms_data.size(), " атомов")
			else:
				print("Ошибка: данные не являются массивом")
		else:
			print("Ошибка парсинга JSON: ", json.get_error_message())
		file.close()
	else:
		print("Не удалось открыть файл atoms.json")
	
func _process(delta):
	# Вызываем проверку луча каждый кадр
	_handle_raycast()
	# Проверяем все пары атомов каждый кадр
	_update_all_links()
	# Обновляем транформ всех связей
	_update_existing_links_transforms()
	
func _handle_raycast():
	if not raycast:
		return
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Проверяем, попали ли указкой в Area3D ячеек таблицы
		if collider is Area3D and collider.is_in_group("atomic_area_group"):
			is_aiming_at_table_cell = true
			current_hit_cell = collider
			current_hit_point = raycast.get_collision_point()
			print("Указка наведена на ячейку: ", collider.name)
			return
	
	is_aiming_at_table_cell = false
	current_hit_cell = null
	
func _on_pointer_picked_up(_pickable):
	print("Указка взята в руку")
	# Включаем луч, если он был выключен
	if raycast:
		raycast.enabled = true

func _on_pointer_dropped(_pickable):
	print("Указка отпущена")
	is_aiming_at_table_cell = false
	current_hit_cell = null
	# Выключаем луч
	if raycast:
		raycast.enabled = false

func _on_pointer_action_pressed(_pickable):
	# Вызывается, когда игрок нажимает action кнопку (trigger) пока указка в руке
	print("Нажат триггер")
	if is_aiming_at_table_cell and current_hit_cell:
		_spawn_atom_from_cell(current_hit_cell)	
		
func _is_player_hand(area: Area3D) -> bool:
	var node_name = area.name.to_lower()
	
	if node_name.contains("hand"):
		return true
		
	var parent = area.get_parent()
	if parent and (parent.name.to_lower().contains("hand")):
		return true
		
	return false
	
func _spawn_atom_from_cell(cell_area: Area3D) -> void:
# Извлекаем ID элемента из названия Area3D
	# Ожидаемый формат: "area_1", "area_2", "area_3" и т.д.
	var cell_name = cell_area.name
	var atom_id = _extract_id_from_area_name(cell_name)
	
	if atom_id == 0:
		print("Не удалось определить ID атома из названия: ", cell_name)
		return
	
	# Получаем данные атома из JSON
	var atom_data = atoms_data.get(float(atom_id))
	if not atom_data:
		print("Данные для атома с ID ", atom_id, " не найдены в JSON")
		return
	
	# Создаем атом
	var atom_instance = atom_scene.instantiate()
	
	# Устанавливаем позицию спавна
	var spawn_pos = table.global_position + Vector3(0, -0.5, 0.7)
	atom_instance.global_position = spawn_pos
	
	# Применяем цвет атома из JSON
	_apply_atom_color(atom_instance, atom_data["color"])
	
	if atom_instance.has_method("set_atom_data"):
		atom_instance.set_atom_data(atom_data)
	
	add_child(atom_instance)
	atoms.append(atom_instance)
	
	print("Создан атом: ", atom_data["name"], " (", atom_data["symbol"], ")")
	print("Всего атомов: ", atoms.size())
	
func _extract_id_from_area_name(area_name: String) -> int:
	# Извлекаем число из названия "area_1", "area_2" и т.д.
	var parts = area_name.split("_")
	if parts.size() >= 2:
		var id_str = parts[1]
		# Если есть дополнительные подчеркивания, берем только цифры
		var id_int = id_str.to_int()
		if id_int > 0:
			return id_int
	return 0
	
func _apply_atom_color(atom_instance: Node3D, color_hex: String):
	# Ищем MeshInstance3D в сцене атома
	var mesh_instance = _find_mesh_instance(atom_instance)
	if mesh_instance and mesh_instance is MeshInstance3D:
		# Создаем новый материал или изменяем существующий
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(color_hex)
		
		# Настройки глянца (металлический блеск)
		material.metallic = 0.4
		material.metallic_specular = 0.6
		material.roughness = 0.15
		material.reflectivity = 0.5 
		
		mesh_instance.material_override = material
		print("Применен цвет: ", color_hex)
		
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	# Рекурсивно ищем первый MeshInstance3D
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null
	
func _update_all_links():
	# Проверяем все пары атомов
	for i in range(atoms.size()):
		for j in range(i + 1, atoms.size()):
			var atom1 = atoms[i]
			var atom2 = atoms[j]
			
			if not is_instance_valid(atom1) or not is_instance_valid(atom2):
				continue
			
			var distance = atom1.global_position.distance_to(atom2.global_position)
			var link_key = str(atom1.get_instance_id()) + "_" + str(atom2.get_instance_id())
			
			if distance < link_length:
				# Если связи нет - создаем
				if not links.has(link_key):
					_create_link(atom1, atom2, link_key)
			else:
				# Если связь есть и расстояние больше - удаляем
				if links.has(link_key):
					_remove_link(link_key)
					
func _update_existing_links_transforms():
	for link_key in links.keys():
		var link_data = links[link_key]
		
		# Проверяем, что все объекты еще существуют
		if not is_instance_valid(link_data["instance"]) or \
		   not is_instance_valid(link_data["atom1"]) or \
		   not is_instance_valid(link_data["atom2"]):
			# Если что-то уничтожено - удаляем связь
			_remove_link(link_key)
			continue
		
		# Обновляем трансформ связи
		_update_link_transform(link_data["instance"], link_data["atom1"], link_data["atom2"])

func _create_link(atom1: Node3D, atom2: Node3D, link_key: String):
	if not link:
		print("Сцена связи не найдена!")
		return
	
	var link_instance = link.instantiate()
	add_child(link_instance)
	
	# Обновляем позицию и поворот связи
	_update_link_transform(link_instance, atom1, atom2)
	
	# Сохраняем связь
	links[link_key] = {
		"instance": link_instance,
		"atom1": atom1,
		"atom2": atom2
	}
	
	print("Создана связь между атомами")

func _update_link_transform(link_instance: Node3D, atom1: Node3D, atom2: Node3D):
	# Вычисляем позицию между атомами
	var mid_point = (atom1.global_position + atom2.global_position) / 2
	link_instance.global_position = mid_point
	
	# Вычисляем направление и поворот
	var direction = atom2.global_position - atom1.global_position
	var distance = direction.length()
	
	# Защита от нулевого вектора
	if distance < 0.001:
		return
	
	# Масштабируем цилиндр по нужной длине
	var cylinder_node = null
	if link_instance is CSGCylinder3D:
		cylinder_node = link_instance
	else:
		# Если это не CSGCylinder3D, пытаемся найти дочерний CSGCylinder3D
		cylinder_node = link_instance.find_child("CSGCylinder3D", true, false)
	
	if cylinder_node:
		cylinder_node.height = distance
	var target_direction = direction.normalized()
	
	# Вычисляем угол между осью Y и нужным направлением
	var rotation_quat = Quaternion(Vector3.UP, target_direction)
	link_instance.quaternion = rotation_quat

func _remove_link(link_key: String):
	if links.has(link_key):
		var link_data = links[link_key]
		if is_instance_valid(link_data["instance"]):
			link_data["instance"].queue_free()
		links.erase(link_key)
		print("Связь удалена")

func _remove_all_links():
	for link_key in links.keys():
		var link_data = links[link_key]
		if is_instance_valid(link_data["instance"]):
			link_data["instance"].queue_free()
	links.clear()

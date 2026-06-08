extends Node3D

# Ссылки
@onready var table = $Tabl_Mendeleeva2
@export var atom_scene: PackedScene = load("res://Scene/ATOM.tscn")
@export var link: PackedScene = load("res://Scene/LINK.tscn")
# Ссылка на указку и контроллера
@onready var raycast = $Pointer/RayCast3D
@onready var pointer = $Pointer
# Ссылка на камеру игрока
@onready var camera = $Player/XROrigin3D/Camera1
# Ссылка на Flag в сцене
@onready var flag = $Flag
# Ссылка на Flag (чтобы перемещать молекулу)
@export var flag_scene: PackedScene = load("res://Scene/FLAG.tscn")

@export var link_length: float = 0.5  # Длина связи
@export var attach_distance: float = 0.3  # Дистанция для прикрепления флага к молекуле

var atoms: Array = []  # Список всех атомов
var links: Dictionary = {}  # Словарь существующих связей (ключ: "id1_id2")

var atom_bond_count: Dictionary = {}  # instance_id -> текущее количество связей
var atom_valence: Dictionary = {}  # instance_id -> максимальная валентность

var is_aiming_at_table_cell: bool = false	# флаг - наведена ли указка на таблицу
var current_hit_cell: Area3D = null  # текущая ячейка, на которую наведена указка
var current_hit_point: Vector3 = Vector3.ZERO	# текущая точка попадания указки, по умолчанию ноль

# Данные об атомах из JSON
var atoms_data: Dictionary = {}  # id -> данные атома

# Данные для управления молекулами
var original_flag_position: Vector3 = Vector3.ZERO  # исходная позиция флага
var original_flag_rotation: Vector3 = Vector3.ZERO  # исходная ротация флага
var active_molecules: Array = []  # Список активных молекул (каждая молекула - словарь с данными)

# Словарь для хранения Label3D каждого атома
var atom_labels: Dictionary = {}  # instance_id -> Label3D

# Список всех флагов в сцене
var all_flags: Array = []

# Флаг для предотвращения множественного спавна
var is_spawning_enabled: bool = true

func _ready():
	# Загружаем данные об атомах
	_load_atoms_data()
	
	print("Доступные ID в JSON: ", atoms_data.keys())
	
	if not table:
		print("Таблица не найдена")
		return
		
	if not atom_scene:
		print("Сцена атома не найдена")
		return
		
	# Сохраняем исходную позицию и ротацию флага 
	if flag:
		original_flag_position = flag.global_position
		original_flag_rotation = flag.rotation
		print("Исходная позиция флага: ", original_flag_position)
		print("Исходная ротация флага: ", original_flag_rotation)
		# Инициализируем начальный флаг
		_initialize_flag(flag)
	
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

func _initialize_flag(flag_instance: Node3D):
	"""Инициализирует новый флаг, подключает сигналы и добавляет в список"""
	# Сохраняем оригинальные позицию и ротацию в метаданные
	if not flag_instance.has_meta("original_position"):
		flag_instance.set_meta("original_position", flag_instance.global_position)
		flag_instance.set_meta("original_rotation", flag_instance.rotation)
		flag_instance.set_meta("replacement_created", false)
		flag_instance.set_meta("spawned", false)  # Отмечаем, что флаг только что создан
	
	# Подключаем сигналы
	_connect_flag_signals(flag_instance)
	
	# Добавляем в список всех флагов, если еще не добавлен
	if flag_instance not in all_flags:
		all_flags.append(flag_instance)
		print("Флаг инициализирован: ", flag_instance.name, " на позиции ", flag_instance.global_position)

func _connect_flag_signals(flag_instance: Node3D):
	# Проверяем, не подключены ли уже сигналы
	if flag_instance.has_signal("dropped"):
		if not flag_instance.dropped.is_connected(_on_flag_dropped):
			flag_instance.dropped.connect(_on_flag_dropped)
	
	# Сигнал для отслеживания момента взятия флага
	if flag_instance.has_signal("picked_up"):
		if not flag_instance.picked_up.is_connected(_on_flag_picked_up):
			flag_instance.picked_up.connect(_on_flag_picked_up)

func _on_flag_picked_up(pickable):
	print("Флаг взят в руку: ", pickable.name)
	# Когда флаг берут в руку, сбрасываем флаг spawned, так как теперь он перемещается
	if pickable.has_meta("spawned"):
		pickable.set_meta("spawned", false)

func _on_flag_dropped(pickable):
	# Флаг отпущен - проверяем, нужно ли прикрепить молекулу
	# Используем флаг, который отпустили
	if not _is_flag_attached_to_molecule(pickable):
		_check_and_attach_molecule_for_flag(pickable)

func _is_flag_attached_to_molecule(flag_instance: Node3D) -> bool:
	# Проверяем, прикреплена ли уже какая-то молекула к этому флагу
	for molecule in active_molecules:
		if molecule["flag"] == flag_instance:
			return true
	return false

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
	
@warning_ignore("unused_parameter")
func _process(delta):
	# Вызываем проверку луча каждый кадр
	_handle_raycast()
	# Проверяем все пары атомов каждый кадр
	_update_all_links()
	# Обновляем транформ всех связей
	_update_existing_links_transforms()
	# Проверяем все флаги на перемещение
	_check_all_flags_movement()
	# Обновляем повороты всех Label3D, чтобы они смотрели на игрока
	_update_all_labels_rotation()
	
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
			return
	
	is_aiming_at_table_cell = false
	current_hit_cell = null

func _check_all_flags_movement():
	# Проверяем все флаги в сцене
	# Используем копию списка, чтобы избежать проблем при изменении во время итерации
	var flags_to_check = all_flags.duplicate()
	
	for flag_instance in flags_to_check:
		if not is_instance_valid(flag_instance):
			# Удаляем невалидный флаг из списка
			all_flags.erase(flag_instance)
			continue
		
		# Проверяем, не прикреплена ли уже молекула к этому флагу
		if _is_flag_attached_to_molecule(flag_instance):
			continue
		
		# Проверяем, был ли флаг перемещен с исходной позиции
		# Для этого храним позицию для каждого флага
		if not flag_instance.has_meta("original_position"):
			flag_instance.set_meta("original_position", flag_instance.global_position)
			flag_instance.set_meta("original_rotation", flag_instance.rotation)
			flag_instance.set_meta("replacement_created", false)
			flag_instance.set_meta("spawned", false)
			continue
		
		# Пропускаем только что созданные флаги, чтобы они не создавали новые флаги сразу
		if flag_instance.has_meta("spawned") and flag_instance.get_meta("spawned") == true:
			# Если флаг был только что создан, даем ему время
			continue
		
		var original_pos = flag_instance.get_meta("original_position")
		var current_pos = flag_instance.global_position
		var distance_moved = current_pos.distance_to(original_pos)
		
		# Если флаг переместился больше чем на допустимую погрешность и еще не создали новый флаг
		if distance_moved > 0.5 and not flag_instance.get_meta("replacement_created"):
			flag_instance.set_meta("replacement_created", true)
			_create_new_flag_at_original_position()
			print("Флаг ", flag_instance.name, " был перемещен. Создан новый флаг на исходной позиции")

func _create_new_flag_at_original_position():
	# Создаем новый экземпляр флага
	if not flag_scene:
		print("Сцена флага не загружена")
		return
	
	if original_flag_position == Vector3.ZERO:
		print("Исходная позиция флага не задана")
		return
	
	# Временно отключаем спавн, чтобы избежать каскадного создания
	if not is_spawning_enabled:
		return
	
	is_spawning_enabled = false
	
	var new_flag = flag_scene.instantiate()
	
	# Устанавливаем уникальное имя для флага
	new_flag.name = "Flag_" + str(randi())
	
	# Устанавливаем позицию на исходную
	new_flag.global_position = original_flag_position
	
	# Устанавливаем ротацию на исходную
	new_flag.rotation = original_flag_rotation
	
	# Отмечаем, что этот флаг был только что создан
	new_flag.set_meta("spawned", true)
	new_flag.set_meta("replacement_created", false)
	
	# Добавляем в сцену
	add_child(new_flag)
	
	# Инициализируем флаг
	_initialize_flag(new_flag)
	
	print("Создан новый флаг '", new_flag.name, "' на исходной позиции: ", original_flag_position)
	print("Всего флагов в сцене: ", all_flags.size())
	
	# Включаем спавн с небольшой задержкой
	await get_tree().create_timer(0.5).timeout
	is_spawning_enabled = true

func _check_and_attach_molecule_for_flag(flag_instance: Node3D):
	# Проверяем, есть ли атомы в сцене
	if atoms.size() == 0:
		print("Нет атомов для прикрепления")
		return
	
	if not flag_instance or not is_instance_valid(flag_instance):
		print("Флаг не существует")
		return
	
	# Проверяем, не прикреплена ли уже молекула к этому флагу
	if _is_flag_attached_to_molecule(flag_instance):
		print("К этому флагу уже прикреплена молекула")
		return
	
	# Находим ближайший атом к флагу, который не принадлежит другой молекуле
	var closest_atom: Node3D = null
	var min_distance = attach_distance
	
	for atom in atoms:
		if not is_instance_valid(atom):
			continue
		
		# Проверяем, не принадлежит ли атом уже другой молекуле
		if _is_atom_part_of_molecule(atom):
			continue
			
		var distance = flag_instance.global_position.distance_to(atom.global_position)
		print("Расстояние до атома ", atom.name, ": ", distance)
		if distance < min_distance:
			min_distance = distance
			closest_atom = atom
	
	# Если атом найден на достаточном расстоянии
	if closest_atom:
		print("Найден ближайший атом на расстоянии: ", min_distance)
		# Собираем все узлы, входящие в молекулу (атомы и связи)
		var molecule_nodes = _get_molecule_nodes(closest_atom)
		
		if molecule_nodes.size() > 0:
			_attach_molecule_to_flag(flag_instance, molecule_nodes)
		else:
			print("Не найдено узлов молекулы")
	else:
		print("Нет доступных атомов для прикрепления. Ближайшее расстояние: ", min_distance)

func _is_atom_part_of_molecule(atom: Node3D) -> bool:
	# Проверяем, принадлежит ли атом уже какой-либо молекуле
	for molecule in active_molecules:
		if atom in molecule["atoms"]:
			return true
	return false

func _get_molecule_nodes(start_atom: Node3D) -> Array:
	var molecule_nodes = []
	var visited = {}
	var stack = [start_atom]
	
	while stack.size() > 0:
		var atom = stack.pop_back()
		var atom_id = atom.get_instance_id()
		
		if visited.has(atom_id):
			continue
		visited[atom_id] = true
		
		# Добавляем атом в список
		if atom not in molecule_nodes:
			molecule_nodes.append(atom)
		
		# Находим все связи с текущим атомом
		for link_key in links.keys():
			var link_data = links[link_key]
			if not is_instance_valid(link_data["atom1"]) or not is_instance_valid(link_data["atom2"]):
				continue
				
			var other_atom = null
			if link_data["atom1"] == atom:
				other_atom = link_data["atom2"]
			elif link_data["atom2"] == atom:
				other_atom = link_data["atom1"]
			
			if other_atom:
				# Добавляем связь в список
				if link_data["instance"] not in molecule_nodes:
					molecule_nodes.append(link_data["instance"])
				# Добавляем связанный атом в стек для обработки
				if not visited.has(other_atom.get_instance_id()):
					stack.append(other_atom)
	
	print("Найдено узлов в молекуле: ", molecule_nodes.size())
	print("Из них атомов: ", visited.size())
	print("Из них связей: ", molecule_nodes.size() - visited.size())
	
	return molecule_nodes

func _attach_molecule_to_flag(flag_instance: Node3D, molecule_nodes: Array):
	if _is_flag_attached_to_molecule(flag_instance):
		print("К этому флагу уже прикреплена молекула")
		return
	
	print("Прикрепление молекулы к флагу...")
	print("Всего узлов для переподчинения: ", molecule_nodes.size())
	
	# Сохраняем информацию об атомах и их трансформациях
	var atoms_transforms = []
	var all_links = []
	
	# Сначала собираем все связи и атомы отдельно
	for node in molecule_nodes:
		if not is_instance_valid(node):
			continue
		
		if node in atoms:
			# Сохраняем трансформацию атома
			atoms_transforms.append({
				"node": node,
				"original_global_transform": node.global_transform,
				"old_parent": node.get_parent()
			})
		else:
			# Добавляем связь в список для удаления
			all_links.append(node)
	
	# Удаляем все связи (они будут пересозданы заново)
	for link_node in all_links:
		if is_instance_valid(link_node):
			# Удаляем из словаря links
			var link_key_to_remove = null
			for key in links.keys():
				if links[key]["instance"] == link_node:
					link_key_to_remove = key
					break
			if link_key_to_remove:
				_remove_link(link_key_to_remove)
			else:
				link_node.queue_free()
	
	# Переподчиняем атомы флагу
	for atom_data in atoms_transforms:
		var atom = atom_data["node"]
		var original_transform = atom_data["original_global_transform"]
		var old_parent = atom_data["old_parent"]
		
		# Переподчиняем атому
		old_parent.remove_child(atom)
		flag_instance.add_child(atom)
		
		# Восстанавливаем глобальную трансформацию
		atom.global_transform = original_transform
	
	# Принудительно обновляем все связи в следующем кадре
	await get_tree().process_frame
	
	# Обновляем словари атомов
	# Очищаем текущий список атомов и пересобираем его
	atoms.clear()
	_find_all_atoms_in_scene()
	
	# Сбрасываем счетчики связей для всех атомов
	atom_bond_count.clear()
	for atom in atoms:
		var instance_id = atom.get_instance_id()
		atom_bond_count[instance_id] = 0
	
	# Принудительно обновляем связи, чтобы они пересоздались
	_update_all_links()
	
	# Сохраняем информацию о молекуле
	var molecule_data = {
		"flag": flag_instance,
		"nodes": molecule_nodes,
		"atoms": atoms_transforms  # Сохраняем атомы
	}
	
	active_molecules.append(molecule_data)
	
	print("Молекула успешно прикреплена к флагу")

func _find_all_atoms_in_scene():
	atoms.clear()
	_find_atoms_recursive(self)

func _find_atoms_recursive(node: Node):
	for child in node.get_children():
		if child.name == "ATOM" or child.get_instance_id() in atom_valence:
			atoms.append(child)
		_find_atoms_recursive(child)

# Функция для удаления молекулы 
func _detach_molecule(molecule_data: Dictionary):
	if not molecule_data["flag"] or not is_instance_valid(molecule_data["flag"]):
		return
	
	var flag_instance = molecule_data["flag"]
	
	# Возвращаем узлы обратно в сцену
	for node in molecule_data["nodes"]:
		if is_instance_valid(node):
			var old_parent = node.get_parent()
			if old_parent == flag_instance:
				flag_instance.remove_child(node)
				add_child(node)
				# Сохраняем глобальную трансформацию
				node.global_transform = node.global_transform
	
	# Удаляем из списка активных молекул
	active_molecules.erase(molecule_data)

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
	# Вызывается, когда игрок нажимает триггер пока указка в руке
	print("Нажат триггер")
	if is_aiming_at_table_cell and current_hit_cell:
		_spawn_atom_from_cell(current_hit_cell)	
		
func _spawn_atom_from_cell(cell_area: Area3D) -> void:
	# Извлекаем ID элемента из названия Area3D
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
	var spawn_pos = table.global_position + Vector3(0, -0.7, 1.1)
	atom_instance.global_position = spawn_pos
	
	# Применяем цвет атома из JSON
	_apply_atom_color(atom_instance, atom_data["color"])
	
	# Устанавливаем символ атома на Label3D
	var label = _set_atom_label(atom_instance, atom_data["symbol"])
	
	if atom_instance.has_method("set_atom_data"):
		atom_instance.set_atom_data(atom_data)
	
	# Сохраняем валентность атома
	var instance_id = atom_instance.get_instance_id()
	atom_valence[instance_id] = atom_data["valence"]
	atom_bond_count[instance_id] = 0
	
	# Сохраняем ссылку на Label3D
	if label != null:
		atom_labels[instance_id] = label
	
	add_child(atom_instance)
	atoms.append(atom_instance)
	
	print("Создан атом: ", atom_data["name"], " (", atom_data["symbol"], ")")
	print("Валентность: ", atom_data["valence"])
	print("Всего атомов: ", atoms.size())
	
func _extract_id_from_area_name(area_name: String) -> int:
	var parts = area_name.split("_")
	if parts.size() >= 2:
		var id_str = parts[1]
		var id_int = id_str.to_int()
		if id_int > 0:
			return id_int
	return 0
	
func _apply_atom_color(atom_instance: Node3D, color_hex: String):
	var mesh_instance = _find_mesh_instance(atom_instance)
	if mesh_instance and mesh_instance is MeshInstance3D:
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(color_hex)
		
		material.metallic = 0.4
		material.metallic_specular = 0.6
		material.roughness = 0.15
		
		mesh_instance.material_override = material
		print("Применен цвет: ", color_hex)
		
func _set_atom_label(atom_instance: Node3D, symbol: String) -> Label3D:
	var label_3d = _find_label_3d(atom_instance)
	
	if label_3d and label_3d is Label3D:
		label_3d.text = symbol
		label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		print("Установлен символ на Label3D: ", symbol)
		return label_3d
	else:
		print("Label3D не найден в сцене атома")
		return null
		
func _find_label_3d(node: Node) -> Label3D:
	if node is Label3D:
		return node
	
	for child in node.get_children():
		var result = _find_label_3d(child)
		if result:
			return result
	
	return null
		
func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var result = _find_mesh_instance(child)
		if result:
			return result
	return null

func _can_create_bond(atom1: Node3D, atom2: Node3D) -> bool:
	var atom1_id = atom1.get_instance_id()
	var atom2_id = atom2.get_instance_id()
	
	var atom1_bonds = atom_bond_count.get(atom1_id, 0)
	var atom2_bonds = atom_bond_count.get(atom2_id, 0)
	var atom1_max = atom_valence.get(atom1_id, 0)
	var atom2_max = atom_valence.get(atom2_id, 0)
	
	if atom1_bonds >= atom1_max:
		print("Атом ", atom1.name, " уже достиг максимальной валентности (", atom1_max, ")")
		return false
	
	if atom2_bonds >= atom2_max:
		print("Атом ", atom2.name, " уже достиг максимальной валентности (", atom2_max, ")")
		return false
	
	return true

func _add_bond_count(atom1: Node3D, atom2: Node3D):
	var atom1_id = atom1.get_instance_id()
	var atom2_id = atom2.get_instance_id()
	
	atom_bond_count[atom1_id] = atom_bond_count.get(atom1_id, 0) + 1
	atom_bond_count[atom2_id] = atom_bond_count.get(atom2_id, 0) + 1
	
	print("Связи атома1: ", atom_bond_count[atom1_id], "/", atom_valence[atom1_id])
	print("Связи атома2: ", atom_bond_count[atom2_id], "/", atom_valence[atom2_id])

func _remove_bond_count(atom1: Node3D, atom2: Node3D):
	var atom1_id = atom1.get_instance_id()
	var atom2_id = atom2.get_instance_id()
	
	atom_bond_count[atom1_id] = max(0, atom_bond_count.get(atom1_id, 0) - 1)
	atom_bond_count[atom2_id] = max(0, atom_bond_count.get(atom2_id, 0) - 1)

func _update_all_links():
	for i in range(atoms.size()):
		for j in range(i + 1, atoms.size()):
			var atom1 = atoms[i]
			var atom2 = atoms[j]
			
			if not is_instance_valid(atom1) or not is_instance_valid(atom2):
				continue
			
			var distance = atom1.global_position.distance_to(atom2.global_position)
			var link_key = str(atom1.get_instance_id()) + "_" + str(atom2.get_instance_id())
			
			if distance < link_length:
				if not links.has(link_key):
					if _can_create_bond(atom1, atom2):
						_create_link(atom1, atom2, link_key)
			else:
				if links.has(link_key):
					_remove_link(link_key)
					
func _update_existing_links_transforms():
	for link_key in links.keys():
		var link_data = links[link_key]
		
		if not is_instance_valid(link_data["instance"]) or \
		   not is_instance_valid(link_data["atom1"]) or \
		   not is_instance_valid(link_data["atom2"]):
			_remove_link(link_key)
			continue
		
		_update_link_transform(link_data["instance"], link_data["atom1"], link_data["atom2"])

func _create_link(atom1: Node3D, atom2: Node3D, link_key: String):
	if not link:
		print("Сцена связи не найдена")
		return
	
	var link_instance = link.instantiate()
	add_child(link_instance)
	
	_update_link_transform(link_instance, atom1, atom2)
	
	links[link_key] = {
		"instance": link_instance,
		"atom1": atom1,
		"atom2": atom2
	}
	
	_add_bond_count(atom1, atom2)
	
	print("Создана связь между атомами")

func _update_link_transform(link_instance: Node3D, atom1: Node3D, atom2: Node3D):
	var mid_point = (atom1.global_position + atom2.global_position) / 2
	link_instance.global_position = mid_point
	
	var direction = atom2.global_position - atom1.global_position
	var distance = direction.length()
	
	if distance < 0.001:
		return
	
	var cylinder_node = null
	if link_instance is CSGCylinder3D:
		cylinder_node = link_instance
	else:
		cylinder_node = link_instance.find_child("CSGCylinder3D", true, false)
	
	if cylinder_node:
		cylinder_node.height = distance
	var target_direction = direction.normalized()
	
	var rotation_quat = Quaternion(Vector3.UP, target_direction)
	link_instance.quaternion = rotation_quat

func _remove_link(link_key: String):
	if links.has(link_key):
		var link_data = links[link_key]
		if is_instance_valid(link_data["atom1"]) and is_instance_valid(link_data["atom2"]):
			_remove_bond_count(link_data["atom1"], link_data["atom2"])
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
	atom_bond_count.clear()

func _remove_atom(atom: Node3D):
	if not is_instance_valid(atom):
		return
	
	var atom_id = atom.get_instance_id()
	
	var keys_to_remove = []
	for link_key in links.keys():
		var link_data = links[link_key]
		if link_data["atom1"] == atom or link_data["atom2"] == atom:
			keys_to_remove.append(link_key)
	
	for key in keys_to_remove:
		_remove_link(key)
	
	atoms.erase(atom)
	
	atom_bond_count.erase(atom_id)
	atom_valence.erase(atom_id)
	atom_labels.erase(atom_id)
	
	atom.queue_free()
	
	print("Атом удален")

func _update_all_labels_rotation():
	if not camera or not is_instance_valid(camera):
		return
	
	var camera_position = camera.global_position
	
	for atom in atoms:
		if not is_instance_valid(atom):
			continue
		
		var atom_id = atom.get_instance_id()
		if atom_labels.has(atom_id):
			var label = atom_labels[atom_id]
			if is_instance_valid(label):
				if label.billboard != BaseMaterial3D.BILLBOARD_ENABLED:
					var direction_to_camera = (camera_position - label.global_position).normalized()
					var target_rotation = Quaternion(Vector3.BACK, direction_to_camera)
					label.quaternion = target_rotation
					var euler = label.rotation
					euler.x = clamp(euler.x, -1.57, 1.57)
					label.rotation = euler

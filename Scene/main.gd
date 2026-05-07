extends Node3D

# Ссылки
@onready var table_area = $Tabl_Mendeleeva/mendeleeva/TablArea
@export var atom_scene: PackedScene = preload("res://Scene/ATOM.tscn")
@export var link: PackedScene = preload("res://Scene/LINK.tscn")
# Ссылка на указку и контроллер
@onready var raycast = $Pointer/RayCast3D
@onready var pointer = $Pointer

@export var link_length: float = 0.5  # Длина связи

var atoms: Array = []  # Список всех атомов
var links: Dictionary = {}  # Словарь существующих связей (ключ: "id1_id2")

var is_aiming_at_table: bool = false	# флаг - наведена ли указка на таблицу
var current_hit_point: Vector3 = Vector3.ZERO	# текущая точка попадания указки, по умолчанию ноль

func _ready():
	if not table_area:
		print("Area таблицы не найдена")
		return
		
	table_area.area_entered.connect(_on_table_area_area_entered)
	print("Сигнал таблицы подключен")
	
	# Подключаем сигналы от указки (XRToolsPickable)
	if pointer:
		# Сигнал когда указку взяли в руку
		if pointer.has_signal("picked_up"):
			pointer.picked_up.connect(_on_pointer_picked_up)
		
		# Сигнал когда указку отпустили
		if pointer.has_signal("dropped"):
			pointer.dropped.connect(_on_pointer_dropped)
		
		# Сигнал нажатия action кнопки (обычно это trigger или grip)
		if pointer.has_signal("action_pressed"):
			pointer.action_pressed.connect(_on_pointer_action_pressed)
	
	print("Система готова: возьмите указку и наведите на таблицу")
	
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
		
		# Проверяем, попали ли в Area3D таблицы
		if collider == table_area or collider.get_parent() == table_area:
			is_aiming_at_table = true
			current_hit_point = raycast.get_collision_point()
			print("Указка наведена на таблицу")
			return
	
	is_aiming_at_table = false
	
func _on_pointer_picked_up(_pickable):
	print("Указка взята в руку")
	# Включаем луч, если он был выключен
	if raycast:
		raycast.enabled = true

func _on_pointer_dropped(_pickable):
	print("Указка отпущена")
	is_aiming_at_table = false
	# Выключаем луч, чтобы не тратить ресурсы
	if raycast:
		raycast.enabled = false

func _on_pointer_action_pressed(_pickable):
	# Это вызывается, когда игрок нажимает action кнопку (обычно trigger)
	# пока указка в руке
	print("Нажат триггер")
	if is_aiming_at_table:
		_spawn_atom()	
	
func _on_table_area_area_entered(area: Area3D) -> void:
	# Проверка, что это рука
	if _is_player_hand(area):
		# Создаем 1 атом
		_spawn_atom()
		
func _is_player_hand(area: Area3D) -> bool:
	var node_name = area.name.to_lower()
	
	if node_name.contains("hand"):
		return true
		
	var parent = area.get_parent()
	if parent and (parent.name.to_lower().contains("hand")):
		return true
		
	return false
	
func _spawn_atom() -> void:
	if not atom_scene:
		print("Сцена атома не найдена!")
		return
		
	var atom_instance = atom_scene.instantiate()
	
	var spawn_pos = table_area.global_position + Vector3(0, 0.5, 0.5)
	atom_instance.global_position = spawn_pos
	
	add_child(atom_instance)
	atoms.append(atom_instance)
	
	print("Создан 1 атом. Всего атомов: ", atoms.size())
	
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

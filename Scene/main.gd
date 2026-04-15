extends Node3D

# Ссылка на сцену связи
@export var cylinder_scene: PackedScene

# Словарь для хранения активных связей (ключ: "atom1_id,atom2_id", значение: узел цилиндра)
var active_connections = {}

func _ready():
	cylinder_scene = load("res://Scene/LINK.tscn")
	# Проверяем, что сцена цилиндра назначена
	if cylinder_scene == null:
		print("cylinder_scene не назначена")
		return

func _process(_delta):
	# Получаем все атомы из группы Atoms
	var atoms = get_tree().get_nodes_in_group("Atoms")
	
	# Проверяем все возможные пары атомов
	for i in range(atoms.size()):
		for j in range(i + 1, atoms.size()):
			var atom1 = atoms[i]
			var atom2 = atoms[j]
			
			# Вычисляем расстояние между атомами
			var distance = atom1.global_position.distance_to(atom2.global_position)
			
			# Длина цилиндра (высота)
			var cylinder_length = 0.5
			
			# Создаем уникальный ключ для пары атомов
			var connection_key = str(atom1.get_instance_id()) + "_" + str(atom2.get_instance_id())
			
			# Если расстояние меньше или равно длине связи
			if distance <= cylinder_length:
				# Если связи еще нет, создаем её
				if not active_connections.has(connection_key):
					create_connection(atom1, atom2, connection_key)
					print(atom1.name, " ", atom2.name)
				else:
					# Обновляем существующую связь (если атомы двигаются)
					update_connection(active_connections[connection_key], atom1, atom2)

func create_connection(atom1: Node3D, atom2: Node3D, key: String):
	# Создаем экземпляр связи
	var cylinder = cylinder_scene.instantiate()
	add_child(cylinder)
	
	# Сохраняем связь в словаре
	active_connections[key] = cylinder
	
	# Позиционируем связь между атомами
	update_connection(cylinder, atom1, atom2)
	
	print("Создана связь между атомами")

func update_connection(cylinder: Node3D, atom1: Node3D, atom2: Node3D):
	# Вычисляем центральную точку между атомами
	var midpoint = (atom1.global_position + atom2.global_position) / 2.0
	cylinder.global_position = midpoint
	
	# Вычисляем расстояние для масштабирования связи
	var distance = atom1.global_position.distance_to(atom2.global_position)
	
	# Масштабируем связь по оси Y (длина)
	var scale_y = distance / 0.5
	cylinder.scale = Vector3(1.0, scale_y, 1.0)
	
	# Поворачиваем связь в направлении от atom1 к atom2
	var direction = (atom2.global_position - atom1.global_position).normalized()
	
	# Вычисляем угол поворота (связь по умолчанию ориентирована по оси Y)
	var up = Vector3.UP
	var rotation_quat = Quaternion(up, direction)
	
	# Применяем поворот
	cylinder.quaternion = rotation_quat

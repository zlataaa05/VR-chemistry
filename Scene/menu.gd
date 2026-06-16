extends Node3D

# Ссылки на кнопки
@onready var button_send: CSGBox3D = $Panel/ButtonSend
@onready var button_lern: CSGBox3D = $Panel/ButtonLern
@onready var button_exit: CSGBox3D = $Panel/ButtonExit

# Ссылки на Area3D кнопок
@onready var area_send: Area3D = $Panel/ButtonSend/AreaSend
@onready var area_lern: Area3D = $Panel/ButtonLern/AreaLern
@onready var area_exit: Area3D = $Panel/ButtonExit/AreaExit

# SceneManager ссылка
var scene_manager = null

# Таймеры для задержки перед переходом
var send_timer: float = 1.0
var lern_timer: float = 1.0
var exit_timer: float = 1.0
var hover_delay: float = 1.0  # Задержка в секундах перед переходом

# Флаги, находится ли рука в зоне кнопки
var is_send_hovered: bool = false
var is_lern_hovered: bool = false
var is_exit_hovered: bool = false

# Оригинальные цвета и свечение кнопок (для возврата)
var original_send_material: StandardMaterial3D
var original_lern_material: StandardMaterial3D
var original_exit_material: StandardMaterial3D

func _ready():
	# Находим SceneManager
	scene_manager = get_node_or_null("/root/SceneManager")
	if not scene_manager:
		print("SceneManager не найден")
	
	# Сохраняем оригинальные материалы кнопок
	_save_original_materials()
	
	# Настройка сигналов для кнопок
	_setup_button_signals()
	
	# Включаем обработку для Area3D
	_setup_area_signals()
	
	#print("Меню готово к взаимодействию")

func _save_original_materials():
	# Сохраняем оригинальные материалы для каждой кнопки
	if button_send and button_send.material:
		original_send_material = button_send.material.duplicate()
	
	if button_lern and button_lern.material:
		original_lern_material = button_lern.material.duplicate()
	
	if button_exit and button_exit.material:
		original_exit_material = button_exit.material.duplicate()

func _setup_button_signals():
	# Настройка сигналов для Area3D (для взаимодействия с руками)
	if area_send:
		area_send.body_entered.connect(_on_send_body_entered)
		area_send.body_exited.connect(_on_send_body_exited)
		area_send.area_entered.connect(_on_send_area_entered)
		area_send.area_exited.connect(_on_send_area_exited)
	
	if area_lern:
		area_lern.body_entered.connect(_on_lern_body_entered)
		area_lern.body_exited.connect(_on_lern_body_exited)
		area_lern.area_entered.connect(_on_lern_area_entered)
		area_lern.area_exited.connect(_on_lern_area_exited)
	
	if area_exit:
		area_exit.body_entered.connect(_on_exit_body_entered)
		area_exit.body_exited.connect(_on_exit_body_exited)
		area_exit.area_entered.connect(_on_exit_area_entered)
		area_exit.area_exited.connect(_on_exit_area_exited)

func _setup_area_signals():
	# Включаем мониторинг для всех Area3D
	for area in [area_send, area_lern, area_exit]:
		if area:
			area.monitoring = true
			area.monitorable = true

func _process(delta):
	# Обновляем таймеры для hover'а
	_update_hover_timers(delta)

func _update_hover_timers(delta):
	# Таймер для кнопки Send
	if is_send_hovered:
		send_timer += delta
		if send_timer >= hover_delay:
			_on_send_button_activated()
			send_timer = 0.0  # Сбрасываем таймер, чтобы не активировать повторно
	else:
		send_timer = 0.0
	
	# Таймер для кнопки Lern
	if is_lern_hovered:
		lern_timer += delta
		if lern_timer >= hover_delay:
			_on_lern_button_activated()
			lern_timer = 0.0
	else:
		lern_timer = 0.0
	
	# Таймер для кнопки Exit
	if is_exit_hovered:
		exit_timer += delta
		if exit_timer >= hover_delay:
			_on_exit_button_activated()
			exit_timer = 0.0
	else:
		exit_timer = 0.0

# Функция для изменения цвета и свечения кнопки
func _set_button_glow(button: CSGBox3D, color: Color, emission_color: Color):
	if button and button.material:
		# Создаем новый материал или используем существующий
		var material: StandardMaterial3D
		if button.material is StandardMaterial3D:
			material = button.material
		else:
			material = StandardMaterial3D.new()
			button.material = material
		
		# Устанавливаем цвет
		material.albedo_color = color
		
		# Устанавливаем свечение
		material.emission_enabled = true
		material.emission = emission_color
		material.emission_energy_multiplier = 1.0

# Функция для сброса цвета и свечения кнопки
func _reset_button_glow(button: CSGBox3D, original_material: StandardMaterial3D):
	if button and original_material:
		# Восстанавливаем оригинальный материал
		if button.material is StandardMaterial3D:
			button.material.albedo_color = original_material.albedo_color
			button.material.emission_enabled = original_material.emission_enabled
			button.material.emission = original_material.emission
			button.material.emission_energy_multiplier = original_material.emission_energy_multiplier
		else:
			button.material = original_material.duplicate()


# Функция для проверки, является ли объект рукой
func _is_hand(node: Node) -> bool:
	if node.name.to_lower().contains("hand"):
		return true
	
	if node.is_class("XRToolsHand") or node.get_script() == preload("res://addons/godot-xr-tools/hands/hand.gd"):
		return true
	
	# Проверяем родителя
	var parent = node.get_parent()
	if parent and (parent.name.to_lower().contains("hand") or parent.is_class("XRToolsHand")):
		return true
	
	return false

func _on_send_body_entered(body: Node):
	if _is_hand(body):
		#print("Рука вошла в зону кнопки Send")
		is_send_hovered = true

func _on_send_body_exited(body: Node):
	if _is_hand(body):
		#print("Рука вышла из зоны кнопки Send")
		is_send_hovered = false

func _on_send_area_entered(area: Area3D):
	if _is_hand(area):
		#print("Область руки вошла в зону кнопки Send")
		is_send_hovered = true
		_set_button_glow(button_send, Color(0, 0.686, 0), Color(0, 0.808, 0.259))  # 00af00 и 00ce42

func _on_send_area_exited(area: Area3D):
	if _is_hand(area):
		#print("Область руки вышла из зоны кнопки Send")
		is_send_hovered = false
		_reset_button_glow(button_send, original_send_material)

func _on_send_button_activated():
	#print("Кнопка Send активирована. Переход на MAIN.tscn...")
	_change_scene("MAIN")

func _on_lern_body_entered(body: Node):
	if _is_hand(body):
		#print("Рука вошла в зону кнопки Lern")
		is_lern_hovered = true

func _on_lern_body_exited(body: Node):
	if _is_hand(body):
		#print("Рука вышла из зоны кнопки Lern")
		is_lern_hovered = false

func _on_lern_area_entered(area: Area3D):
	if _is_hand(area):
		#print("Область руки вошла в зону кнопки Lern")
		is_lern_hovered = true
		_set_button_glow(button_lern, Color(0, 0.686, 0), Color(0, 0.808, 0.259))  # 00af00 и 00ce42

func _on_lern_area_exited(area: Area3D):
	if _is_hand(area):
		#print("Область руки вышла из зоны кнопки Lern")
		is_lern_hovered = false
		_reset_button_glow(button_lern, original_lern_material)

func _on_lern_button_activated():
	#print("Кнопка Lern активирована. Переход на MAIN_LEARN.tscn...")
	_change_scene("MAIN_LEARN")

func _on_exit_body_entered(body: Node):
	if _is_hand(body):
		#print("Рука вошла в зону кнопки Exit")
		is_exit_hovered = true

func _on_exit_body_exited(body: Node):
	if _is_hand(body):
		#print("Рука вышла из зоны кнопки Exit")
		is_exit_hovered = false

func _on_exit_area_entered(area: Area3D):
	if _is_hand(area):
		#print("Область руки вошла в зону кнопки Exit")
		is_exit_hovered = true
		_set_button_glow(button_exit, Color(0, 0.686, 0), Color(0, 0.808, 0.259))  # 00af00 и 00ce42

func _on_exit_area_exited(area: Area3D):
	if _is_hand(area):
		#print("Область руки вышла из зоны кнопки Exit")
		is_exit_hovered = false
		_reset_button_glow(button_exit, original_exit_material)

func _on_exit_button_activated():
	#print("Кнопка Exit активирована. Выход из приложения...")
	if scene_manager:
		get_tree().quit()
	else:
		get_tree().quit()

# Функция смены сцены с SceneManager
func _change_scene(scene_name: String):
	if scene_manager:
		# SceneManager для перехода
		if scene_manager.has_method("change_scene"):
			scene_manager.change_scene("res://Scene/" + scene_name + ".tscn")
		elif scene_manager.has_method("goto_scene"):
			scene_manager.goto_scene("res://Scene/" + scene_name + ".tscn")
		elif scene_manager.has_method("load_scene"):
			scene_manager.load_scene("res://Scene/" + scene_name + ".tscn")
		else:
			print("Методы SceneManager не найдены")
	else:
		print("Методы SceneManager не найдены")

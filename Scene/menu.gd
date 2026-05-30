extends Node3D

# Ссылки на кнопки
@onready var button_send: CSGBox3D = $ButtonSend
@onready var button_lern: CSGBox3D = $ButtonLern
@onready var button_exit: CSGBox3D = $ButtonExit

# Ссылки на Area3D кнопок
@onready var area_send: Area3D = $ButtonSend/AreaSend
@onready var area_lern: Area3D = $ButtonLern/AreaLern
@onready var area_exit: Area3D = $ButtonExit/AreaExit

# Ссылка на сцену игрока
@onready var player_menu: PackedScene = load("res://Scene/PLAYER_MENU.tscn")

# Материалы кнопок
var material_send: StandardMaterial3D
var material_lern: StandardMaterial3D
var material_exit: StandardMaterial3D

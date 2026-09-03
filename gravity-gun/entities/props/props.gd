class_name Props extends RigidBody3D

## Peso expresado en Kg. Es la fuente de verdad: sobrescribe a "mass" al arrancar.
@export_range(0.1, 500.0, 0.1) var weight: float = 1.0
@export var label_3d: Label3D

var _gravity_scale: float
var _linear_damp: float
var _angular_damp: float
var _can_sleep: bool
var _is_held: bool = false


func _ready() -> void:
	mass = weight

	if label_3d != null:
		label_3d.text = "%.1f kg" % mass


## True mientras alguien lo tenga agarrado.
func is_held() -> bool:
	return _is_held


## Apaga la gravedad y amortigua el movimiento para poder arrastrarlo.
func grab() -> void:
	if _is_held:
		return
	_is_held = true

	_gravity_scale = gravity_scale
	_linear_damp = linear_damp
	_angular_damp = angular_damp
	_can_sleep = can_sleep

	gravity_scale = 0.0
	linear_damp = 5.0
	angular_damp = 5.0
	can_sleep = false
	sleeping = false


## Devuelve el objeto a su física normal.
func release() -> void:
	if not _is_held:
		return
	_is_held = false

	gravity_scale = _gravity_scale
	linear_damp = _linear_damp
	angular_damp = _angular_damp
	can_sleep = _can_sleep

class_name GravityGun extends Node3D

## Largo del rayo (m)
@export var max_range: float = 8.0
## A que distancia enfrente flota el objeto una vez agarrado (m)
@export var hold_distance: float = 2.5
## Peso máximo que puede sostener el arma (Kg)
@export var max_mass: float = 80.0
## Velocidad que se le aplica al objeto al lanzarlo (m/s).
## No depende de la masa: todo lo que puedas cargar sale igual de rápido.
@export var launch_speed: float = 25.0
## Fuerza del empuje (N * s). Se reparte entre la masa: una caja de 10 Kg
## con 25 N*s sale a 2.5 m/s, una de 1 Kg saldría a 25 m/s.
@export var punt_impulse: float = 25.0
## Tope de velocidad que puede alcanzar un objeto empujado (m/s).
## Evita que lo muy ligero salga disparado más rápido que un lanzamiento.
@export var max_punt_speed: float = 15.0
## Que tan agresivo persigue el objeto al punto de anclaje (1/s)
@export var follow_strength: float = 12.0
## Si el objeto queda más lejos del anclaje, se suelta solo (m)
@export var break_distance: float = 3.0
## Tope de velocidad mientras persigue el anclaje (m/s)
@export var max_follow_speed: float = 30.0
## Tiempo tras lanzar en el que no se puede volver a agarrar (s)
@export var grab_cooldown: float = 0.25

@onready var marker_3d: Marker3D = %Marker3D
@onready var ray_cast_3d: RayCast3D = %RayCast3D

var current_target: Props = null
## Lo que traemos agarrado. Solo lo tocan _grab(), _release() y _launch().
var held_item: Props = null

var _cooldown: float = 0.0


func _ready() -> void:
	ray_cast_3d.target_position = Vector3(0, 0, -max_range)
	marker_3d.position = Vector3(0, 0, -hold_distance)


func _physics_process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta

	if held_item == null:
		_update_target()
	else:
		_move_held_item(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("grab"):
		if held_item != null:
			_release()
		elif current_target != null:
			_grab(current_target)

	elif event.is_action_pressed("punt"):
		if held_item != null:
			_launch()
		else:
			_punt()


## Dirección a la que apunta el arma en espacio global.
func _aim_direction() -> Vector3:
	return -ray_cast_3d.global_basis.z


## Busca un Props válido bajo la mira y lo deja en current_target.
func _update_target() -> void:
	current_target = null

	if _cooldown > 0.0 or not ray_cast_3d.is_colliding():
		return

	# Devuelve null si el collider es otra cosa (piso, pared, etc).
	var collider := ray_cast_3d.get_collider() as Props
	if collider != null and collider.mass <= max_mass:
		current_target = collider


## Agarra el prop: apaga su gravedad y lo marca como sostenido.
func _grab(item: Props) -> void:
	held_item = item
	held_item.grab()
	current_target = null


## Suelta el prop y le devuelve su física normal.
func _release() -> void:
	if held_item == null:
		return

	if is_instance_valid(held_item):
		held_item.release()
	held_item = null


## Dispara el objeto que traemos cargando.
func _launch() -> void:
	if not is_instance_valid(held_item):
		held_item = null
		return

	# Guardamos la referencia porque _release() la borra.
	var item := held_item
	var direction := _aim_direction()

	# Primero devolverle su física normal, y hasta entonces darle velocidad:
	# al revés, el damping del agarre se comería el lanzamiento.
	_release()
	item.linear_velocity = direction * launch_speed

	_cooldown = grab_cooldown


## Empujón con las manos vacías. Funciona sobre cualquier RigidBody3D, no solo Props.
func _punt() -> void:
	if not ray_cast_3d.is_colliding():
		return

	var body := ray_cast_3d.get_collider() as RigidBody3D
	if body == null:
		return

	# Un cuerpo dormido ignora los impulsos, y todo lo que lleva un rato
	# quieto sobre el piso está dormido. Hay que despertarlo primero.
	body.sleeping = false

	var direction := _aim_direction()
	# El offset del punto de impacto es lo que hace que además gire,
	# en vez de salir volando plano como una tabla.
	var offset := ray_cast_3d.get_collision_point() - body.global_position

	# El impulso se divide entre la masa, así que en un objeto muy ligero
	var impulse := minf(punt_impulse, max_punt_speed * body.mass)
	body.apply_impulse(direction * impulse, offset)


## Mueve el prop sostenido hacia el marcador con velocidad, nunca con posición.
func _move_held_item(delta: float) -> void:
	# El prop pudo haber sido destruido mientras lo cargábamos.
	if not is_instance_valid(held_item):
		held_item = null
		return

	var to_target := marker_3d.global_position - held_item.global_position

	# Se atoró detrás de una pared o se alejó demasiado: lo soltamos.
	if to_target.length() > break_distance:
		_release()
		return

	held_item.linear_velocity = (to_target * follow_strength).limit_length(max_follow_speed)
	held_item.angular_velocity = held_item.angular_velocity.lerp(
		Vector3.ZERO, clampf(delta * 10.0, 0.0, 1.0)
	)

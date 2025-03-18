extends Camera3D

var mouse_sensitivity = 0.002
var velocity = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	
	if Input.is_action_pressed("ui_up"): position += -transform.basis.z * velocity
	if Input.is_action_pressed("ui_down"): position += transform.basis.z * velocity
	if Input.is_action_pressed("ui_right"): position += transform.basis.x * velocity
	if Input.is_action_pressed("ui_left"): position += -transform.basis.x * velocity
	
	if Input.is_action_pressed("ui_focus_next"): position += -transform.basis.y * velocity
	if Input.is_action_pressed("ui_select"): position += transform.basis.y * velocity
	
	
	
	pass

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		rotate_x(-event.relative.y * mouse_sensitivity)

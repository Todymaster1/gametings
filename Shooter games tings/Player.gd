extends CharacterBody3D

# Player Nodes

@onready var neck = $Neck
@onready var head = $Neck/Head
@onready var eyes = $Neck/Head/Eyes
@onready var standing_collision_shape = $Standing_Collision_Shape
@onready var crouching_collision_shape = $Crouching_Collision_Shape
@onready var ray_cast_3d = $RayCast3D
@onready var camera_3d = $Neck/Head/Eyes/Camera3D
@onready var animation_player = $Neck/Head/Eyes/AnimationPlayer

#Speed vars
var Current_Speed = 5.0

const Walking_Speed = 5.0
const Sprinting_Speed = 8.0
const Crouching_Speed = 3.0

#States

var Walking = false
var Sprinting = false
var Crouching = false
var Free_looking = false
var Sliding = false

#Slide Vars

var slide_timer = 0.0
var slide_timer_max = 1.0
var slide_vector = Vector2.ZERO
var slide_speed = 10.0

#Head bobbing vars

const head_bobbing_sprinting_speed = 22.0
const head_bobbing_walking_speed = 14.0
const head_bobbing_crouching_speed = 10.0

const head_bobbing_crouching_intensity = 0.05
const head_bobbing_sprinting_intensity = 0.2
const head_bobbing_walking_intensity = 0.1

var head_bobbing_vector = Vector2.ZERO
var head_bobbing_index = 0.0
var head_bobbing_current_intensity = 0.0


#Movement Vars

var Crouching_depth = -0.5

const Jump_velocity = 4.5

var Lerp_Speed = 10.0

var air_lerp_speed = 3.0

var Free_look_tilt_amount = 8

var last_velocity = Vector3.ZERO

#Input Vars

var Directions = Vector3.ZERO

const Mouse_Sens = 0.4

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event):
	#Mouse looking logic
	
	if event is InputEventMouseMotion:
		if Free_looking:
			neck.rotate_y(deg_to_rad(-event.relative.x * Mouse_Sens))
			neck.rotation.y = clamp(neck.rotation.y, deg_to_rad(-120), deg_to_rad(120))
		else:
			rotate_y(deg_to_rad(-event.relative.x * Mouse_Sens))
		head.rotate_x(deg_to_rad(-event.relative.y * Mouse_Sens))
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _physics_process(delta):
	#Getting movement input
	var input_dir = Input.get_vector("Left", "Right", "Forward", "Backward")
	#Handle movement state
	
	#Couching
	
	if Input.is_action_pressed("Crouch") || Sliding:
		Current_Speed = lerp(Current_Speed, Crouching_Speed, delta * Lerp_Speed)
		head.position.y = lerp(head.position.y, 0.0 + Crouching_depth, delta*Lerp_Speed)
		
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
		
		#Slide begin logic
		
		if Sprinting && input_dir != Vector2.ZERO:
			Sliding = true
			slide_timer = slide_timer_max
			slide_vector = input_dir
			Free_looking = true
		
		Walking = false
		Sprinting = false
		Crouching = true
		
	elif !ray_cast_3d.is_colliding():
		
		#Standing
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
		
		head.position.y = lerp(head.position.y, 0.0, delta*Lerp_Speed)
		
		if Input.is_action_pressed("Sprint"):
			#Sprinting
			Current_Speed = lerp(Current_Speed, Sprinting_Speed, delta * Lerp_Speed)
			
			Walking = false
			Sprinting = true
			Crouching = false
		else:
			#Walking
			Current_Speed = lerp(Current_Speed, Walking_Speed, delta * Lerp_Speed)
			
			Walking = true
			Sprinting = false
			Crouching = false
			
	#Handle free looking
	if Input.is_action_pressed("Free_Look") || Sliding:
		Free_looking = true
		if Sliding:
			eyes.rotation.z = lerp(eyes.rotation.z, -deg_to_rad(7.0), delta * Lerp_Speed)
		else: 
			eyes.rotation.z = -deg_to_rad(neck.rotation.y * Free_look_tilt_amount)
	else:
		Free_looking = false
		neck.rotation.y =  lerp(neck.rotation.y, 0.0, delta*Lerp_Speed)
		eyes.rotation.z = lerp(eyes.rotation.y, 0.0, delta*Lerp_Speed)
		
	#Handle Sliding
	
	if Sliding:
		slide_timer -= delta
		if slide_timer <= 0:
			Sliding = false
			Free_looking = false

#Handle headbob

	if Sprinting:
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta 
	elif Walking:
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta 	
	elif Crouching:
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta 	
	
	if is_on_floor() && !Sliding && input_dir != Vector2.ZERO:
		head_bobbing_vector.y = sin(head_bobbing_index)
		head_bobbing_vector.x = sin(head_bobbing_index/2) * 0.5
		
		eyes.position.y = lerp(eyes.position.y, head_bobbing_vector.y * (head_bobbing_crouching_intensity/2.0), delta * Lerp_Speed)
		eyes.position.x = lerp(eyes.position.x, head_bobbing_vector.x * head_bobbing_crouching_intensity, delta * Lerp_Speed)
		
	else:
		eyes.position.y = lerp(eyes.position.y, 0.0, delta * Lerp_Speed)
		eyes.position.x = lerp(eyes.position.x, 0.0, delta * Lerp_Speed)
		
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle Jump.
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = Jump_velocity
		Sliding = false
		animation_player.play("Jump")
		
	#Handle Landing
	if is_on_floor():
		if last_velocity.y < 0.0:
			animation_player.play("Landing")


	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	if is_on_floor():
		Directions = lerp(Directions,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*Lerp_Speed)
	else:
		if input_dir != Vector2.ZERO:
			Directions = lerp(Directions,(transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*air_lerp_speed)
	
	
	if Sliding:
		Directions = (transform.basis * Vector3(slide_vector.x, 0, slide_vector.y)).normalized()
		Current_Speed = (slide_timer + 0.1) * slide_speed

	
	if Directions:
		velocity.x = Directions.x * Current_Speed
		velocity.z = Directions.z * Current_Speed
		
		
	else:
		velocity.x = move_toward(velocity.x, 0, Current_Speed)
		velocity.z = move_toward(velocity.z, 0, Current_Speed)

	last_velocity = velocity
	
	move_and_slide()
	
	

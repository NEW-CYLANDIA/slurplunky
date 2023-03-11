extends KinematicBody2D
class_name Player

enum State {
	Moving,
	Swinging,
	Licking,
	Eating,
	Stomping,
}

enum AimStyle {
	Locked,
	Free,
}

export var speed : float = 300.0
export var jump_vel : float = -400.0
export var accel : float = 0.1
export var tongue_length : float = 100
export var tongue_extend_speed : float = 0.5
export var spin_speed : float = 0.05
export var mood_add : float = 3
export var stomp_speed : float = 200
export var stomp_launch_speed : float = 400
export var grapple_cooldown : float = 0.75

export(AimStyle) var aim_style : int = AimStyle.Locked
export(NodePath) var taste_buds_path : NodePath
export(AudioStream) var jump_sfx
export(AudioStream) var tongue_sfx

# state stuff
var dir : int = 1
var state : int = State.Moving
var is_stomping : bool = false

# velocity stuff
var velocity : Vector2
var stored_velocity : Vector2

var grappled_object : Object

# TODO - move some of this stuff tongue script(s)?
var tongue_ray : RayCast2D
var tongue_sprite_connect_pos:Node2D
var tongue_length_normalizer : float
var tongue_grapple_point : Vector2
var tongue_grapple_point_sprite : Sprite
var tongue_sprite : Sprite

# TODO - move bubble stuff into its own class?
export var bubble_slowdown : float = 0.5
export var food_zip_speed : float = 400
export var bubble_launch_dropoff : float = 0.9
var current_bubble = null
var bubble_velocity : Vector2

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

onready var taste_buds = get_node(taste_buds_path)

	
func _init():
	tongue_sprite = load("res://src/Player/TongueBody.tscn").instance()
	tongue_grapple_point_sprite = load("res://src/Player/TongueTip.tscn").instance()


func _ready():
	get_tree().get_root().call_deferred("add_child", tongue_grapple_point_sprite)
	get_tree().get_root().call_deferred("add_child", tongue_sprite)

	tongue_ray = $TongueRay
	tongue_length_normalizer = 1.0 / tongue_sprite.texture.get_height()
	tongue_ray.cast_to = tongue_ray.cast_to.normalized() * tongue_length
	$FloorRay.cast_to = $FloorRay.cast_to.normalized() * tongue_length
	tongue_sprite_connect_pos = $Sprite/TonguePos
	tongue_sprite.visible = false

	$GrappleCooldown.wait_time = grapple_cooldown


func _physics_process(delta):
	bubble_velocity = velocity * bubble_slowdown

	# warning-ignore:return_value_discarded
	move_and_slide(
		bubble_velocity if current_bubble else velocity, Vector2.UP,false, 4, 0.78, false
	)
	
	var collision_data : KinematicCollision2D

	for i in range(get_slide_count()-1, -1, -1):
		collision_data = get_slide_collision(i)
		if collision_data:
			break
	
	if not is_on_floor() and state != State.Licking:
		velocity.y += gravity * delta
	
	if is_on_floor():
		velocity.y = 0

	

	if state == State.Moving:
		$Sprite.play("default")
		$Sprite.rotate(dir * spin_speed)

		if Input.is_action_just_pressed("action"):
			if is_on_floor():
				jump()
			elif $GrappleCooldown.is_stopped(): 
				if tongue_ray.is_colliding() or current_bubble:
					change_state(State.Licking)
				elif $FloorRay.is_colliding():
					print("Setting launch speed")
					stomp_launch_speed = (($FloorRay.get_collision_point().y - position.y) / delta) * 0.1
					is_stomping = true
					change_state(State.Licking)
			else:
				$Sprite/HitShake.do_shake(0.2, 1.5)					
		
		# Get the input direction and handle the movement/deceleration.
		velocity.x = move_toward(velocity.x, dir * speed, accel)

		if collision_data:
			var is_horizontal_collision = abs(collision_data.normal.x) == 1.0
			if is_horizontal_collision:
				velocity.x = (velocity.bounce(collision_data.normal) * 0.5).x
				velocity.y = jump_vel/2
				play_audio(jump_sfx)
				dir = int(sign(velocity.x))

		if is_on_ceiling():
			velocity.y = 1
		
	if state == State.Licking:
		tongue_grapple_point_sprite.position = tongue_grapple_point_sprite.position.linear_interpolate(tongue_grapple_point, 0.5)

		if (
			tongue_grapple_point_sprite.position.distance_to(tongue_grapple_point) < 1
		):			
			if current_bubble:
				change_state(State.Eating)
			elif is_stomping:
				change_state(State.Stomping)
			else:
				change_state(State.Swinging)
				
		play_audio(tongue_sfx)
	
	if state == State.Swinging:
		
		if tongue_grapple_point_sprite.current_collisions == 0:
			change_state(State.Moving)

		if "velocity" in grappled_object:
			tongue_grapple_point += grappled_object.velocity
			tongue_grapple_point_sprite.position = tongue_grapple_point

		var dir_to_grapple = (tongue_grapple_point - position).normalized()
		var speed_towards_point = velocity.dot(dir_to_grapple) 
		
		if collision_data:
			velocity = velocity.bounce(collision_data.normal) * 0.75
		dir = int(sign(velocity.x))
		
		if position.distance_to(tongue_grapple_point) > tongue_length:
			velocity -= speed_towards_point * dir_to_grapple
			position = tongue_grapple_point - dir_to_grapple * tongue_length
		if Input.is_action_just_released("action"):
			change_state(State.Moving)
			jump()

	if state == State.Eating:
		if position.distance_to(tongue_grapple_point) < 10:
			velocity *= bubble_launch_dropoff
			change_state(State.Moving)
			current_bubble.queue_free()
			exit_bubble()
			
			$HitStop.do_hit_stop(0.2)
		if current_bubble == null:
			change_state(State.Moving)

	if state == State.Stomping:
		if is_on_floor():
			$HitStop.do_hit_stop(0.1)
			is_stomping = false
			velocity.y = -stomp_launch_speed
			change_state(State.Moving)
	
	if aim_style == AimStyle.Free:
		tongue_ray.rotation_degrees = $Sprite.rotation_degrees - 45
		
	check_flip()
	update_tongue_visuals()



func change_state(new_state : int):
	tongue_grapple_point_sprite.visible = false

	if new_state == State.Moving:
		$TongueRay.visible = true;
		$Sprite.play("default")
		print("change state to moving")
		tongue_sprite.visible = false

	if new_state == State.Licking:
		print("change state to lick")
		tongue_sprite.set_squiggly()
		$Sprite.play("open")

		if current_bubble:
			tongue_grapple_point = current_bubble.food_sprite.global_position
		elif is_stomping:
			$Sprite.rotation_degrees = 180
			tongue_grapple_point = $FloorRay.get_collision_point()
		else:
			grab_grapple_point()

		stored_velocity = velocity
		velocity = Vector2.ZERO
		tongue_grapple_point_sprite.position = tongue_sprite_connect_pos.global_position
		tongue_sprite.visible = true

		if $GrappleCooldown.is_stopped():
			$GrappleCooldown.start()
	
	if new_state == State.Swinging:
		$TongueRay.visible = false;
		tongue_sprite.set_straight()
		print("change state to swinging")
		velocity = stored_velocity
		var artificial_vel = tongue_grapple_point - position
		artificial_vel.y *= -1
		artificial_vel *= 1
		velocity += artificial_vel
		tongue_grapple_point_sprite.visible = true
		tongue_grapple_point_sprite.position = tongue_grapple_point
	
	if new_state == State.Eating:
		tongue_sprite.set_straight()
		print("change state to eating")
		$Sprite.play("open")
		velocity = (tongue_grapple_point - position).normalized() * food_zip_speed
		dir = int(sign(velocity.x))

		$GrappleCooldown.stop()

	if new_state == State.Stomping:		
		velocity = Vector2.DOWN * stomp_speed

		$GrappleCooldown.stop()
	
	state = new_state


func enter_bubble(bubble):
	change_state(State.Moving)
	current_bubble = bubble


func exit_bubble():
	current_bubble = null


func play_audio(sfx):
	if not $AudioStreamPlayer2D.playing:
		$AudioStreamPlayer2D.stream = sfx
		$AudioStreamPlayer2D.play()


func jump():
	velocity.y = jump_vel
	play_audio(jump_sfx)


func grab_grapple_point():
	var collision_point = tongue_ray.get_collision_point()
	var collision_normal = tongue_ray.get_collision_normal()
	
	grappled_object = tongue_ray.get_collider()

	if grappled_object is TileMap:
		var tilemap = grappled_object as TileMap
		var tilemap_pos = tilemap.world_to_map(collision_point - collision_normal)
		var tile_hit = tilemap.get_cellv(tilemap_pos)
		var tile_hit_name = tilemap.tile_set.tile_get_name(tile_hit)
		
		var buds_dict:Dictionary = taste_buds.taste_buds
		if buds_dict.has(tile_hit_name):
			var affected_bud = buds_dict[tile_hit_name]
			affected_bud.add_mood(mood_add)

	tongue_grapple_point = collision_point - collision_normal * 4
	tongue_length = position.distance_to(tongue_grapple_point)


func check_flip():	
	if aim_style == AimStyle.Locked: 
		tongue_ray.rotation_degrees = 0
	if sign(dir) != sign($WallRay.cast_to.x):
		if aim_style == AimStyle.Locked: tongue_ray.cast_to.x *= -1
		$WallRay.cast_to.x *= -1
#		if (round($TongueGuide.rotation_degrees) == -135):
#			$TongueGuide.rotation_degrees -= 90
#		else:
#			$TongueGuide.rotation_degrees += 90


func update_tongue_visuals():
	var pointing_vec = tongue_grapple_point_sprite.position - tongue_sprite_connect_pos.global_position
	
	tongue_sprite.scale.y = pointing_vec.length() * tongue_length_normalizer
	tongue_sprite.rotation = pointing_vec.angle() + PI/2
	tongue_sprite.position = tongue_sprite_connect_pos.global_position

extends RigidBody2D

const TUG_FORCE = 1.15
const GRAVITY_SCALE = 1.2

var _TUG_FORCE = TUG_FORCE
var ivec = Vector2()
var main
var fired = false
var contact_point = Vector2()
var ray_colliding = false
var tween_done = true
var sprite_rotation = 0
var tween
var rope
var target
var target_sprite
var swish
var ray
var dust
var sprites
var can_latch = true
var dead = false
var helmet

var can_fire = false

func _ready():
	main = get_node("/root/main")
	rope = main.get_node("rope")
	rope = main.get_node("rope")
	tween = main.get_node("rope_tween")
	target = get_node("overlay/target")
	target_sprite = target.get_node("sprite")
	swish = get_node("swish")
	ray = get_node("ray")
	sprites = get_node("sprites")
	helmet = preload("res://scenes/helmet.tscn").instance()

	ivec = main.get_node("rope_attach").get_global_position()
	
	var player_target = main.get_node("player_target")
	player_target.set_global_position(Vector2(360/2, 640/2))
	set_global_position(player_target.get_global_position())
	rope.set_point_position(1, main.get_node("rope_attach").get_global_position())
	rope.show()
	
	$anim.stop()

	set_process_input(true)
	set_physics_process(true)
	
func item_obtained(item):
	
	if item.is_in_group("BEETLE"):
		add_hp(25)
	if item.is_in_group("HEART"):
		add_hp(global.max_hp)

func _integrate_forces(state):
		
		var gravity = state.get_total_gravity()*GRAVITY_SCALE
		var force = Vector2()
		
		if tween_done and not dead:
			force += (ivec - get_global_position() + (ivec - get_global_position())*_TUG_FORCE)
			
		force += gravity
		set_linear_velocity(force)
		
func _input(event):
	
	
	var btn_menu = main.menu.get_node("btn_menu")
	var menu_mouse_pos = btn_menu.get_local_mouse_position()

	if btn_menu.get_rect().has_point(menu_mouse_pos):
		can_fire = false
		
	if not can_fire:
		if event.is_action_pressed("fire"): can_fire = true
	
	
	if can_fire:
		
		if event.is_action_pressed("fire") and can_fire:
			var cast_to = get_local_mouse_position()
			ray.set_cast_to(cast_to + cast_to.normalized()*target_sprite.texture.get_size().x*7.5)
		
		if event.is_action_released("fire") and not dead and tween_done and can_fire:
			
			if can_latch:
				target.set_modulate(Color(1.0,1.0,1.0,1.0))
				
				if tween.is_active(): tween.stop_all()
				
				tween.interpolate_property(self, "ivec", ray.get_global_position(),
					contact_point, 0.2, tween.TRANS_LINEAR, tween.EASE_OUT)
				tween.interpolate_property(self, "sprite_rotation", sprite_rotation,
					PI*1.5 + get_global_position().angle_to_point(ivec), 0.2,
					tween.TRANS_LINEAR, tween.EASE_IN_OUT)
				
				if not tween.is_active():
					swish.play()
					tween.start()
					tween_done = false
					
			else:
				target.set_modulate(Color(1.0,0.0,0.0,0.8))
			
			target_sprite.get_node("anim").stop()
			target.set_position(get_viewport().get_mouse_position())
			target.show()
			target_sprite.get_node("anim").play("explode")

func _physics_process(delta):
	

	ray_colliding = ray.is_colliding()
	if ray_colliding:
		
		var col = ray.get_collider()
		if col != null:
			if col.is_in_group("LATCH"):
				contact_point = ray.get_collision_point()
				can_latch = true
				if col.is_in_group("GRAPPLE"):
					_TUG_FORCE = 10
				else:
					_TUG_FORCE = TUG_FORCE
			else:
				can_latch = false
		else:
			can_latch = false
	else:
		can_latch = false
	
	#rotate the sprite to match the angle
	var to_angle = PI*1.5 + get_global_position().angle_to_point(ivec)
	sprite_rotation = lerp(sprite_rotation, to_angle, 0.9*delta)
	sprites.set_rotation(sprite_rotation)
	
	#match first end of rope x and y position with player x and y position
	rope.set_point_position(0, $sprites/rope_from.get_global_transform().get_origin())
	rope.set_point_position(1, ivec)
	
	#set the hook sprite
	rope.get_node("hook").set_global_position(ivec)
	rope.get_node("hook").set_rotation(PI*1.5 + get_global_position().angle_to_point(ivec))

func _on_player_body_entered(body):

	if body.is_in_group("THREAT"):
		if $death_ticker.is_stopped():
			do_hit(25, true, true)

func add_hp(num):
	num = get_hp() + num
	main.hp_meter.set_value(num)

func get_hp():
	return main.hp_meter.get_value()

func do_hit(d = 25, shake = true, factor = false):

	if factor:
		var v = get_linear_velocity().length()*0.5
		if v < 50: d = 5
		if v > 50 and v < 100: d = 10
		if v > 100 and v < 150: d = 15
		if v > 150: d = 20
	
	add_hp(-1*d)
	
	$hit_sfx.play()
	sprites.set_animation("dead")
	
	if shake:
		main.shaker.get_node("shake_dur").stop()
		main.shaker.get_node("shake_dur").start()
		main.shaker.get_node("shake_freq").start()
	
	if get_hp() <= 0:
		target.hide()
		main.get_node("dust_particles").hide()
		main.get_node("rope").hide()
		dead = true
		tween.stop_all()
		$death_ticker.start()
		$sprites/helmet_sprite.hide()
		helmet.set_global_position($sprites/helmet_sprite.get_global_transform().get_origin())
		#main.add_child(helmet)
		main.call_deferred("add_child", helmet)
		#set_mode(RigidBody2D.MODE_RIGID)
		call_deferred("set_mode", RigidBody2D.MODE_RIGID)
		$anim.play("falling")
		
	$death_ticker.start()

func _on_death_ticker_timeout():
	if dead:
		main.call("_on_death")
	else:
		sprites.set_animation("default")

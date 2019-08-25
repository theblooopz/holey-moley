extends Node

const BEETLE_POINTS = 25
const SCORE_FACTOR = 50

#scale difficulty
var start_wait_time = 1.85
var wait_time_rate = 0.4/1000

var generator_ticker
var player
var player_target
var latch_pool
var camera
var latch_engine
var score_ticker
var hp_meter
var meters
var dust
var hook_fx
var items
var latches
var menu
var score_label
var best_label
var score_meters
var destroyer
var walls
var shaker
var reward_video_container
var ad
var ad2

var latch_spawns = []
var score = 0
var score_rollover = 0
var can_generate = true
var max_depth = 0

var bg_cave
var bg_cave_left
var bg_cave_right
var dead = false

func _ready():

	player_target = get_node("player_target")
	latch_pool = get_node("latch_pool")
	camera = get_node("camera")
	shaker = camera.get_node("shaker")
	destroyer = get_node("destroyer")
	walls = get_node("walls")
	player = preload("res://scenes/player.tscn").instance()
	latch_engine = player_target.get_node("latch_engine")
	menu = get_node("hud/VBoxContainer/menu_score/menu")
	hp_meter = get_node("hud/VBoxContainer/menu_score/score_meters/meters/hp_meter")
	meters = get_node("hud/VBoxContainer/menu_score/score_meters/meters")
	dust = get_node("dust")
	hook_fx = get_node("hook_fx")
	items = preload("res://scenes/items.tscn").instance()
	score_label = get_node("hud/VBoxContainer/menu_score/score_meters/score_label")
	best_label = get_node("hud/VBoxContainer/menu_score/score_meters/best_label")
	score_meters = get_node("hud/VBoxContainer/menu_score/score_meters")
	reward_video_container = get_node("hud/death_note/VBoxContainer/reward_video_container")
	ad = get_node("hud/VBoxContainer/ad")
	ad2 = get_node("hud/help/ad_space")
	
	latch_spawns = latch_engine.get_node("latch_spawns/spawns").get_children()
	latches = preload("res://scenes/latches.tscn").instance()
	generator_ticker = get_node("generator_ticker")
	
	bg_cave = get_node("cave/bg_cave")
	bg_cave_left = get_node("cave/bg_cave_left")
	bg_cave_right = get_node("cave/bg_cave_right")
	
	$hud/pause_shade/anim.stop()
	
	get_tree().connect("screen_resized", self, "_on_screen_resized")
	
	set_physics_process(true)
	
	if global.playing:
		menu.get_node("btn_menu").set_text("MENU")
		do_play()
	
	randomize()

	if global.mute:
		menu.get_node("btn_mute").set_text("UNMUTE")
	else:
		menu.get_node("btn_mute").set_text("MUTE")
	if global.mute_sfx:
		menu.get_node("btn_mute_sfx").set_text("UNMUTE SFX")
	else:
		menu.get_node("btn_mute_sfx").set_text("MUTE SFX")
	
	AudioServer.set_bus_mute(AudioServer.get_bus_index("MUSIC"), global.mute)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), global.mute_sfx)
		
	if global.fullscreen:
		menu.get_node("btn_fullscreen").set_text("WINDOW")
	
	OS.set_window_fullscreen(global.fullscreen)
	
	if global.ad_banner_loaded:
		show_ad_banner_panel()
	if global.ad_video_loaded:
		show_ad_video_panel()

func show_ad_banner_panel(val = true):
	if !val:
		ad.hide()
		return
		
	ad.set_custom_minimum_size(Vector2(1,global.ad_banner_height+5))
	ad.show()
	
	ad2.set_custom_minimum_size(Vector2(1,global.ad_banner_height+5))

func show_ad_video_panel(val = true):
	if !val:
		reward_video_container.hide()
		return
	reward_video_container.show()

func _on_screen_resized():
	do_fullscreen(false)

func do_shake():
	var amp = 5
	var rand = Vector2(0,0)
	rand.x = 0
	rand.y = rand_range(-amp, amp)
	shaker.interpolate_property(camera, "offset", camera.offset, camera.offset + rand,
		shaker.get_node("shake_freq").wait_time, Tween.TRANS_LINEAR,Tween.EASE_IN)
	shaker.start()

func _on_shake_freq_timeout():
	do_shake()

func _on_shake_dur_timeout():
	shaker.stop_all()
	shaker.get_node("shake_freq").stop()
	
func _physics_process(delta):
	
	if global.playing:
		
		#match player_target y position with player y position
		#if not player.dead:
		#	var player_y = player.get_global_position().y 
		#	var player_target_x = player_target.get_global_position().x 
		#	player_target.set_global_position(Vector2(player_target_x, player_y))
		player_target.set_global_position(Vector2(player_target.get_global_position().x,
			camera.get_offset().y + get_viewport().size.y/2))
		
		#reset camera and retain score in the highly unlikely chance limit is reached
		var cam_y = camera.get_camera_position().y + get_viewport().size.y
		if  cam_y >= camera.get_limit(MARGIN_BOTTOM):
			player.set_global_position(
					Vector2(get_viewport().size.x/2,
					(get_viewport().size.y/2) + 640*2)
				)
			score_rollover += score
		
		#scroll camera and destroyer down
		var scroll_speed = 200*delta
		
		camera.offset.y += scroll_speed
		
		destroyer.set_global_position(Vector2(destroyer.get_global_position().x,
			camera.offset.y - 100))
		walls.set_global_position(Vector2(walls.get_global_position().x, 
			camera.offset.y))
			
		#add length to cave backdrop if it needs it
		var amount = camera.get_offset().y + get_viewport().size.y
		if bg_cave.get_region_rect().size.y < amount:
			bg_cave.set_region_rect(Rect2(0, 0, bg_cave.get_region_rect().size.x, amount))
		if bg_cave_left.get_region_rect().size.y < amount:
			bg_cave_left.set_region_rect(Rect2(0, 0, bg_cave_left.get_region_rect().size.x, amount))
		if bg_cave_right.get_region_rect().size.y < amount:
			bg_cave_right.set_region_rect(Rect2(3, 0, bg_cave_right.get_region_rect().size.x, amount))
		
		
		#keep score and get max depth
		if not player.dead:
			
			#get max depth
			if player.get_global_position().y > max_depth:
				max_depth = player.get_global_position().y
			
			#keep score
			score = score_rollover + max_depth/SCORE_FACTOR
			if score < 0: score = 0
			score = round(score)
			score_label.set_text(str(score))
		
		#update best label
		if max_depth > global.best:
			best_label.set_text("BEST: " + str(round(max_depth/SCORE_FACTOR)))
		else:
			best_label.set_text("BEST: " + str(round(global.best/SCORE_FACTOR)))
		
		var wt = generator_ticker.get_wait_time() - (wait_time_rate)*(1/start_wait_time)
		wt = max(0.3, wt)
		generator_ticker.set_wait_time(wt)

func _on_btn_play_pressed():
	global.playing = true
	do_restart()

func do_play():

	#capture the mouse
	#if not global.OS_is("HTML5"):
	#	Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)

	var pos = get_node("player_target").get_global_position()
	add_child(player)
	player.set_global_position(pos)
	
	for child in $latch_pool.get_children():
		$latch_pool.remove_child(child)
		child.queue_free()

	meters.show()
	
	$hud/death_note.hide()
	$hud/title_menu.hide()
	
	hp_meter.set_max(global.max_hp)
	hp_meter.set_value(global.max_hp)
	
	score = 0
	score_rollover = 0
	score_label.set_text("0")
	
	if global.playing and get_tree().is_paused():
		do_pause()

	score_meters.show()
	menu.get_node("btn_menu").set_text("MENU")
	global.playing = true
	generator_ticker.start()
	generate()
	
func generate():
	
	if can_generate:
		
		var skip = 0
		
		for latch_spawn in latch_spawns:
			
			skip = randi() % 4
			if skip == 1 or skip == 2:
				
				
				var show_item = randi() % 11
				if show_item == 1:
					
					var ri = randi() % items.get_children().size()
					var new_item = items.get_children()[ri]
					var new_item_chance = new_item.chance
					
					var scale = 0
					if hp_meter.get_value() <= 50:
						scale = 15
					if hp_meter.get_value() <= 25:
						scale = 25
					if hp_meter.get_value() <= 15:
						scale = 45
					
					var skip_item = randi() % 101
					if skip_item > new_item_chance*100 + scale: continue

					var pos = latch_spawn.get_global_position()
					var offset = 50
					if latch_spawn.is_in_group("SPAWN_RIGHT"):
						offset *= -1
					
					var new_item_dup = new_item.duplicate()
					new_item_dup.set_global_position(pos + Vector2(offset,0))
					$latch_pool.add_child(new_item_dup, true)
				
				continue
			
			var sx = randi() % 2
			var sy = randi() % 2
			if not sx: sx = -1
			if not sy: sy = -1
			
			if skip == 3:
				if sx == -1: sx = -1.15
				if sx == 1: sx = 1.15
			
			#random threat
			var rl = randi() % latches.get_children().size()
			var new_latch = latches.get_children()[rl].duplicate()
			var pos = latch_spawn.get_global_position()
			new_latch.set_global_position(pos)
			new_latch.apply_scale(Vector2(sx, sy))
			$latch_pool.add_child(new_latch, true)

func _on_generator_ticker_timeout():
	if player.get_global_position().y > max_depth:
		generate()

func _on_destroyer_body_enter( body ):
	if body.is_in_group("THREAT"):
		body.queue_free()
	if body.is_in_group("PLAYER"):
		player.do_hit(player.get_hp())

func _on_btn_menu_pressed():
	do_pause()
	
func do_pause():
	
	if dead: return
	
	player.can_fire = false

	var paused = get_tree().is_paused()
	if not paused:
		#if not global.OS_is("HTML5"): Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		menu.get_node("btn_menu").set_text("CONTINUE")
		
		global.show_group(menu, "SHOW_PAUSE")

		if global.OS_is("HTML5") or global.OS_is("Android"): 
			menu.get_node("btn_fullscreen").hide()
		
		if global.OS_is("HTML5"):
			menu.get_node("btn_quit").hide()

		if not global.playing: menu.get_node("btn_restart").hide()
		
		$hud/pause_shade.fade_show()
	else:
		#if global.playing: 
		#	if not global.OS_is("HTML5"): Input.set_mouse_mode(Input.MOUSE_MODE_CONFINED)
		menu.get_node("btn_menu").set_text("MENU")
		global.hide_group(menu, "SHOW_PAUSE")
		
		$hud/pause_shade.fade_hide()
	
	get_tree().set_pause(not paused)

func _on_btn_restart_pressed():
	do_restart()

func _on_btn_mute_pressed():
	do_mute("MUSIC")

func _on_btn_mute_sfx_pressed():
	do_mute("SFX")

func do_mute(what):
	
	var bus = AudioServer.get_bus_index(what)
	var val = !AudioServer.is_bus_mute(bus)
	AudioServer.set_bus_mute(bus, val)
	
	if what == "MUSIC":
		global.mute = val
		var btn_mute = menu.get_node("btn_mute")
		if val: btn_mute.set_text("UNMUTE")
		else: btn_mute.set_text("MUTE")
	if what == "SFX":
		global.mute_sfx = val
		var btn_mute_sfx = menu.get_node("btn_mute_sfx")
		if val == false:
			$hook_fx.play()
		if val: btn_mute_sfx.set_text("UNMUTE SFX")
		else: btn_mute_sfx.set_text("MUTE SFX")

func _on_death():
	
	#show video reward button if available and reset max hp
	#set_ad_video()
	
	global.max_hp = 100
	
	do_pause()
	dead = true
	death_message()
	menu.get_node("btn_menu").hide()
	$hud/death_note.show()
	if global.best < max_depth:
		global.best = max_depth
	
	var config = ConfigFile.new()
	config.set_value("score","best",global.best)
	config.save("user://score.cfg")

func death_message():
	var msg = "You Failed"
	
	if score > 250:
		msg = "Good job"
	if score > 400:
		msg = "You are doing well"
	if score > 800:
		msg = "That is impressive"
	if score > 1500:
		msg = "Amazing job"
	if score > 3000:
		msg = "Are you even human?"
	if score > 5000:
		msg = "You're a god"
	
	$hud/death_note/VBoxContainer/death_note.set_text(msg)
	$hud/death_note.show()

func _on_btn_quit_pressed():
	if global.OS_is("HTML5"): return
	get_tree().quit()

func _on_btn_fullscreen_pressed():
	do_fullscreen()

func do_restart():
	global.music_seek = $music.get_playback_position()
	global.fullscreen = OS.is_window_fullscreen()
	get_tree().change_scene("res://scenes/main.tscn")

func do_fullscreen(flag = true):
	
	if global.OS_is("HTML5"): return
	
	if flag:
		OS.set_window_fullscreen(!OS.is_window_fullscreen())
	
	if not OS.is_window_fullscreen():
		menu.get_node("btn_fullscreen").set_text("FULLSCREEN")
	else:
		menu.get_node("btn_fullscreen").set_text("WINDOW")

func _on_rope_tween_tween_completed(object, key):
	if dead: return
	
	player.tween_done = true
	
	var new_dust = dust.duplicate()
	new_dust.get_node("anim").stop()
	new_dust.set_global_position(player.ivec)
	$dust_particles.add_child(new_dust)
	new_dust.get_node("anim").play("puff")
	
	hook_fx.set_global_position(player.ivec)
	hook_fx.play()

func _on_btn_reward_pressed():
	global.showRewardedVideo()


func _on_btn_instructions_pressed():
	$hud/help.show()
	$hud/title_menu.hide()
	menu.hide()
	if not get_tree().is_paused():
		do_pause()


func _on_btn_back_pressed():
	$hud/help.hide()
	$hud/title_menu.show()
	menu.show()
	if get_tree().is_paused():
		do_pause()

func _on_main_tree_exited():
	if global.best < max_depth:
		global.best = max_depth
	var config = ConfigFile.new()
	config.set_value("score","best",global.best)
	config.save("user://score.cfg")

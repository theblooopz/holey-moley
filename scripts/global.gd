extends Node

var fullscreen = false
var playing = false
var mute = false
var mute_sfx = false
var music_seek = 0.0
var best = 0

var admob = null
var isReal = true
var isTop = true

var adBannerId = ""
var adRewardedId = ""
var ad_banner_loaded = false
var ad_video_loaded = false
var ad_banner_height = 0

var max_hp = 100

func _ready():

	if OS.is_debug_build():
		mute = true
		isReal = false
		
	"""
	have to do this manually because admob module isn't returning correct height values
	got info about dpi and banner height from here: https://developers.google.com/admob/android/banner
	"""
	var dpi = OS.get_screen_dpi()
	#var screen_height = OS.get_window_size().x #using width because in portrait mode
	
	if dpi <= 400:
		ad_banner_height = 32
	if dpi > 400 and dpi <= 720:
		ad_banner_height = 50
	if dpi > 720:
		ad_banner_height = 90
	
	if Engine.has_singleton("AdMob") and OS_is("Android"):
		admob = Engine.get_singleton("AdMob")
		admob.init(isReal, get_instance_id())
		loadBanner()
		loadRewardedVideo()
		admob.resize()
		
	OS.center_window()

	var config = ConfigFile.new()
	var err = config.load("user://score.cfg")
	if err == OK:
		best = config.get_value("score","best",0)

	get_tree().connect("screen_resized", self, "_on_resize")
	set_pause_mode(Node.PAUSE_MODE_PROCESS)
	set_process_input(true)
	
func _on_resize():
	if admob != null:
		admob.resize()

func _on_admob_ad_loaded():
	ad_banner_loaded = true
	var main = get_node("/root/main")
	admob.showBanner()
	main.show_ad_banner_panel()
	loadRewardedVideo()
		
func _on_rewarded_video_ad_loaded():
	ad_video_loaded = true
	var main = get_node("/root/main")
	main.show_ad_video_panel()

func loadBanner():
	if admob != null:
		admob.loadBanner(adBannerId, isTop)

func loadRewardedVideo():
	if admob != null:
		admob.loadRewardedVideo(adRewardedId)

func showRewardedVideo():
	if admob != null:
		admob.showRewardedVideo()

func _on_rewarded(currency, amount):
	var main = get_node("/root/main")
	
	if currency == "Health":
		max_hp = 100 + amount
		
	main.do_restart()
	
func _on_rewarded_video_ad_closed():
	loadRewardedVideo()
	
func _on_rewarded_video_ad_failed_to_load(errorCode):
	ad_video_loaded = false
	var main = get_node("/root/main")
	main.show_ad_video_panel(false)

func _on_admob_network_error():
	ad_banner_loaded = false
	var main = get_node("/root/main")
	admob.hideBanner()
	main.show_ad_banner_panel(false)

func show_group(node, group, show=true):
	for child in node.get_children():
		if child.is_in_group(group):
			if show: child.show()
			else: child.hide()

func hide_group(node, group):
	show_group(node,group,false)

func OS_is(name):
	return OS.get_name() == name

func set_seek(seek):
	music_seek = seek

func _input(event):
	
	var main = get_node("/root/main")

	if event.is_action_pressed("fullscreen"):
		main.call("do_fullscreen")

	if event.is_action_pressed("ui_cancel"):
		main.call("do_pause")
		
	if event.is_action_pressed("restart"):
		main.call("do_restart")

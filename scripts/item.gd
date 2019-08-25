extends Area2D

export var chance = 0.1

var collided = false

func _on_beetle_body_entered(body):
	if body.is_in_group("PLAYER"):
		if body.has_method("item_obtained"):
			if not collided:
				collided = true
				body.item_obtained(self)
				$item_anim.play("vanish")

func play_sfx():
	$sfx.play()
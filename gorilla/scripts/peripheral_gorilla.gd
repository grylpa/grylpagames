extends Node2D

signal exited_screen

var velocity: Vector2 = Vector2.ZERO
var screen_rect: Rect2 = Rect2()

func _ready() -> void:
	$Sprite.play("Enemy")

func _process(delta: float) -> void:
	position += velocity * delta
	if velocity.length_squared() > 0:
		if velocity.x > 0:
			$Sprite.rotation = 0
			$Sprite.flip_h = false
		elif velocity.x < 0:
			$Sprite.rotation = 0
			$Sprite.flip_h = true
		elif velocity.y > 0:
			$Sprite.rotation = PI / 2
			$Sprite.flip_h = false
		else:
			$Sprite.rotation = -PI / 2
			$Sprite.flip_h = false
	if  velocity.x < 0 and position.x < screen_rect.position.x or \
		velocity.y < 0 and position.y < screen_rect.position.y or \
		velocity.x > 0 and position.x > screen_rect.end.x or \
		velocity.y > 0 and position.y > screen_rect.end.y:
		exited_screen.emit()
		queue_free()

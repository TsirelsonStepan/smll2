extends RigidBody2D

@onready var raycast = $RayCast2D
@onready var player = $"/root/Main/Game/Player"

func _ready():
	contact_monitor = true
	max_contacts_reported = 2

func _physics_process(_delta):
	if (player.position - position).length() > player.SPEED * 0.95:
		player._chaser_defeated()
		queue_free()
	raycast.target_position = (player.position - position).rotated(-rotation)
	raycast.force_raycast_update()
	if (!raycast.is_colliding()):
		linear_velocity = (player.position - position).normalized() * (player.SPEED * 0.95)
	else:
		for i in range(player.past_points.size()):
			var target = player.past_points[player.past_points.size() - i - 1]
			raycast.target_position = (target - position).rotated(-rotation)
			raycast.force_raycast_update()
			if !raycast.is_colliding():
				linear_velocity = (target - position).normalized() * (player.SPEED * 0.95)
				break

func _on_collision(body):
	if body == player: player._gameend()

func _on_timer_timeout():
	player._chaser_defeated()
	queue_free()

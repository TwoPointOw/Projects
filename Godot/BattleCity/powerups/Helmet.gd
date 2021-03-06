const ShieldScn = preload("res://effects/Shield.tscn")
const ShieldGd = preload("res://powerups/Shield.gd")


func execute( stage, tank ):
	var shield = tank.get_node("Shield")
	if shield != null:
		shield.resetDuration()
		return

	var shieldEffect = ShieldScn.instance()
	shieldEffect.set_script(ShieldGd)
	tank.add_child(shieldEffect)

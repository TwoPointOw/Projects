extends AgentBase

const LevelLoaderGd          = preload("res://core/game/LevelLoader.gd")
const FogVisionBaseGd        = preload("res://core/level/FogVisionBase.gd")
const SquareFogVisionGd      = preload("res://core/level/SquareFogVision.gd")
const SelectionComponentScn  = preload("res://core/SelectionComponent.tscn")


var _game : Node                       setget deleted
var _selectedUnits := {}               setget deleted


func deleted(_a):
	assert(false)


func _ready():
	$"SelectionBox".connect("areaSelected", self, "_selectUnitsInRect")


func _physics_process(delta):
	var movement := Vector2(0, 0)

	if Input.is_action_pressed("gameplay_up"):
		movement.y -= 1
	if Input.is_action_pressed("gameplay_down"):
		movement.y += 1
	if Input.is_action_pressed("gameplay_left"):
		movement.x -= 1
	if Input.is_action_pressed("gameplay_right"):
		movement.x += 1

	if movement:
		for unit in _selectedUnits:
			assert( unit is UnitBase )
			assert( unit.is_inside_tree() )
			unit.moveInDirection( movement )


func _unhandled_input(event):
	if event.is_action_pressed("travel"):
		_onTravelRequest()


func initialize( gameScene : Node ):
	assert( is_instance_valid(gameScene) )
	_game = gameScene


func addUnit( unit : UnitBase ):
	.addUnit( unit ) == OK && _makeAPlayerUnit( unit )
	selectUnit( unit )


func removeUnit( unit : UnitBase ) -> bool:
	if unit in _selectedUnits:
		deselectUnit( unit )
	var removed = .removeUnit( unit )
	removed && _unmakeAPlayerUnit( unit )
	return removed


func selectUnit( unit : UnitBase ):
	assert( unit in _units.container() )

	if unit in _selectedUnits:
		return FAILED

	for child in unit.get_children():
		if child.filename != null and child.filename == SelectionComponentScn.resource_path:
			child.get_node("Perimeter").visible = true
			_selectedUnits[ unit ] = child
			return OK

	assert( !"unit %s has no selection box" % [unit] )


func deselectUnit( unit : UnitBase ):
	assert( unit in _units.container() )
	if not unit in _selectedUnits:
		return FAILED

	if is_instance_valid( _selectedUnits[ unit ] ):
		_selectedUnits[ unit ].get_node("Perimeter").visible = false

	_selectedUnits.erase( unit )
	return OK


func _selectUnitsInRect( selectionRect : Rect2 ):
	print( "selection rect %s" % [selectionRect] ) # TODO: select units


func getSelected() -> Array:
	return _selectedUnits.keys()


func serialize():
	var unitNamesAndSelection := {}
	for unit in _units.container():
		assert( unit is UnitBase )
		assert( unit.is_inside_tree() )
		unitNamesAndSelection[unit.name] = unit in _selectedUnits
	return unitNamesAndSelection


func deserialize( data ):
	for unitName in data:
		assert( _game.currentLevel.getUnit( unitName ) )
		addUnit( _game.currentLevel.getUnit( unitName ) )


func postDeserialize():
	_game.currentLevel.update()


func _makeAPlayerUnit( unit : UnitBase ):
	var hasFogVision := false
	for child in unit.get_children():
		if child is FogVisionBaseGd:
			hasFogVision = true
			break

	if not hasFogVision:
		unit.add_child( SquareFogVisionGd.new() )

	var selection = SelectionComponentScn.instance()
	unit.add_child( selection )


func _unmakeAPlayerUnit( unit : UnitBase ):
	for child in unit.get_children():
		if child is FogVisionBaseGd:
			child.queue_free()
			unit.remove_child( child )
		elif child.filename != null and child.filename == SelectionComponentScn.resource_path:
			child.queue_free()
			unit.remove_child( child )


func _onTravelRequest():
	yield( get_tree(), "idle_frame" )
	var currentLevel : LevelBase = _game.currentLevel
	var entrance : Area2D = currentLevel.findEntranceWithAllUnits( _unitsInTree )

	if entrance == null:
		return

	var levelAndEntranceNames : Array = _game._module.getTargetLevelFilenameAndEntrance(
		currentLevel.name, entrance.name )

	if levelAndEntranceNames.empty():
		return

	var levelName : String = levelAndEntranceNames[0].get_file().get_basename()
	var entranceName : String = levelAndEntranceNames[1]
	var result : int = yield( _game.loadLevel( levelName ), "completed" )

	if result != OK:
		return

	assert( _unitsInTree.empty() )

	LevelLoaderGd.insertPlayerUnits( _units.container(), _game.currentLevel, entranceName )

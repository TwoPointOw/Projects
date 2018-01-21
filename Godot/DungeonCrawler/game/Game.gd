extends Node

const GameSceneScn = "res://game/GameScene.tscn"
const LevelLoaderGd = preload("res://levels/LevelLoader.gd")
const PlayerAgentGd = preload("res://actors/PlayerAgent.gd")

const NodeName = "Game"
enum UnitFields {PATH = 0, OWNER = 1, NODE = 2}

var m_levelLoader = LevelLoaderGd.new()  setget deleted
var m_module_                         setget deleted
var m_playerUnitsCreationData = []    setget deleted
var m_playerUnits = []                setget deleted
var m_currentLevel                    setget deleted


signal gameStarted
signal gameEnded


func deleted():
	assert(false)


func _init(module_ = null, playerUnitsData = null):
	assert( module_ != null == Network.isServer() )
	assert( playerUnitsData != null == Network.isServer() )
	set_name(NodeName)
	m_module_ = module_
	m_playerUnitsCreationData = playerUnitsData


func _enter_tree():
	Connector.connectGame( self )
	setPaused(true)
	if is_network_master():
		prepare()


func _exit_tree():
	setPaused(false)
	emit_signal("gameEnded")


func _notification(what):
	if what == NOTIFICATION_PREDELETE:
		if m_module_ != null:
			m_module_.free()


func _input(event):
	if event.is_action_pressed("ui_select"):
		changeLevel()


func setPaused( enabled ):
	get_tree().set_pause(enabled)
	Utility.emit_signal("sendVariable", "Pause", "Yes" if enabled else "No")


func prepare():
	assert( Network.isServer() )

	m_playerUnits = createPlayerUnits( m_playerUnitsCreationData )
	m_currentLevel = m_levelLoader.loadLevel( m_module_.getStartingLevel(), self )
	m_levelLoader.insertPlayerUnits( m_playerUnits, m_currentLevel )

	Network.readyToStart( get_tree().get_network_unique_id() )

	for playerId in Network.m_players:
		if playerId == Network.ServerId:
			continue

		rpc_id(
			playerId, 
			"loadLevel",
			m_currentLevel.get_filename(),
			m_currentLevel.get_parent().get_path(),
			m_currentLevel.get_name()
			)
		m_currentLevel.sendToClient(playerId)

	assignAgentsToPlayerUnits( m_playerUnits )


slave func loadLevel(filePath, nodePath):
	m_levelLoader.loadLevel(filePath, get_tree().get_root().get_node(nodePath))
	Network.rpc_id( get_network_master(), "readyToStart", get_tree().get_network_unique_id() )


remote func start():
	if is_network_master():
		rpc("start")

	setPaused(false)
	emit_signal("gameStarted")
	SceneSwitcher.switchScene( GameSceneScn )


func finish():
	self.queue_free()


func createPlayerUnits( unitsCreationData ):
	var playerUnits = []
	for unitData in unitsCreationData:
		var unitNode_ = load( unitData["path"] ).instance()
		unitNode_.set_name( str( Network.m_players[unitData["owner"]] ) + "_" )
		unitNode_.setNameLabel( Network.m_players[unitData["owner"]] )
		playerUnits.append( {OWNER : unitData["owner"], NODE : unitNode_} )

	return playerUnits


func assignAgentsToPlayerUnits( playerUnits ):
	assert( is_network_master() )

	for unit in playerUnits:
		var ow = unit[OWNER]
		if unit[OWNER] == get_tree().get_network_unique_id():
			assignOwnAgent( unit[NODE].get_path() )
		else:
			rpc_id( unit[OWNER], "assignOwnAgent", unit[NODE].get_path() )


remote func assignOwnAgent( unitNodePath ):
	var unitNode = get_node( unitNodePath )
	assert( unitNode )
	var playerAgent = Node.new()
	playerAgent.set_network_master( get_tree().get_network_unique_id() )
	playerAgent.set_script( PlayerAgentGd )
	playerAgent.setActions( PlayerAgentGd.PlayersActions[0] )
	playerAgent.assignToUnit( unitNode )


func changeLevel():
	var nextLevelPath = m_module_.getNextLevel()
	if nextLevelPath == null:
		return

	var currentLevel = m_currentLevel
	if currentLevel == null:
		return

	for playerUnit in m_playerUnits:
		# leaving nodes without parent
		playerUnit[NODE].get_parent().remove_child( playerUnit[NODE] )

	Utility.setFreeing( currentLevel )
	currentLevel = null

	m_currentLevel = m_levelLoader.loadLevel( nextLevelPath, self )
	m_levelLoader.insertPlayerUnits( m_playerUnits, m_currentLevel )

	for playerId in Network.m_players:
		if playerId == Network.ServerId:
			continue

		rpc_id(
			playerId, 
			"loadLevel",
			m_currentLevel.get_filename(),
			m_currentLevel.get_parent().get_path(),
			m_currentLevel.get_name()
			)
		m_currentLevel.sendToClient(playerId)


func save( filePath ):
	var saveFile = File.new()
	if OK != saveFile.open(filePath, File.WRITE):
		return

	var saveDict = {}
	saveDict[m_currentLevel.get_name()] = m_currentLevel.save()

	saveFile.store_line(to_json(saveDict))
	saveFile.close()


func load(saveDict):
	pass


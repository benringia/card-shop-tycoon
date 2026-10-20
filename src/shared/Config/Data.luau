--!strict
-- Player data storage. See DESIGN.md section 10.4.
return {
	STORE_NAME = "PlayerData",
	KEY_PREFIX = "Player_",
	SCHEMA_VERSION = 2, -- bump and add a migration in DataService when the data shape changes
	LOAD_FAILED_MESSAGE = "Your shop data couldn't be loaded. Please rejoin in a moment.",
	SESSION_ENDED_MESSAGE = "Your shop was opened on another server.",
}

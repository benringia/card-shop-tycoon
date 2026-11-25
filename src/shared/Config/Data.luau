--!strict
-- Player data storage. See DESIGN.md section 10.4.
return {
	STORE_NAME = "PlayerData",
	KEY_PREFIX = "Player_",
	SLOT_STORE = "OwnerSaveSlot", -- the game's owner's chosen save ("/slot test | main | reset": SaveSlotService)
	-- Studio only: true and every Play starts a brand-new save kept in memory, never written (ProfileStore's Mock), to play
	-- a new player's first minutes again and again; the real and test saves aren't touched (DataService, SaveSlots.fresh)
	STUDIO_FRESH = false,
	SCHEMA_VERSION = 44, -- bump and add a migration in server/Util/Migrations when the data shape changes (43: storage racks' boxes; 44: weapon mutations)
	LOAD_FAILED_MESSAGE = "Your shop data couldn't be loaded. Please rejoin in a moment.",
	SESSION_ENDED_MESSAGE = "Your shop was opened on another server.",
}

---------------------------------------------------------------------------------------------
-- Copyright (c) 2025 Ayios. All rights reserved.
-- All code within this repository created by Ayios is under MIT license. Other code within
-- this repository is under its own respective license which will be displayed within their
-- respective files or around the areas of their code.
-- See LICENSE in the project root for license information.
---------------------------------------------------------------------------------------------
return {
	Name = "unban";
	Description = "Unban a player from the game.";
	Group = "DefaultAdmin";
	Args = {
		{
			Type = "playerId";
			Name = "player";
			Description = "The player to ban.";
		},
        {
            Type = "string";
            Name = "reason";
            Description = "The reason for the ban.";
        }
	};
}
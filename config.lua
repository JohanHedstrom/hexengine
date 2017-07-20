application =
{

	content =
	{
		--width = 375,
		--height = 667, 
		--scale = "letterBox",
        scale = "adaptive",
		fps = 30,

		imageSuffix =
		{
			["@2x"] = 1.5,
			["@3x"] = 2.5,
		},
		
	},

	--[[
	-- Push notifications
	notification =
	{
		iphone =
		{
			types =
			{
				"badge", "sound", "alert", "newsstand"
			}
		}
	},
	--]]    
}

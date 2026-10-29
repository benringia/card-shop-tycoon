--!strict
-- Where the 3D pack opening's cards sit on screen (UI project 3 spec 4.6; Util/OpeningLayout). Plain data, so Lune
-- tests load it (Config/PackOpening holds Color3s).
return {
	LAYOUT = {
		rowHeight = 0.13, -- a row card's height, share of the screen height
		rowGap = 10, -- px between row cards
		rowBottom = 0.12, -- the row's gap to the screen's bottom (clear of the letterbox bar), share of the height
		maxCard = 140, -- px, the widest a lineup card gets
		gap = 22, -- px between lineup cards
		side = 70, -- px kept clear at each side
		lineupCentre = 0.47, -- the lineup's middle, share of the height below the top bar
		lineupHeight = 0.55, -- the tallest a lineup card gets, share of the height below the top bar
	},
}

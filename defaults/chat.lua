local ADDON, Engine = ...

-- chat windows and frames
Engine:NewConfig("ChatWindows", {
	autoposition = true, -- whether or not to autoposition the default chat frame 
	hasbeenqueried = false -- whether the user has been asked about the previous
})

-- chat filters and emoticons
Engine:NewConfig("ChatFilters", {})

-- chat bubbles
Engine:NewConfig("ChatBubbles", {})

-- chat sounds
Engine:NewConfig("ChatSounds", {})

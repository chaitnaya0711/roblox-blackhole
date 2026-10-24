local Config = {
	Center = Vector3.new(0, 500, 0),
	D = 60,
	FOV = 34,

	DiskInner = 3.8,
	DiskOuter = 17,
	DiskTempInner = 4800,
	Brightness = 3.2,
	BrightnessFalloff = 1.6,
	DopplerBeaming = 1.5,
	DopplerColor = 0.5,
	Exposure = 1.0,
	RingGlow = 0.9,
	LoopSeconds = 90,
	InnerRevolutions = 10,

	Stars = 2200,
	StarsB = 700,

	AutoOrbit = 0.04,
	Bloom = 0.6,
}

Config.SqrtF = math.sqrt(1 - 2 / Config.D)
Config.RIn = math.max(Config.DiskInner, 3.2)
Config.ROut = Config.DiskOuter
Config.BCrit = 3 * math.sqrt(3)

return Config

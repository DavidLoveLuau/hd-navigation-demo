--!strict

const SharedPackages = game.ReplicatedStorage.Packages

const StarProfile = require(SharedPackages.StarProfile)

const profile =
	assert(StarProfile.Wait(15), "[StarProfileTest] Timed out waiting for the player profile")

assert(
	type(profile:Get "Settings.MusicVolume") == "number",
	"[StarProfileTest] Missing MusicVolume"
)
assert(
	type(profile:Get "Settings.MusicEnabled") == "boolean",
	"[StarProfileTest] Missing MusicEnabled"
)

const currentMusicVolume = profile:Get "Settings.MusicVolume"
const requestedMusicVolume = if currentMusicVolume == 10 then -1 else 11
const expectedMusicVolume = if currentMusicVolume == 10 then 0 else 10

profile:RequestSet("Settings.MusicVolume", requestedMusicVolume)
task.wait(0.2)
assert(
	profile:Get "Settings.MusicVolume" == expectedMusicVolume,
	"[StarProfileTest] MusicVolume was not normalized"
)

const currentMusicEnabled = profile:Get "Settings.MusicEnabled"
profile:RequestSet("Settings.MusicEnabled", not currentMusicEnabled)
task.wait(0.2)
assert(
	profile:Get "Settings.MusicEnabled" == not currentMusicEnabled,
	"[StarProfileTest] MusicEnabled was not saved"
)

print "[StarProfileTest][Client] PASS: profile loaded and client settings were server-validated"

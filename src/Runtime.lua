-- Single Roblox composition root. Core/Rules/RunSystems remain engine-independent.
-- Both entry points receive the same final catalog, research graph and pricing definitions.
local shared=script.Parent
local C=require(shared.Config)
if not C.economyReady then
 C.Tech=require(shared.Tech)
 C.Catalog=require(shared.Catalog)
 C.RunSystems=require(shared.RunSystems)
 C.ResearchWeb=require(shared.ResearchWeb)
 C.Economy=require(shared.Economy)
 C.Economy.configure(C)
end
return C

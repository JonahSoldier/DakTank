AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")
local math = math
local IsValid = IsValid
local pairs = pairs
local ipairs = ipairs
ENT.DakMaxHealth = 10
ENT.DakHealth = 10
ENT.DakArmor = 0
ENT.DakName = "Turret Control"
ENT.DakContraption = {}
ENT.DakTurretMotor = nil
ENT.SentError = 0
ENT.SentError2 = 0
ENT.DakCore = NULL
ENT.DakTurretMotors = {}
ENT.DakCrew = NULL
local function GetTurretParents(ent, Results)
	Results = Results or {}
	local Parent = ent:GetParent()
	Results[ent] = ent
	if IsValid(Parent) then GetTurretParents(Parent, Results) end
	return Results
end

local function GetTurretPhysCons(ent, Results)
	Results = Results or {}
	if not IsValid(ent) then return end
	if Results[ent] then return end
	Results[ent] = ent
	local Constraints = constraint.GetTable(ent)
	for _, v in ipairs(Constraints) do
		if (v.Type ~= "NoCollide") and (v.Type ~= "Axis") and (v.Type ~= "Ballsocket") and (v.Type ~= "AdvBallsocket") and (v.Type ~= "Rope") and (v.Type ~= "Wire") then
			for _, Ent in pairs(v.Entity) do
				GetTurretPhysCons(Ent.Entity, Results)
			end
		end
	end
	return Results
end

local function normalizedVector(vector)
	local len = (vector[1] * vector[1] + vector[2] * vector[2] + vector[3] * vector[3]) ^ 0.5
	if len > 0.0000001 then
		return Vector(vector[1] / len, vector[2] / len, vector[3] / len)
	else
		return Vector(0, 0, 0)
	end
end

local function angClamp(ang, clamp1, clamp2)
	return Angle(math.Clamp(ang.pitch, clamp1.pitch, clamp2.pitch), math.Clamp(ang.yaw, clamp1.yaw, clamp2.yaw), math.Clamp(ang.roll, clamp1.roll, clamp2.roll))
end

local function angNumClamp(ang, clamp1, clamp2)
	return Angle(math.Clamp(ang.pitch, clamp1, clamp2), math.Clamp(ang.yaw, clamp1, clamp2), math.Clamp(ang.roll, clamp1, clamp2))
end

function ENT:Initialize()
	self:SetModel("models/beer/wiremod/gate_e2_mini.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self.DakHealth = self.DakMaxHealth
	self.DakArmor = 10
	self.timer = CurTime()
	self.CoreRemoteMult = 1
	self.Inputs = Wire_CreateInputs(self, {"Active", "Gun [ENTITY]", "Turret [ENTITY]", "CamTrace [RANGER]", "Lock", "CamTrace2 [RANGER]", "Active2", "AirBurst"})
	self.ErrorTime = CurTime()
	self.ErrorTime2 = CurTime()
	self.SlowThinkTime = CurTime()
	self.SentError = 0
	self.SentError2 = 0
	self.LastHullAngles = self:GetAngles()
	self.DakBurnStacks = 0
	self.DakTurretMotors = {}
	self.Locked = 0
	self.Off = true
	self.OffTicks = 0
	self.Accel = 0
	self.ShortStop = self:GetShortStopStabilizer()
	self.FixedGun = self:GetFixedGun()
	self.Stabilizer = self:GetStabilizer()
	self.FCS = self:GetFCS()
end

local function GetParents(ent, Results)
	Results = Results or {}
	local Parent = ent:GetParent()
	Results[ent] = ent
	if IsValid(Parent) then GetParents(Parent, Results) end
	return Results
end

function ENT:Think()
	local RotMult = 0.1
	self.WiredGun = self.Inputs.Gun.Value
	self.WiredTurret = self.Inputs.Turret.Value
	if #self.DakContraption > 0 then
		local GunEnt = self.Inputs.Gun.Value
		if IsValid(GunEnt) and self.Controller.Off ~= true then
			GunEnt.TurretController = self
			if IsValid(GunEnt:GetParent()) and IsValid(GunEnt:GetParent():GetParent()) then self.DakGun = GunEnt:GetParent():GetParent() end
			local DakGun = self.DakGun
			if IsValid(DakGun) then
				local Elevation = math.Clamp(self:GetElevation(), 0, 90)
				local Depression = math.Clamp(self:GetDepression(), 0, 90)
				local YawMin = math.Clamp(self:GetYawMin(), 0, 360)
				local YawMax = math.Clamp(self:GetYawMax(), 0, 360)
				local RotationMult = math.Clamp(self:GetRotationSpeedMultiplier(), 0, 1)
				if self.FCS ~= true then
					if self:GetTable().Inputs.CamTrace.Path and self:GetTable().Inputs.CamTrace.Path[1].Entity:GetClass() ~= "gmod_wire_cameracontroller" then self.FCS = true end
					if self:GetTable().Inputs.CamTrace2.Path and self:GetTable().Inputs.CamTrace2.Path[1].Entity:GetClass() ~= "gmod_wire_cameracontroller" then self.FCS = true end
					if self.FCS == true then self.DakOwner:ChatPrint("Custom FCS E2 detected, gun handling multiplier affected.") end
					self.CustomFCS = true
				end

				self.DakActive = self.Inputs.Active.Value
				self.DakActive2 = self.Inputs.Active2.Value
				local DakTurret = self.Inputs.Turret.Value
				self.DakTurret = DakTurret
				local hash = {}
				local res = {}
				for _, v in ipairs(self.DakTurretMotors) do
					if not hash[v] then
						res[#res + 1] = v
						hash[v] = true
					end
				end

				self.DakTurretMotors = res
				if #self.DakTurretMotors > 0 then
					for i = 1, #self.DakTurretMotors do
						if IsValid(self.DakTurretMotors[i]) then RotMult = RotMult + self.DakTurretMotors[i].DakRotMult end
					end
				end

				if self.DakParented ~= 1 then
					if IsValid(GunEnt:GetParent()) then
						if IsValid(GunEnt:GetParent():GetParent()) then DakGun = GunEnt:GetParent():GetParent() end
						self.Turret = {}
						if IsValid(DakTurret) then
							table.Add(self.Turret, GetTurretParents(GunEnt))
							for _, v in pairs(GetTurretParents(GunEnt)) do
								table.Add(self.Turret, GetTurretPhysCons(v))
							end

							if IsValid(DakTurret) then
								table.Add(self.Turret, GetTurretParents(DakTurret))
								for _, v in pairs(GetTurretParents(DakTurret)) do
									table.Add(self.Turret, GetTurretPhysCons(v))
								end
							end

							for i = 1, #self.Turret do
								table.Add(self.Turret, self.Turret[i]:GetChildren())
								table.Add(self.Turret, self.Turret[i]:GetParent())
							end

							local Children = {}
							for i2 = 1, #self.Turret do
								if table.Count(self.Turret[i2]:GetChildren()) > 0 then table.Add(Children, self.Turret[i2]:GetChildren()) end
							end

							table.Add(self.Turret, Children)
						else
							table.Add(self.Turret, DakGun:GetChildren())
							for _, v in pairs(DakGun:GetChildren()) do
								table.Add(self.Turret, v:GetChildren())
							end
						end

						local hash = {}
						local res = {}
						for _, v in ipairs(self.Turret) do
							if not hash[v] then
								res[#res + 1] = v
								hash[v] = true
							end
						end

						self.Turret = res
						self.TurretBase = DakTurret
						DakGun.DakMovement = true
						self.TurretBase.DakMovement = true
						local Mass = 0
						self.Guns = {}
						for i = 1, #res do
							if res[i]:IsSolid() then
								if res[i]:GetClass() == "dak_tegun" or res[i]:GetClass() == "dak_teautogun" or res[i]:GetClass() == "dak_temachinegun" then
									Mass = Mass + res[i].DakMass
								else
									Mass = Mass + res[i]:GetPhysicsObject():GetMass()
								end
							end

							if res[i]:IsValid() then
								if res[i]:GetClass() == "dak_tegun" or res[i]:GetClass() == "dak_teautogun" or res[i]:GetClass() == "dak_temachinegun" then
									res[i].TurretController = self
									res[i].TurretBase = DakTurret
									self.Guns[#self.Guns + 1] = res[i]
								end
							end
						end

						self.GunMass = Mass
						self.DakParented = 1
						if IsValid(DakTurret) then self.YawDiff = DakTurret:GetAngles().yaw - DakGun:GetAngles().yaw end
					else
						self.DakParented = 0
					end
				end

				if IsValid(DakGun) then
					local BasePlate = self.Controller:GetParent():GetParent()
					if self.LastVel == nil then self.LastVel = 0 end
					if self.DakParented == 0 then
						if self.SentError == 0 then
							self.SentError = 1
							self.DakOwner:PrintMessage(HUD_PRINTTALK, "Turret Controller Error: Gun must be parented to an aimer prop.")
							self.ErrorTime = CurTime()
						else
							if CurTime() >= self.ErrorTime + 10 then
								self.DakOwner:PrintMessage(HUD_PRINTTALK, "Turret Controller Error: Gun must be parented to an aimer prop.")
								self.ErrorTime = CurTime()
							end
						end
					end

					local Class = GunEnt:GetClass()
					if Class ~= "dak_tegun" and Class ~= "dak_teautogun" and Class ~= "dak_temachinegun" then
						if self.SentError2 == 0 then
							self.SentError2 = 1
							self.DakOwner:PrintMessage(HUD_PRINTTALK, "Turret Controller Error: You must wire the gun input to the gun entity, not an aimer prop.")
							self.ErrorTime2 = CurTime()
						else
							if CurTime() >= self.ErrorTime2 + 10 then
								self.DakOwner:PrintMessage(HUD_PRINTTALK, "Turret Controller Error: You must wire the gun input to the gun entity, not an aimer prop.")
								self.ErrorTime2 = CurTime()
							end
						end
					end

					self.RotationSpeed = math.min(RotMult * (15000 / self.GunMass) * RotationMult, 5)
					--if self.Controller.ColdWar == 1 then
					--	self.RotationSpeed = self.RotationSpeed * 1.5
					--elseif self.Controller.Modern == 1 then
					--	self.RotationSpeed = self.RotationSpeed * 2
					--end
					local TimeScale = 66 / (1 / engine.TickInterval())
					if self.DakCrew == NULL then
						self.RotationSpeed = 0
						if self.GunnerErrorMessageSent1 == nil then
							self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " gunner not detected, gun unable to move. Please link a crew member to the turret controller.")
							self.GunnerErrorMessageSent1 = true
						end
					else
						if self.DakCrew.DakEntity ~= self then
							self.RotationSpeed = 0
						else
							self.DakCrew.Job = 1
							if self.DakCrew.DakDead == true or self.DakCrew.Busy == true then self.RotationSpeed = 0 end
							if not (self.Controller.ColdWar == 1 or self.Controller.Modern == 1) then
								--check for both gun itself and pivot point
								if self.RemoteWeapon == true then
									self.RotationSpeed = 0
									if self.FloatGunErrorMessageSent == nil then
										self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " Gun not within turret, remote weapon systems are cold war and modern only.")
										self.FloatGunErrorMessageSent = true
									end
								end

								if IsValid(self.TurretBase) and (math.Clamp(self:GetYawMin(), 0, 360) + math.Clamp(self:GetYawMax(), 0, 360) > 90) then
									if self.DakCrew:IsValid() then
										if self.DakCrew:GetParent():IsValid() then
											if self.DakCrew:GetParent():GetParent():IsValid() then
												if self.DakCrew:GetParent():GetParent() ~= self.TurretBase and self.DakCrew:GetParent():GetParent() ~= DakGun then
													self.RotationSpeed = 0
													if self.GunnerErrorMessageSent2 == nil then
														self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " gunner not in turret, remote weapon systems are cold war and modern only.")
														self.GunnerErrorMessageSent2 = true
													end
												end
											end
										end
									end
								end

								if not IsValid(self.TurretBase) and (math.Clamp(self:GetYawMin(), 0, 360) + math.Clamp(self:GetYawMax(), 0, 360) > 90) then
									if self.DakCrew:IsValid() then
										if self.DakCrew:GetParent():IsValid() then
											if self.DakCrew:GetParent():GetParent():IsValid() then
												if self.DakCrew:GetParent():GetParent() == self:GetParent():GetParent() or self.DakCrew:GetParent():GetParent() == DakGun then
													self.RotationSpeed = 0
													if self.GunnerErrorMessageSent3 == nil then
														self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " gunner not in hull, remote weapon systems are cold war and modern only.")
														self.GunnerErrorMessageSent3 = true
													end
												end
											end
										end
									end
								end
							else
								--check for both gun itself and pivot point
								if self.RemoteWeapon == true then
									self.RotationSpeed = self.RotationSpeed * self.CoreRemoteMult
									if self.nonWWIIRemoteGunErrorMessageSent == nil then
										self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " remote weapon system detected, 50% cost increase added to gun handling multiplier for this turret.")
										self.nonWWIIRemoteGunErrorMessageSent = true
										self.RemoteWeapon = true
									end
								end

								if IsValid(self.TurretBase) and (math.Clamp(self:GetYawMin(), 0, 360) + math.Clamp(self:GetYawMax(), 0, 360) > 90) then
									if self.DakCrew:IsValid() then
										if self.DakCrew:GetParent():IsValid() then
											if self.DakCrew:GetParent():GetParent():IsValid() then
												if self.DakCrew:GetParent():GetParent() ~= self.TurretBase and self.DakCrew:GetParent():GetParent() ~= DakGun then
													self.RotationSpeed = self.RotationSpeed * self.CoreRemoteMult
													if self.nonWWIIRemoteGunErrorMessageSent == nil then
														self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " remote weapon system detected, 50% cost increase added to gun handling multiplier for this turret.")
														self.nonWWIIRemoteGunErrorMessageSent = true
														self.RemoteWeapon = true
													end
												end
											end
										end
									end
								end

								if not IsValid(self.TurretBase) and (math.Clamp(self:GetYawMin(), 0, 360) + math.Clamp(self:GetYawMax(), 0, 360) > 90) then
									if self.DakCrew:IsValid() then
										if self.DakCrew:GetParent():IsValid() then
											if self.DakCrew:GetParent():GetParent():IsValid() then
												if self.DakCrew:GetParent():GetParent() == self:GetParent():GetParent() or self.DakCrew:GetParent():GetParent() == DakGun then
													self.RotationSpeed = self.RotationSpeed * self.CoreRemoteMult
													if self.nonWWIIRemoteGunErrorMessageSent == nil then
														self.DakOwner:ChatPrint(self.DakName .. " #" .. self:EntIndex() .. " remote weapon system detected, 50% cost increase added to gun handling multiplier for this turret.")
														self.nonWWIIRemoteGunErrorMessageSent = true
														self.RemoteWeapon = true
													end
												end
											end
										end
									end
								end
							end
						end
					end

					if self.DakActive > 0 then self.DakCamTrace = self.Inputs.CamTrace.Value end
					if self.DakActive2 > 0 then self.DakCamTrace = self.Inputs.CamTrace2.Value end
					if Class == "dak_tegun" or Class == "dak_teautogun" or Class == "dak_temachinegun" then
						if not self.Parented and self.FixedGun == false then
							timer.Simple(engine.TickInterval() * 1, function()
								constraint.RemoveAll(DakGun)
								if IsValid(DakTurret) then
									self.turretaimer = ents.Create("prop_physics")
									self.turretaimer:SetAngles(self:GetAngles())
									self.turretaimer:SetPos(DakTurret:GetPos())
									self.turretaimer:SetMoveType(MOVETYPE_NONE)
									self.turretaimer:PhysicsInit(SOLID_NONE)
									self.turretaimer:SetParent(self)
									self.turretaimer:SetModel("models/daktanks/smokelauncher100mm.mdl")
									self.turretaimer:DrawShadow(false)
									self.turretaimer:SetColor(Color(255, 255, 255, 0))
									self.turretaimer:SetRenderMode(RENDERMODE_TRANSCOLOR)
									self.turretaimer:Spawn()
									self.turretaimer:Activate()
									self.turretaimer:SetMoveType(MOVETYPE_NONE)
									self.turretaimer:PhysicsInit(SOLID_NONE)
									self.turretaimer.turretaimer = true
									DakTurret:SetParent()
									DakGun:SetParent()
									constraint.RemoveAll(DakTurret)
									constraint.AdvBallsocket(DakTurret, self.Controller:GetParent():GetParent(), 0, 0, Vector(0, 0, 0), Vector(0, 0, 0), 0, 0, -180, -180, -180, 180, 180, 180, 0, 0, 0, 1, 0)
									constraint.AdvBallsocket(DakGun, DakTurret, 0, 0, Vector(0, 0, 0), Vector(0, 0, 0), 0, 0, -180, -180, -180, 180, 180, 180, 0, 0, 0, 1, 0)
									constraint.AdvBallsocket(self.turretaimer, self.Controller:GetParent():GetParent(), 0, 0, Vector(0, 0, 0), Vector(0, 0, 0), 0, 0, -180, -180, -180, 180, 180, 180, 0, 0, 0, 1, 0)
									DakTurret:SetParent(self.turretaimer)
									DakGun:SetParent(self.turretaimer)
								else
									DakGun:SetParent()
									constraint.AdvBallsocket(DakGun, self.Controller:GetParent():GetParent(), 0, 0, Vector(0, 0, 0), Vector(0, 0, 0), 0, 0, -180, -180, -180, 180, 180, 180, 0, 0, 0, 1, 0)
									DakGun:SetParent(self:GetParent())
								end
							end)

							self.Parented = 1
						end

						if self.Parented == 1 then
							if self.DakActive > 0 or self.DakActive2 > 0 then
								if self.Inputs.Lock.Value > 0 then
									self.LastAngles = self:GetAngles()
									if self.LastPos == nil then self.LastPos = BasePlate:GetPos() end
									if IsValid(self.DakCore.Base) then if self.Locked == 0 then self.Locked = 1 end end
								else
									if self.Locked == 1 then self.Locked = 0 end
									if self.DakCamTrace then
										if self.FCS == true and not (self.CustomFCS == true) and not (GunEnt.DakShellAmmoType == "HEATFS" and GunEnt.DakShellPenetration == GunEnt.DakMaxHealth * 6.40) then --atgm has 6.40 maxhealth for pen and HEATFS ammo type
											local AirBurst = self.Inputs.AirBurst.Value
											local AddZ = 0
											if AirBurst ~= 0 then
												AddZ = self:GetAirburstHeight() * 39.3701
												for i = 1, #self.Guns do
													self.Guns[i].FuzeOverride = true
												end
											else
												for i = 1, #self.Guns do
													self.Guns[i].FuzeOverride = false
												end
											end

											local traceFCS = {}
											traceFCS.start = self.DakCamTrace.StartPos
											traceFCS.endpos = self.DakCamTrace.StartPos + self.DakCamTrace.Normal * 9999999999
											traceFCS.filter = self.DakContraption
											local PreCamTrace = util.TraceLine(traceFCS)
											if self.NoTarTicks == nil then self.NoTarTicks = 0 end
											local G = math.abs(physenv.GetGravity().z)
											local Caliber = GunEnt.DakMaxHealth
											local ShellType = GunEnt.DakShellAmmoType
											local V = GunEnt.DakShellVelocity * (GunEnt:GetPropellant() * 0.01)
											local ShellMass = GunEnt.DakShellMass
											local Drag = (((V * 0.0254) * (V * 0.0254)) * (math.pi * ((Caliber / 2000) * (Caliber / 2000)))) * 0.0245
											if ShellType == "HVAP" then Drag = (((V * 0.0254) * (V * 0.0254)) * (math.pi * (((Caliber * 0.5) / 1000) * ((Caliber * 0.5) / 1000)))) * 0.0245 end
											if ShellType == "APFSDS" then Drag = (((V * 0.0254) * (V * 0.0254)) * (math.pi * (((Caliber * 0.25) / 1000) * ((Caliber * 0.25) / 1000)))) * 0.085 end
											local VelLoss
											if ShellType == "HEAT" or ShellType == "HVAP" or ShellType == "ATGM" or ShellType == "HEATFS" or ShellType == "APFSDS" or ShellType == "APDS" then
												VelLoss = (Drag / (ShellMass * 8 / 2)) * 39.37
											else
												VelLoss = (Drag / (ShellMass / 2)) * 39.37
											end

											if PreCamTrace.Entity and not PreCamTrace.Entity:IsWorld() or self.Tar == nil then
												self.Tar = PreCamTrace.Entity
												self.CamTarPos = PreCamTrace.HitPos
											else
												self.NoTarTicks = self.NoTarTicks + 1
											end

											if self.NoTarTicks > 15 then
												self.Tar = PreCamTrace.Entity
												self.NoTarTicks = 0
											end

											local TarPos0
											local GunPos = GunEnt:GetPos()
											self.TarVel = Vector(0, 0, 0)
											if self.Tar and self.Tar:IsValid() then
												TarPos0 = self.Tar:GetPos() + (self.CamTarPos - self.Tar:GetPos()) + Vector(0, 0, AddZ)
												self.TarVel = self.Tar:GetVelocity()
											else
												TarPos0 = PreCamTrace.HitPos + Vector(0, 0, AddZ)
											end

											local basefound = false
											local base = self.Tar
											if IsValid(self.Tar) then
												while basefound == false do
													if IsValid(base:GetParent()) then
														base = base:GetParent()
													else
														basefound = true
													end
												end
											end

											if base ~= NULL and base:IsValid() then
												self.TarVel = base:GetVelocity()
											else
												self.TarVel = Vector(0, 0, 0)
											end

											local SelfVel = self.Controller:GetParent():GetParent():GetVelocity()
											local VelValue = V
											local VelLossFull = VelLoss
											local TravelTime = 0
											local Diff
											local X
											local Y
											local Disc
											local Ang
											local TarPos
											for i = 1, 2 do
												VelValue = V - VelLossFull
												TarPos = TarPos0 + ((self.TarVel - SelfVel) * (TravelTime + 0.1))
												Diff = TarPos - GunPos
												X = Vector(Diff.x, Diff.y, 0):Length()
												Y = Diff.z
												Disc = VelValue ^ 4 - G * (G * X * X + 2 * Y * VelValue * VelValue)
												Ang = math.atan(-(VelValue ^ 2 - math.sqrt(Disc)) / (G * X)) * 57.29577951
												TravelTime = X / (VelValue * math.cos(Ang * 0.017453293))
												VelLossFull = VelLoss * TravelTime
											end

											if AirBurst ~= 0 then
												for i = 1, #self.Guns do
													self.Guns[i].FuzeOverrideDelay = TravelTime
												end
											end

											--print(SelfVel)
											--print(TravelTime)
											if Ang ~= Ang then Ang = -45 end
											local yaw = Diff:Angle().yaw
											if yaw ~= yaw then yaw = (TarPos0 - GunPos):Angle().yaw end
											local traceFCS2 = {}
											traceFCS2.start = GunPos
											traceFCS2.endpos = GunPos + Angle(Ang, yaw, 0):Forward() * 100000000
											traceFCS2.filter = self.DakContraption
											self.CamTrace = util.TraceLine(traceFCS2)
										else
											local trace = {}
											trace.start = self.DakCamTrace.StartPos
											trace.endpos = self.DakCamTrace.StartPos + self.DakCamTrace.Normal * 9999999999
											trace.filter = self.DakContraption
											self.CamTrace = util.TraceLine(trace)
										end

										self.Shake = Angle(0, 0, 0)
										if self.Stabilizer == false then
											if self.LastPos == nil then self.LastPos = BasePlate:GetPos() end
											if self.LastAngles == nil then self.LastAngles = Angle(0, 0, 0) end
											local Speed = Vector(0, 0, 0):Distance(BasePlate:GetPos() - self.LastPos)
											if self.ShakeAmpX == nil then self.ShakeAmpX = 0 end
											self.ShakeAmpX = self.ShakeAmpX + math.random(-1, 1)
											if self.ShakeAmpX > 5 then self.ShakeAmpX = 5 end
											if self.ShakeAmpX < -5 then self.ShakeAmpX = -5 end
											if self.ShakeAmpX > 0 then self.ShakeAmpX = self.ShakeAmpX - 0.05 end
											if self.ShakeAmpX < 0 then self.ShakeAmpX = self.ShakeAmpX + 0.05 end
											if self.ShakeAmpY == nil then self.ShakeAmpY = 0 end
											self.ShakeAmpY = self.ShakeAmpY + math.random(-1, 1)
											if self.ShakeAmpY > 5 then self.ShakeAmpY = 5 end
											if self.ShakeAmpY < -5 then self.ShakeAmpY = -5 end
											if self.ShakeAmpY > 0 then self.ShakeAmpY = self.ShakeAmpY - 0.05 end
											if self.ShakeAmpY < 0 then self.ShakeAmpY = self.ShakeAmpY + 0.05 end
											local Shake
											if self.ShortStop == false then
												self.Accel = math.Clamp(self.Accel, -0.15, 0.15)
												Shake = (Angle(1 * self.ShakeAmpX, 0.1 * self.ShakeAmpY, 0) * (Speed * 0.025)) + Angle(-self.Accel * 25, 0, 0) --+(Angle(((self:GetAngles().pitch - self.LastAngles.pitch))*5,0,0))
											else
												Shake = Angle(1 * self.ShakeAmpX, 0.1 * self.ShakeAmpY, 0) * (Speed * 0.0125)
											end

											self.Shake = Shake
										end

										--local HullAngleMovement = -self:WorldToLocalAngles(self.LastAngles)
										self.LastAngles = self:GetAngles()
										--get angle that self has changed in last tick, infact this is done above in last angles
										local GunDir = normalizedVector(self.CamTrace.HitPos - self.CamTrace.StartPos + (self.CamTrace.StartPos - DakGun:GetPos()))
										if self:GetSetPitchOnLoading() and not (GunEnt.ShellLoaded == 1 or GunEnt.ShellLoaded2 == 1) then
											if IsValid(DakTurret) then
												GunDir = (self.turretaimer:GetAngles() + Angle(-self:GetLoadingAngle(), 0, 0)):Forward()
											else
												GunDir = (self:GetAngles() + Angle(-self:GetLoadingAngle(), 0, 0)):Forward()
											end
										end

										if self:GetQuadrantElevation() then
											local GunYaw = self:WorldToLocalAngles(DakGun:GetAngles()).yaw
											if GunYaw >= -45 and GunYaw <= 45 then
												--print("Forward")
												Elevation = math.Clamp(self:GetFrontElevation(), 0, 90)
												Depression = math.Clamp(self:GetFrontDepression(), 0, 90)
											elseif GunYaw < -45 and GunYaw > -135 then
												--print("Right")
												Elevation = math.Clamp(self:GetRightElevation(), 0, 90)
												Depression = math.Clamp(self:GetRightDepression(), 0, 90)
											elseif GunYaw > 45 and GunYaw < 135 then
												--print("Left")
												Elevation = math.Clamp(self:GetLeftElevation(), 0, 90)
												Depression = math.Clamp(self:GetLeftDepression(), 0, 90)
											else
												--print("Rear")
												Elevation = math.Clamp(self:GetRearElevation(), 0, 90)
												Depression = math.Clamp(self:GetRearDepression(), 0, 90)
											end
										end

										local Ang = angNumClamp(angClamp(self:WorldToLocalAngles(GunDir:Angle() + self.Shake), Angle(-Elevation, -YawMin, -1), Angle(Depression, YawMax, 1)) - self:WorldToLocalAngles(DakGun:GetAngles()), -self.RotationSpeed * TimeScale, self.RotationSpeed * TimeScale)
										if IsValid(DakTurret) then
											--turn both turret and gun
											local TurDir = normalizedVector(self.CamTrace.HitPos - self.CamTrace.StartPos + (self.CamTrace.StartPos - self.turretaimer:GetPos()))
											local TurClamp = self:LocalToWorldAngles(angClamp(self:WorldToLocalAngles(TurDir:Angle()), Angle(-Elevation, -YawMin, -1), Angle(Depression, YawMax, 1)))
											local TurAng = angNumClamp(self.turretaimer:WorldToLocalAngles(TurClamp), -self.RotationSpeed * TimeScale, self.RotationSpeed * TimeScale)
											if self.Off == true then
												self.OffTicks = self.OffTicks + 1
												if self.OffTicks > 70 then self.Off = false end
											else
												if self.Locked == 0 then
													self.turretaimer:SetAngles(self:LocalToWorldAngles(Angle(0, self:WorldToLocalAngles(self.turretaimer:GetAngles()).yaw, 0)) + Angle(0, TurAng.yaw, 0))
													local yawdiff = math.abs(self.turretaimer:WorldToLocalAngles(TurClamp).yaw)
													local pitch = Ang.pitch
													local Limit = 180
													local max = 0.5
													if self.Controller.Modern == 1 then
														Limit = 90
														max = 1
													elseif self.Controller.ColdWar == 1 then
														Limit = 45
														max = 0.5
													else
														Limit = 25
														max = 0.25
													end

													if yawdiff > Limit then
														pitch = 0
													else
														pitch = pitch * math.min((Limit - yawdiff) / Limit, max)
													end

													DakGun:SetAngles(self.turretaimer:LocalToWorldAngles(Angle(self:WorldToLocalAngles(DakGun:GetAngles()).pitch, 0, 0)) + Angle(pitch, 0, 0))
												end
											end
										else
											if self.Off == true then
												self.OffTicks = self.OffTicks + 1
												if self.OffTicks > 70 / (66 / (1 / engine.TickInterval())) then self.Off = false end
											else
												--turn gun
												DakGun:SetAngles(self:LocalToWorldAngles(Angle(self:WorldToLocalAngles(DakGun:GetAngles()).pitch, self:WorldToLocalAngles(DakGun:GetAngles()).yaw, 0)) + Angle(Ang.pitch, Ang.yaw, 0))
											end
										end
									end
								end
							else
								if self.Locked == 1 then self.Locked = 0 end
								--reposition to forward facing
								local GunDir = self:GetForward()
								local Ang = angNumClamp(angClamp(self:WorldToLocalAngles(GunDir:Angle() + Angle(-self:GetIdleElevation(), self:GetIdleYaw(), 0)), Angle(-Elevation, -YawMin, -1), Angle(Depression, YawMax, 1)) - self:WorldToLocalAngles(DakGun:GetAngles()), -self.RotationSpeed * TimeScale, self.RotationSpeed * TimeScale)
								if IsValid(DakTurret) and IsValid(self.turretaimer) then
									local TurDir = self:GetForward()
									local TurAng = angNumClamp(angClamp(self:WorldToLocalAngles(TurDir:Angle() + Angle(0, math.Clamp(self:GetIdleYaw(), -179.99, 179.99), 0)), Angle(-Elevation, -YawMin, -1), Angle(Depression, YawMax, 1)) - self:WorldToLocalAngles(self.turretaimer:GetAngles()), -self.RotationSpeed * TimeScale, self.RotationSpeed * TimeScale)
									self.turretaimer:SetAngles(self:LocalToWorldAngles(Angle(0, self:WorldToLocalAngles(self.turretaimer:GetAngles()).yaw, 0)) + Angle(0, TurAng.yaw, 0))
									DakGun:SetAngles(self.turretaimer:LocalToWorldAngles(Angle(self:WorldToLocalAngles(DakGun:GetAngles()).pitch, 0, 0)) + Angle(Ang.pitch, 0, 0))
								else
									DakGun:SetAngles(self:LocalToWorldAngles(Angle(self:WorldToLocalAngles(DakGun:GetAngles()).pitch, self:WorldToLocalAngles(DakGun:GetAngles()).yaw, 0)) + Angle(Ang.pitch, Ang.yaw, 0))
								end

								self.Off = true
								self.OffTicks = 0
								if self.LastPos == nil then self.LastPos = BasePlate:GetPos() end
								self.LastAngles = self:GetAngles()
							end
						end
					end

					if self.FixedGun == false then
						if self.SpeedTable == nil then self.SpeedTable = {} end
						if self.LastAccel == nil then self.LastAccel = 0 end
						self.SpeedTable[#self.SpeedTable + 1] = Vector(0, 0, 0):Distance(BasePlate:GetPos() - self.LastPos) - self.LastVel
						if #self.SpeedTable >= 5 then table.remove(self.SpeedTable, 1) end
						local totalspeed = 0
						for i = 1, #self.SpeedTable do
							totalspeed = totalspeed + self.SpeedTable[i]
						end

						self.Accel = totalspeed / #self.SpeedTable
						self.LastVel = Vector(0, 0, 0):Distance(BasePlate:GetPos() - self.LastPos)
						self.LastPos = BasePlate:GetPos()
					end
				end
			end
		end
	end

	self:NextThink(CurTime())
	return true
end

function ENT:PreEntityCopy()
	local info = {}
	-- local entids = {}
	info.TurretMotorIDs = {}
	if #self.DakTurretMotors > 0 then
		for i = 1, #self.DakTurretMotors do
			info.TurretMotorIDs[i] = self.DakTurretMotors[i]:EntIndex()
		end
	end

	info.CrewID = self.DakCrew:EntIndex()
	info.DakName = self.DakName
	info.DakHealth = self.DakHealth
	info.DakMaxHealth = self.DakMaxHealth
	info.DakMass = self.DakMass
	info.DakOwner = self.DakOwner
	duplicator.StoreEntityModifier(self, "DakTek", info)
	-- Wire dupe info
	self.BaseClass.PreEntityCopy(self)
end

function ENT:PostEntityPaste(Player, Ent, CreatedEntities)
	if Ent.EntityMods and Ent.EntityMods.DakTek then
		if Ent.EntityMods.DakTek.TurretMotorIDs then
			if #Ent.EntityMods.DakTek.TurretMotorIDs > 0 then
				for i = 1, #Ent.EntityMods.DakTek.TurretMotorIDs do
					self.DakTurretMotors[#self.DakTurretMotors + 1] = CreatedEntities[Ent.EntityMods.DakTek.TurretMotorIDs[i]]
				end
			end
		end

		local Crew = CreatedEntities[Ent.EntityMods.DakTek.CrewID]
		if Crew and IsValid(Crew) then self.DakCrew = Crew end
		self.DakArmor = 0
		self.DakName = Ent.EntityMods.DakTek.DakName
		self.DakMaxHealth = Ent.EntityMods.DakTek.DakMaxHealth
		if Ent.EntityMods.DakTek.DakMaxHealth == nil then self.DakMaxHealth = 10 end
		self.DakHealth = self.DakMaxHealth
		self.DakMass = Ent.EntityMods.DakTek.DakMass
		self.DakOwner = Player
		Ent.EntityMods.DakTek = nil
	end

	self.BaseClass.PostEntityPaste(self, Player, Ent, CreatedEntities)
end
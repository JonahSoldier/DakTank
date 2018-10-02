include("daktank_swepbase.lua")

if CLIENT then
 
	SWEP.PrintName = "IMI Galil"
	SWEP.Slot = 3
end

SWEP.Purpose	  = "Assault rifle with 13mm of penetration."
SWEP.Instructions = "Right click to zoom in.\nRecoil bonus while crouching and standing still."

SWEP.Spawnable = true
SWEP.AdminOnly = true

SWEP.ViewModel  = "models/weapons/cstrike/c_rif_galil.mdl"
SWEP.WorldModel = "models/weapons/w_rif_galil.mdl"

SWEP.Primary.ClipSize	 = 35
SWEP.Primary.DefaultClip = 350
SWEP.Primary.Automatic	 = true
SWEP.Primary.Ammo		 = "AR2"
SWEP.Primary.Cooldown	 = 0.08
SWEP.Primary.Caliber	 = 5.56
SWEP.Primary.Penetration = 13
SWEP.Primary.MuzzleVel	 = 40000
SWEP.Primary.RoundMass	 = 1
SWEP.Primary.Damage		 = 0.08
SWEP.Primary.Spread		 = 0.1
SWEP.Primary.AimFOV 	 = 50

SWEP.FireSound = "weapons/galil/galil-1.wav"

SWEP.HoldType = "ar2"
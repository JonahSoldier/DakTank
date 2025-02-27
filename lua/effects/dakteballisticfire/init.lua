function EFFECT:Init( data )
	local Pos = data:GetOrigin()
	local Ent = data:GetEntity()
	local size = data:GetScale()
	local EntVel = 0

	if not IsValid( Ent ) then return end

	EntVel = Ent:GetVelocity()
	if Ent:GetParent():IsValid() then
		EntVel = Ent:GetParent():GetVelocity()
		if Ent:GetParent():GetParent():IsValid() then
			EntVel = Ent:GetParent():GetParent():GetVelocity()
			if Ent:GetParent():GetParent():GetParent():IsValid() then
				EntVel = Ent:GetParent():GetParent():GetParent():GetVelocity()
			end
		end
	end

	local emitter = ParticleEmitter( Pos )

	if size > 7.5 then
		local pregroundtrace = {}
		pregroundtrace.start = Pos + 2 * ( Ent:GetPos() - Pos )
		pregroundtrace.endpos = Pos + 2 * ( Ent:GetPos() - Pos ) + Vector( 0, 0, -250 )
		pregroundtrace.mask = MASK_SOLID_BRUSHONLY

		local groundtrace = util.TraceLine( pregroundtrace )

		if groundtrace.Hit then
			for _ = 1, size * 3 do
				local ang = math.Rand( 0, 360 ) * math.pi / 180
				local particle = emitter:Add( "dak/smokey", groundtrace.HitPos + Vector( math.Rand( 0, size * 15 ) * math.cos( ang ), math.Rand( 0, size * 15 ) * math.sin( ang ), 0 ) )

				if particle == nil then
					particle = emitter:Add( "dak/smokey", groundtrace.HitPos + Vector( math.Rand( -size * 10, size * 10 ), math.Rand( -size * 10, size * 10 ), -25 ) )
				end

				if particle then
					local power = math.Rand( 0.75, 1.25 )
					particle:SetVelocity( Vector( 0, 0, size * 20 * power ) )
					particle:SetLifeTime( 0 )
					particle:SetDieTime( size * 0.1 )
					particle:SetStartAlpha( 150 )
					particle:SetEndAlpha( 0 )
					particle:SetStartSize( size * 0.5 * math.Rand( 0.5, 2 ) )
					particle:SetEndSize( size * 5 * math.Rand( 0.5, 2 ) )
					particle:SetAngles( Angle( 0, 0, 0 ) )
					particle:SetAngleVelocity( Angle( math.Rand( -0.5, 0.5 ), 0, 0 ) )
					particle:SetRoll( math.Rand( 0, 360 ) )
					particle:SetColor( math.random( 227, 227 ), math.random( 211, 211 ), math.random( 161, 161 ), math.random( 50, 50 ) )
					particle:SetGravity( Vector( 0, 0, 0 ) )
					particle:SetAirResistance( size * 100 * power )
					particle:SetCollide( false )
					particle:SetBounce( 0 )
				end
			end
		end
	end

	for _ = 1, size * 3 do
		local particle = emitter:Add( "dak/smokey", Pos )

		if particle == nil then
			particle = emitter:Add( "dak/smokey", Pos )
		end

		if particle then
			particle:SetVelocity( -Ent:GetRight() * 50 * size * math.Rand( 0.1, 1 ) + EntVel )
			particle:SetLifeTime( 0 )
			particle:SetDieTime( size / 50 + math.Rand( 0, 0.5 ) )
			particle:SetStartAlpha( 25 )
			particle:SetEndAlpha( 0 )
			particle:SetStartSize( 1 * size )
			particle:SetEndSize( 1 * size * 2 )
			particle:SetAngles( Angle( 0, 0, 0 ) )
			particle:SetAngleVelocity( Angle( 0, 0, 0 ) )
			particle:SetRoll( math.Rand( 0, 360 ) )
			particle:SetColor( math.random( 250, 250 ), math.random( 250, 250 ), math.random( 250, 250 ), math.random( 25, 25 ) )
			particle:SetGravity( VectorRand( -1, 1 ) * 20 * size )
			particle:SetAirResistance( 5 * size )
			particle:SetCollide( false )
			particle:SetBounce( 0 )
		end
	end

	for _ = 1, size * 1 do
		local particle = emitter:Add( "dak/smokey", Pos + -Ent:GetRight() * -size * 0.5 )

		if particle == nil then
			particle = emitter:Add( "dak/smokey", Pos )
		end

		if particle then
			particle:SetVelocity( Vector( 0, 0, 0 ) + EntVel )
			particle:SetLifeTime( 0 )
			particle:SetDieTime( size / 50 + math.Rand( 0, 0.5 ) )
			particle:SetStartAlpha( 25 )
			particle:SetEndAlpha( 0 )
			particle:SetStartSize( 0.15 * size )
			particle:SetEndSize( 0.15 * size * 2 )
			particle:SetAngles( Angle( 0, 0, 0 ) )
			particle:SetAngleVelocity( Angle( 0, 0, 0 ) )
			particle:SetRoll( math.Rand( 0, 360 ) )
			particle:SetColor( math.random( 250, 250 ), math.random( 250, 250 ), math.random( 250, 250 ), math.random( 25, 25 ) )
			particle:SetGravity( VectorRand( -1, 1 ) * 1 + -Ent:GetRight() * math.random( 10, 100 ) + Ent:GetUp() * -5 )
			particle:SetAirResistance( 0 )
			particle:SetCollide( false )
			particle:SetBounce( 0 )
		end
	end

	for _ = 1, size * 1 do
		local particle = emitter:Add( "effects/muzzleflash1.vtf", Pos + -Ent:GetRight() * math.random( -0, 0 ) )

		if particle == nil then
			particle = emitter:Add( "effects/muzzleflash1.vtf", Pos + -Ent:GetRight() * math.random( 0, 0 ) )
		end

		if particle then
			particle:SetVelocity( -Ent:GetRight() * math.Rand( 250, 3000 + size * 600 ) + Vector( math.random( -( 50 + size * 20 ), 50 + size * 20 ), math.random( -( 50 + size * 20 ), 50 + size * 20 ), math.random( -( 50 + size * 20 ), 50 + size * 20 ) ) + EntVel )
			particle:SetLifeTime( 0 )
			particle:SetDieTime( 0.1 + math.Rand( 0, 0.15 ) )
			particle:SetStartAlpha( 200 )
			particle:SetEndAlpha( 0 )
			particle:SetStartSize( size * 2.5 )
			particle:SetEndSize( 0 )
			particle:SetAngles( Angle( 0, 0, 0 ) )
			particle:SetAngleVelocity( Angle( 0, 0, 0 ) )
			particle:SetRoll( math.Rand( 0, 360 ) )
			particle:SetColor( 255, 255, 255, math.random( 150, 255 ) )
			particle:SetGravity( Vector( 0, 0, 0 ) )
			particle:SetAirResistance( 2500 )
			particle:SetCollide( false )
			particle:SetBounce( 0 )
		end
	end

	local Sparks = EffectData()
	Sparks:SetEntity( Ent )
	util.Effect( "AirboatMuzzleFlash", Sparks )

	emitter:Finish()
end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
function EFFECT:Init( data )
	local Pos = data:GetOrigin()
	local size = data:GetScale()
	local emitter = ParticleEmitter( Pos )
	local dustsize = data:GetScale()/5
	if dustsize > 0 then
		local pregroundtrace = {}
			pregroundtrace.start = Pos
			pregroundtrace.endpos = Pos + Vector(0,0,-25)
			pregroundtrace.mask = MASK_SOLID_BRUSHONLY
		local groundtrace = util.TraceLine(pregroundtrace)

		if groundtrace.Hit then
			for i = 1,math.Clamp(dustsize*2,2,1000) do

				local particle = emitter:Add( "dak/smokey", groundtrace.HitPos+Vector(math.Rand(-dustsize*10,dustsize*10),math.Rand(-dustsize*10,dustsize*10),-25))

				if particle == nil then particle = emitter:Add( "dak/smokey", groundtrace.HitPos+Vector(math.Rand(-dustsize*10,dustsize*10),math.Rand(-dustsize*10,dustsize*10),-25))  end

				if (particle) then
					particle:SetVelocity(Vector(0,0,math.Rand(5*75,5*125)))
					particle:SetLifeTime(0)
					particle:SetDieTime((dustsize/5)+math.Rand(0,5))
					particle:SetStartAlpha(50)
					particle:SetEndAlpha(0)
					particle:SetStartSize(15+dustsize*3)
					particle:SetEndSize((15+dustsize)*5)
					particle:SetAngles( Angle(0,0,0) )
					particle:SetAngleVelocity( Angle(0,0,0) )
					particle:SetRoll(math.Rand( 0, 360 ))
					particle:SetColor(math.random(227,227),math.random(211,211),math.random(161,161),math.random(50,50))
					particle:SetGravity( Vector(0,0,0) )
					particle:SetAirResistance(5*75)
					particle:SetCollide(false)
					particle:SetBounce(0)
				end
			end
		end
	end
	for i = 1,5*size do
		local particle = emitter:Add( "dak/smokey", Pos+Vector(math.random(-5,5),math.random(-5,5),math.random(-5,5)))
		if particle == nil then particle = emitter:Add( "dak/smokey", Pos) end
		if (particle) then
			particle:SetVelocity(Vector(math.random(-100*size,100*size),math.random(-100*size,100*size),math.random(-100*size,100*size)))
			particle:SetLifeTime(0)
			particle:SetDieTime(0.5)
			particle:SetStartAlpha(150)
			particle:SetEndAlpha(0)
			particle:SetStartSize(5+size)
			particle:SetEndSize(0)
			particle:SetAngles( Angle(0,0,0) )
			particle:SetAngleVelocity( Angle(0,0,0) )
			particle:SetRoll(math.Rand( 0, 360 ))
			local CVal = math.random(50,100)
			particle:SetColor(CVal,CVal,CVal,math.random(50,50))
			particle:SetGravity( Vector(0,0,math.random(5,10)) )
			particle:SetAirResistance(75*size)
			particle:SetCollide(false)
			particle:SetBounce(0)
		end
	end

	for i=1, 10*size do
		local Debris = emitter:Add( "effects/fleck_tile"..math.random(1,2), Pos )
		if (Debris) then
			Debris:SetVelocity (Vector(math.random(-250*size,250*size),math.random(-250*size,250*size),math.random(-250*size,250*size)))
			Debris:SetLifeTime( 0 )
			Debris:SetDieTime( math.Rand( 0.5 , 1.5 ) )
			Debris:SetStartAlpha( 255 )
			Debris:SetEndAlpha( 0 )
			Debris:SetStartSize( 1 )
			Debris:SetEndSize( 1 )
			Debris:SetRoll( math.Rand(0, 360) )
			Debris:SetRollDelta( math.Rand(-3, 3) )
			Debris:SetAirResistance( 20*size )
			Debris:SetGravity( Vector( 0, 0, math.Rand(-350, -150) ) )
			Debris:SetColor( 50,50,50 )
		end
	end

	local Sparks = EffectData()
	Sparks:SetOrigin( Pos )
	--Sparks:SetNormal( self.Normal )
	Sparks:SetMagnitude( 2+math.Rand(0,size/10) )
	Sparks:SetScale( math.Rand(1+size/10,2+size/10) )
	Sparks:SetRadius( math.Rand(2+size/10,3+size/10) )
	util.Effect( "Sparks", Sparks )
	emitter:Finish()

end

function EFFECT:Think()
	return false
end

function EFFECT:Render()
end
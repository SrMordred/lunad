print("main.lua loaded")


person = {
	name  = "Patric",
	last  = "Dexheimer",
	age   = 31,
	infos = {
		a = "info 1",
		b = "info 2"
	}
}

x = 10
print( "inc(x) = " .. inc(x) )

function inner(x,y)
	print("Inner")
	return x + y
end

function luaf(x, y)
	return inner
end
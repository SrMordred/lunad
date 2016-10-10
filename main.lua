print("main.lua loaded")


x = 10

function foo( a,b  )
	return a + b
end

function other()
	print("im other");
	return "STRINGGGG"
end
a = add(20,30);
print("value of a is: "..a)

a = mult(20,30);
print("value of a is: "..a)

a = div(20,30);
print("value of a is: "..a)
test = Test()

print ( "Test.x :" ..  test.x )
print ( "Test.y :" ..  test.y )



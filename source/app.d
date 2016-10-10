import std.stdio;

import derelict.lua.lua;

static this(){
	DerelictLua.load();
}

void LuaFunCall( Return = void , Args...)(lua_State* L, Args args ){
	import core.stdc.stdio : printf;
	foreach( arg ; args ){
		alias T = typeof(arg);
		static if( __traits(isIntegral, T) ){
			lua_pushinteger( L, arg );
		}else static if( __traits(isFloating, T) ){
			lua_pushnumber( L, arg );
		}
		else static if( is(T == string ) ){
			lua_pushstring( L, arg );
		}
	}
	if (lua_pcall(L, Args.length, 1, 0) != 0) {
        printf("Error running function f:%s`", lua_tostring(L, -1));
    }
}

auto LuaConvert(Type)(lua_State* L ){
	import std.string : fromStringz;
	import std.traits : TemplateOf;

	static if( __traits(isIntegral, Type) ){
		auto r = cast(Type)lua_tointeger(L, -1);
	}else static if( __traits(isFloating, Type) ){
		auto r = cast(Type)lua_tonumber(L, -1);
	}
	else static if( is(Type == string ) ){
		auto r = cast(Type)lua_tostring(L, -1).fromStringz;
	}
	else static if( is(Type == LuaFun ) ){
		auto r = LuaValue(L, luaL_ref(L, LUA_REGISTRYINDEX) );
	}
	else{
		auto r = null;
	}
	return r; 
}

struct LuaValue{
	lua_State* L;
	int lua_index;

	this( lua_State* l, int index ){
		L = l;
		lua_index = index;
	}

	auto as(T)(){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		auto r = L.LuaConvert!T;
		lua_pop(L, 1);
		return r;
	}

	auto fun(ReturnType = void, Args...)( Args args ){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		LuaFunCall!ReturnType(L, args);
		auto r = LuaConvert!ReturnType(L);
		lua_pop(L, 1);
		return r;
	}
}

alias LuaFun = LuaValue;

struct LunadObj{
	import std.string : toStringz, fromStringz;

	lua_State* L;
	this( lua_State* l){
		L = l;
		luaL_openlibs( L );
	}

	void doString( string code ){
		luaL_loadstring(L, code.toStringz);
  	    lua_pcall(L,0,0,0);
	}

	void doFile( string file ){
		if ( luaL_dofile( L, file.toStringz ) ){
			writeln( "Error loading file: \n", cast(string)lua_tostring(L, -1).fromStringz );
		}
	}
	auto get( T )( string value ){
		return L.getGlobalValue!T( value );
	}

	auto opIndex( string name ){
		lua_getglobal(L, name.toStringz);
		return LuaValue( L, luaL_ref(L, LUA_REGISTRYINDEX ) );
	}

	auto opIndexAssign( Fun )( Fun f, string name  ){
		import std.traits   : Parameters, ReturnType;

		writeln(Parameters!f);
	}
}

extern(C) auto multiply(lua_State* L) nothrow {
	import core.stdc.stdio : printf;
	import std.string : toStringz;

	try{

		auto args = lua_gettop (L);
		//try{
		//}catch(Exception e){
		//}
		auto a = cast(int)lua_tonumber(L,-1);
		auto b = cast(int)lua_tonumber(L,-2);


		//printf("%i * %i",a,b);

		lua_pushnumber(L, a * b);

		auto returns = 1;
		return returns;
	}
	catch(Exception e){}

	return 0;
}


auto Lunad(){
	return LunadObj( luaL_newstate() );
}

void LuaFunConvert(alias fun)(lua_State* L){
	extern(C) auto inner(lua_State* L) nothrow {
		import std.traits   : Parameters, ReturnType;
		import std.typecons : Tuple;
		import std.string   : toStringz,fromStringz;
		import core.stdc.stdio: printf;

		try{

			/*INPUT*/
			Tuple!(Parameters!fun) args;
			auto args_n = lua_gettop (L);
			foreach( i, Type ; Parameters!fun ){
				immutable int offset 	= cast(int)(-1 - i);
				immutable size_t index  = args.length - i - 1;
				static if( __traits(isIntegral, Type) ){
					args[index] = cast(Type)lua_tointeger(L,  offset );
				}else static if( __traits(isFloating, Type) ){
					args[index] = cast(Type)lua_tonumber(L, offset );
				}else static if( is(Type == string ) ){
					args[index] = cast(Type)lua_tostring(L, offset ).fromStringz;
				}
			}

			/*RETURN*/
			alias Return = ReturnType!fun;
			auto r = fun(args.expand);
			static if( __traits(isIntegral, Return) ){
				lua_pushinteger(L, r);
			}else static if( __traits(isFloating, Return) ){
				lua_pushnumber(L, r);
			}else static if( is(Return == string ) ){
				lua_pushstring(L, r.toStringz);
			}

		}catch(Exception e){ printf( e.msg.toStringz );}
		return 1;
	}

	lua_pushcfunction( L, &inner);
	lua_setglobal( L, __traits(identifier, fun) );
}


auto add(int x, int y){
	return x + y;
}

auto mult(float x, float y){
	return x * y;
}

auto div(float x, float y){
	return x / y;
}

auto concat(string x, string y){
	return x ~ y;
}

auto getStructMembers(Type)(){
	import std.typecons : Tuple;

	struct ReturnType{
		string 		name;
		string[] 	fields;
		string[] 	functions;
		string[] 	static_functions;
	}
	ReturnType data;
	data.name = __traits(identifier, Type);
	foreach(member ; __traits(allMembers, Type)){
	    auto isFunction = false;
	    foreach (t; __traits(getOverloads, Type, member)){
	    	isFunction = true;
		    static if (__traits(isStaticFunction, t)){
		    	data.static_functions~= member;
		    }else{
		    	data.functions~= member;
		    }
		}
		if(!isFunction){
			data.fields~=member;
		}
	}
	return data;
}


struct Test{
	int x =  100;
	float y;
	void add(int x_){
		//x+=x_ ;
	}
	auto get(){
		return 1;
	}
	static auto TypeName(){
		return "Test";
	}
}

extern(C) auto __index(lua_State* L) nothrow {
	import std.string : fromStringz, toStringz;
	try{
		auto args_n = lua_gettop (L);
		auto userdata = cast(Test*)lua_touserdata(L,-2);
		auto field    = cast(string)lua_tostring(L,-1).fromStringz;	
		if( field == "x" ){
			lua_pushinteger(L, userdata.x );
		}
	}catch(Exception e){ printf( e.msg.toStringz );}


	return 1;
}

extern(C) auto __newindex(lua_State* L) nothrow {

}


extern(C) auto __call(lua_State* L) nothrow {
	import std.string : fromStringz, toStringz;

	try{
		auto test = cast(Test *)lua_newuserdata(L, Test.sizeof);
		luaL_newmetatable(L, "__metaTest");

		lua_pushcfunction( L, &__index);
		lua_setfield(L, -2, "__index");

	  	lua_setmetatable(L, -2);
	}catch(Exception e){ printf( e.msg.toStringz );}


  	//lua_setglobal(L, "Test");
  	return 1;
}


void main(){
	import std.string : fromStringz, toStringz;
	auto lua = Lunad();

	//lua.doString( "print('OI')" );
	LuaFunConvert!add(lua.L);
	LuaFunConvert!mult(lua.L);
	LuaFunConvert!div(lua.L);
	LuaFunConvert!concat(lua.L);

	getStructMembers!Test.writeln;



	lua.doString( `
	__metastruct = {
		__index = function( _table, _field )
			print(_table, _field)
		end
	}` );

	lua_pushcfunction( lua.L, &__call);
	lua_setglobal( lua.L, "Test" );

	//LuaFunConvert!__call;

	//auto test = cast(Test *)lua_newuserdata(lua.L, Test.sizeof);
 // 	luaL_getmetatable(lua.L, "__metastruct");
 // 	lua_setmetatable(lua.L, -2);
 // 	lua_setglobal(lua.L, "Test");


	//lua_pushcfunction( lua.L, &multiply);
	//lua_setglobal( lua.L, "multiply" );

	lua.doFile("main.lua");
	auto f = lua["foo"];
	//f.fun!int( 10,20 ).writeln;
	import std.typecons : Tuple;


	//Parameters!x.writeln;






	//lua_Debug*ar;
	//lua_getglobal(lua.L , "foo");
	//auto f_index = luaL_ref(lua.L, LUA_REGISTRYINDEX);
	

 // 	auto r_index = luaL_ref(lua.L, LUA_REGISTRYINDEX);
	//lua_rawgeti(lua.L, LUA_REGISTRYINDEX, r_index);
 // 	lua_pcall(lua.L, 0, 1,0);



	//lua.get!(LuaFunction!(LuaFunction!void))("foo")()();
	//auto x = lua["foo"].fun();
	//x.writeln;
	//lua["foo"];
	//lua["foo"].fun();

	//lua.get!string("foo");





	//lua.getFun(  );

	//luaL_openlibs( L );

	//lua_pushcfunction( L, &multiply);
	//lua_setglobal( L, "multiply" );

	//luaL_dofile( L, "main.lua" );
}
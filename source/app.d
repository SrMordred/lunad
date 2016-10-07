import std.stdio;

import derelict.lua.lua;


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


		printf("%i * %i",a,b);

		lua_pushnumber(L, a * b);

		auto returns = 1;
		return returns;
	}
	catch(Exception e){}

	return 0;
}


static this(){
	DerelictLua.load();

}

auto getValue( T )( lua_State* L ){
	import std.string : fromStringz;

	static if( __traits(isIntegral, T) ){
		auto r = cast(T)lua_tointeger(L, -1);
	}else static if( __traits(isFloating, T) ){
		auto r = cast(T)lua_tonumber(L, -1);
	}
	else static if( is(T == string ) ){
		auto r = cast(T)lua_tostring(L, -1).fromStringz;
	}
	else static if( __traits(hasMember, T, "fun_index") ){
		assert(lua_isfunction(L, -1) );
		auto r = LuaFun!(T.ReturnType)(L, luaL_ref(L, LUA_REGISTRYINDEX) );
	}else{
		auto r = null;
	}
	
	return r;
}

auto getGlobalValue( T )( lua_State* L, string v ){
	import std.string : toStringz;
	lua_getglobal( L, v.toStringz );
	auto r = L.getValue!T;
	lua_pop(L, 1);
	return r;
}

struct LuaValue{
	lua_State* L;
	string name;
	auto as(Type)(){
		return L.getGlobalValue!Type( name );
	}

	auto fun(ReturnType = void)(){
		return L.getGlobalValue!(LuaFun!ReturnType)( name )();
	}
}

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
		return LuaValue( L, name );
	}
}

struct LuaFun(T = void){
	lua_State* L;
	int fun_index;
	alias ReturnType = T;

	this( lua_State* l, int index ){
		L = l;
		fun_index = index;
	}

	auto opCall(Args...)(Args args){
		import core.stdc.stdio : printf;
		lua_rawgeti(L, LUA_REGISTRYINDEX, fun_index);
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
	    return L.getValue!ReturnType();
	}
}

auto Lunad(){
	return LunadObj( luaL_newstate() );
}


 

void main(){
	import std.string : fromStringz, toStringz;

	auto lua = Lunad();

	//lua.doString( "print('OI')" );
	lua.doFile("main.lua");



	//lua_Debug*ar;
	//lua_getglobal(lua.L , "foo");
	//auto f_index = luaL_ref(lua.L, LUA_REGISTRYINDEX);
	

 // 	auto r_index = luaL_ref(lua.L, LUA_REGISTRYINDEX);
	//lua_rawgeti(lua.L, LUA_REGISTRYINDEX, r_index);
 // 	lua_pcall(lua.L, 0, 1,0);



	//lua.get!(LuaFunction!(LuaFunction!void))("foo")()();
	lua["foo"].fun();
	lua["foo"].fun();
	lua["foo"].fun();

	//lua.get!string("foo");





	//lua.getFun(  );

	//luaL_openlibs( L );

	//lua_pushcfunction( L, &multiply);
	//lua_setglobal( L, "multiply" );

	//luaL_dofile( L, "main.lua" );
}
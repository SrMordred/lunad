import std.stdio : writeln;
import std.string : toStringz, fromStringz;

import derelict.lua.lua;

static this(){
	DerelictLua.load();
}

auto LuaPushValue(Type)(lua_State* L, Type val){
	static if( __traits(isIntegral, Type) ){
		lua_pushinteger(L, val);
	}else static if( __traits(isFloating, Type) ){
		lua_pushnumber(L, val);
	}else static if( is(Type == string ) ){
		lua_pushstring(L, val.toStringz);
	}else static if( is(Type == LuaTable ) ){
		lua_newtable(L);
	}
}

void LuaCallFunction( Return = void , Args...)(lua_State* L, Args args ){
	import core.stdc.stdio : printf;
	foreach( arg ; args ){
		LuaPushValue(L, arg);
	}
	if (lua_pcall(L, Args.length, 1, 0) != 0) {
        printf("Error running function f:%s`", lua_tostring(L, -1));
    }
}

auto LuaConvert(Type)(lua_State* L ){
	import std.traits : TemplateOf;

	static if( __traits(isIntegral, Type) ){
		auto r = cast(Type)lua_tointeger(L, -1);
	}else static if( __traits(isFloating, Type) ){
		auto r = cast(Type)lua_tonumber(L, -1);
	}
	else static if( is(Type == string ) ){
		auto r = cast(Type)lua_tostring(L, -1).fromStringz;
	}
	else static if( is(Type == LuaObject ) ){
		auto r = LuaObject(L, luaL_ref(L, LUA_REGISTRYINDEX) );
	}
	else{
		auto r = null;
	}
	return r; 
}



//alias LuaFun = LuaValue;



extern(C) auto multiply(lua_State* L) nothrow {
	import core.stdc.stdio : printf;

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



void LuaPushFunction(Fun)(lua_State* L , Fun fun ){
	extern(C) auto inner(lua_State* L) nothrow {
		import std.traits   : Parameters, ReturnType;
		import std.typecons : Tuple;
		import core.stdc.stdio: printf;

		try{
			/*GET FUNCTION*/
			auto fun = cast(Fun) lua_touserdata(L,1);

			/*INPUT*/
			Tuple!(Parameters!Fun) args;
			auto args_n = lua_gettop (L);
			foreach( i, Type ; Parameters!Fun ){
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
			alias Return = ReturnType!Fun;
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
	lua_pushlightuserdata(L, fun);
	luaL_newmetatable(L, "__meta_fun");
	lua_pushcfunction(L, &inner);
	lua_setfield(L, -2, "__call");
  	lua_setmetatable(L, -2);
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

	void add2(T)(T t){}

}

string FieldGet( T , alias M )()  {
	enum Type = __traits(identifier, T);
	return "__traits(compiles, { "~Type~" t; auto v = t."~M~"; })";
}

string FieldSet( T , alias M )()  {
	enum Type = __traits(identifier, T);
	return "__traits(compiles, { "~Type~" t; t."~M~" = typeof( t."~M~" ).init ; })";
}

string FunctionCall( T , alias M )()  {
	enum Type = __traits(identifier, T);
	return "is ( typeof(__traits(getMember,"~Type~", \""~M~"\")) == function)";
}



struct LunadStruct{
	

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

	auto opIndex( string var ){
		lua_getglobal(L, var.toStringz);
		return LuaObject( L, luaL_ref(L, LUA_REGISTRYINDEX ) );
	}

	auto opIndexAssign( Type )(Type val, string var ){
		import std.traits : isSomeFunction;

		static if( isSomeFunction!Type ){
			LuaPushFunction(L, val);
		}else{
			LuaPushValue(L, val);
		}
		lua_setglobal(L, var.toStringz);
	}

	//auto register( Type )(){
	//	foreach( member ; __traits( allMembers, Test ) ){
	//		static if( mixin( FieldGet!(Test, member)) ) {
	//			writeln( "GETTER : ", member );
	//		}
	//		static if( mixin( FieldSet!(Test, member)) ) {
	//			writeln( "SETTER : ", member );
	//		}
	//		//writeln( is ( typeof(__traits(getMember,Test, member)) == function ));
	//		static if( mixin( FunctionCall!(Test, member)) ) {
	//			writeln( "IS FUNCTION : ", member );
	//		}

	//		static if(__traits(isTemplate, __traits(getMember, Test, member))){
	//			writeln( "IS template : ", member );	
	//		}
	//	}
	//}
}

void LuaDump(lua_State* L){
	import core.stdc.stdlib;
	int i;
	int top = lua_gettop(L);
	for (i = 1; i <= top; i++) {  /* repeat for each level */
        int t = lua_type(L, i);
        switch (t) {
			case LUA_TSTRING:  /* strings */
				printf("'%s'", lua_tostring(L, i));
			break;
			case LUA_TBOOLEAN:  /* booleans */
				printf(lua_toboolean(L, i) ? "true" : "false");
			break;
			case LUA_TNUMBER:  /* numbers */
				printf("%g", lua_tonumber(L, i));
			break;
			default:  /* other values */
				printf("%s", lua_typename(L, t));
			break;
        }
    	printf("  ");  /* put a separator */
    }
    printf("\n");  /* end the listing */
}

struct LuaObject{
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

	auto opIndex( string var ){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		if( lua_istable(L, -1) ){
			lua_pushstring(L, var.toStringz);
			lua_gettable(L, -2);
		}else{
			lua_getglobal(L, var.toStringz);
		}
		return LuaObject( L, luaL_ref(L, LUA_REGISTRYINDEX ) );
	}

	auto opIndexAssign( Type )(Type val, string var ){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		LuaPushValue(L, var);
		LuaPushValue(L, val);
		lua_settable(L, -3);
	}
}

struct LuaTable{

}

auto Lunad(){
	return LunadStruct( luaL_newstate() );
}

auto inc(int x){
	return x + 1;
}

void LuaPushFunction2(Fun)(lua_State* L , Fun fun ){

	extern(C) auto inner(lua_State* L) nothrow {
		import std.traits   : Parameters, ReturnType;
		import std.typecons : Tuple;
		import core.stdc.stdio: printf;

		try{
			/*GET FUNCTION*/
			//LuaDump(L);

			auto f = cast(Fun) lua_touserdata(L,1);
			//LuaDump(L);
			writeln(f(10));

			///*INPUT*/
			//Tuple!(Parameters!Fun) args;
			//auto args_n = lua_gettop (L);
			//foreach( i, Type ; Parameters!Fun ){
			//	immutable int offset 	= cast(int)(-1 - i);
			//	immutable size_t index  = args.length - i - 1;
			//	static if( __traits(isIntegral, Type) ){
			//		args[index] = cast(Type)lua_tointeger(L,  offset );
			//	}else static if( __traits(isFloating, Type) ){
			//		args[index] = cast(Type)lua_tonumber(L, offset );
			//	}else static if( is(Type == string ) ){
			//		args[index] = cast(Type)lua_tostring(L, offset ).fromStringz;
			//	}
			//}

			///*RETURN*/
			//alias Return = ReturnType!Fun;
			//auto r = fun(args.expand);
			//static if( __traits(isIntegral, Return) ){
			//	lua_pushinteger(L, r);
			//}else static if( __traits(isFloating, Return) ){
			//	lua_pushnumber(L, r);
			//}else static if( is(Return == string ) ){
			//	lua_pushstring(L, r.toStringz);
			//}

		}catch(Exception e){ printf( e.msg.toStringz );}
		return 1;
	}
	lua_pushlightuserdata(L, fun);
	luaL_newmetatable(L, "__meta_fun");
	lua_pushcfunction(L, &inner);
	lua_setfield(L, -2, "__call");
  	lua_setmetatable(L, -2);
}

struct Teste{
	lua_State* L;
	auto opIndexAssign( Type )(Type val, string var ){
		import std.traits : isSomeFunction;

		static if( isSomeFunction!Type ){
			LuaPushFunction2(L, val);
		}else{
			LuaPushValue(L, val);
		}
		lua_setglobal(L, var.toStringz);
	}
}

void main(){
	import std.traits;

	auto lua = Lunad();



	//lua["x"].as!int.writeln;

	//lua_pushinteger(lua.L, 100);
 //   lua_setglobal(lua.L, "y".toStringz );
	lua["y"] = 100;
	//
	//lua["y"].as!int.writeln;

	lua["info"] = LuaTable();
	lua["info"]["name"] = "Patric";
	lua["info"]["age"] = "31";
	lua["info"]["other"] = LuaTable();
	lua["info"]["other"]["value"] = 10;

	lua.doFile("main.lua");


	lua["person"]["name"].as!string.writeln;
	lua["person"]["last"].as!string.writeln;
	lua["person"]["age"].as!string.writeln;

	lua["person"]["infos"]["a"].as!string.writeln;
	lua["person"]["infos"]["b"].as!string.writeln;



	//lua["info"]["name"].as!string.writeln;
	//lua["info"]["age"].as!int.writeln;
	//lua["info"]["other"]["value"].as!int.writeln;

	lua["inc"] = &inc;
	lua.doFile("main.lua");


	//foreach( member ; __traits( allMembers, Test ) ){
	//	static if( mixin( FieldGet!(Test, member)) ) {
	//		writeln( "GETTER : ", member );
	//	}
	//	static if( mixin( FieldSet!(Test, member)) ) {
	//		writeln( "SETTER : ", member );
	//	}
	//	//writeln( is ( typeof(__traits(getMember,Test, member)) == function ));
	//	static if( mixin( FunctionCall!(Test, member)) ) {
	//		writeln( "IS FUNCTION : ", member );
	//	}

	//	static if(__traits(isTemplate, __traits(getMember, Test, member))){
	//		writeln( "IS template : ", member );	
	//	}
	//}
	



	//Test t; t.x = typeof( t.x ).init ;
	
	//LuaFunConvert!mult(lua.L);
	//LuaFunConvert!div(lua.L);
	//LuaFunConvert!concat(lua.L);

	//getStructMembers!Test.writeln;

	//lua.doString( `
	//__metastruct = {
	//	__index = function( _table, _field )
	//		print(_table, _field)
	//	end
	//}` );

	//lua_pushcfunction( lua.L, &__call);
	//lua_setglobal( lua.L, "Test" );

	//lua.doFile("main.lua");
	//auto f = lua["foo"];
}

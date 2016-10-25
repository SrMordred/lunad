import std.stdio : writeln;
import std.string : toStringz, fromStringz;

import derelict.lua.lua;

static this(){
	DerelictLua.load();
}

void LuaDump(lua_State* L){
	import core.stdc.stdio;
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

auto LuaGetValue(Type)(lua_State* L, int index = -1 ){
	import std.traits : TemplateOf;

	static if( __traits(isIntegral, Type) ){
		auto r = cast(Type)lua_tointeger(L, index);
	}else static if( __traits(isFloating, Type) ){
		auto r = cast(Type)lua_tonumber(L, index);
	}
	else static if( is(Type == string ) ){
		auto r = cast(Type)lua_tostring(L, index).fromStringz;
	}
	else static if( is(Type == LuaObject ) ){
		auto r = LuaObject(L, luaL_ref(L, LUA_REGISTRYINDEX) );
	}
	else{
		auto r = null;
	}
	return r; 
}

extern(C) auto inner(Fun, alias Name) (lua_State* L) nothrow {
		import std.traits   : Parameters, ReturnType;
		import std.typecons : Tuple;
		import core.stdc.stdio: printf;

		alias Args = Parameters!Fun;
		alias Return = ReturnType!Fun;

		try{
			/*GET FUNCTION*/
			auto fun = cast(Fun) lua_touserdata(L,lua_upvalueindex(1));

			/*INPUT*/
			Args args;
			foreach( index, Type ; Args )
				args[index] = LuaGetValue!Type(L, index + 1);

			/*RETURN*/
			static if( is(Return == void) ){
				fun(args);
				lua_pushnil(L);
			}else{
				LuaPushValue!Return(L, fun(args) );
			}

		}catch(Exception e){ printf( e.msg.toStringz );}
		return 1;
	}

void LuaPushFunction(Fun)(lua_State* L , Fun fun ){
	lua_pushlightuserdata(L, fun);
	lua_pushcclosure(L, &inner!(Fun, Fun.mangleof),1);
}



string FieldGet( T , alias M )()  {
	enum Type = __traits(identifier, T);
	return "__traits(compiles, { "~Type~" t; auto v = t."~M~"; })";
}

string FieldSet( T , alias M )()  {
	enum Type = __traits(identifier, T);
	return "__traits(compiles, { "~Type~" t; t."~M~" = typeof( t."~M~" ).init ; })";
}

//string FunctionCall( T , alias M )()  {
//	enum Type = __traits(identifier, T);
//	return "is ( typeof(__traits(getMember,"~Type~", \""~M~"\")) == function)";
//}



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

	/*REG FUNCTIONS*/

	auto regFunctions( alias Module )(){
		foreach( member ; __traits( allMembers, Module) ){
			static if( __traits( compiles , __traits( getMember, Module, member) ) ){
				static if( is( typeof(__traits( getMember, Module, member)) == function ) ){
					this[member] = &__traits( getMember, Module, member);
				}
			}
		}

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



struct LuaObject{
	lua_State* L;
	int lua_index;
	this( lua_State* l, int index ){
		L = l;
		lua_index = index;
	}
	auto as(T)(){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		auto r = L.LuaGetValue!T(-1);
		lua_pop(L, 1);
		return r;
	}

	//auto fun(ReturnType = void, Args...)( Args args ){
	//	lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
	//	LuaFunCall!ReturnType(L, args);
	//	auto r = LuaConvert!ReturnType(L);
	//	lua_pop(L, 1);
	//	return r;
	//}

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

	auto opCall( Args... )(Args args){
		lua_rawgeti(L, LUA_REGISTRYINDEX, lua_index);
		LuaCallFunction(L, args);
		return LuaObject( L, luaL_ref(L, LUA_REGISTRYINDEX ) );
		
	}
}

struct LuaTable{}

auto Lunad(){
	return LunadStruct( luaL_newstate() );
}

import funcs;

void main(){
	import std.traits;

	auto lua = Lunad();

	lua["x"] = 10;
	lua["x"].as!int.writeln;

	lua.regFunctions!funcs;
	
	lua.doFile("main.lua");


	//NEXT TODO
	//metatables is missing!! something like : 
	//lua["mt"] = LuaMetaTable();
	//lua.setmetatable("table", "mt"); or
	//lua["table"].setmetatable("mt");
	//lua.registerModule!main(int, float);
	//lua.registerStruct!Test(int, float);
	//lua.registerTemplate!template_func(int, float);



	//lua["info"]["name"].as!string.writeln;
	//lua["info"]["age"].as!int.writeln;
	//lua["info"]["other"]["value"].as!int.writeln;


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

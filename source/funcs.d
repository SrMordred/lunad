module funcs;


import std.stdio;

public: 

auto add( int x , int y){
	return x + y;
}

auto div( float x, float y ){
	return x / y;
}

void showme( string s ){
	writeln("Show me : ", s);
}


private:

void showme_private( string s ){
	writeln("Show me : ", s);
}
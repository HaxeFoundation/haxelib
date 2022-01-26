package website.cache;

import tink.CoreApi;
import ufront.core.Futuristic;
import ufront.cache.UFCache;

class DummyCacheConnection implements UFCacheConnection implements UFCacheConnectionSync {
	static var cache:DummyCache = new DummyCache();

	public function new() {};

	public function getNamespaceSync( namespace:String ):DummyCache
		return cache;

	public function getNamespace( namespace:String ):DummyCache
		return cache;
}

class DummyCache implements UFCache implements UFCacheSync {

	public function new() {};

	public function getSync( id:String ):Outcome<Dynamic,CacheError>
		return Failure( ENotInCache );

	public function setSync<T>( id:String, value:T ):Outcome<T,CacheError>
		return Success( value );

	public function getOrSetSync<T>( id:String, ?fn:Void->T ):Outcome<Dynamic,CacheError>
		return Success( fn() );

	public function removeSync( id:String ):Outcome<Noise,CacheError> {
		return Success(Noise);
	}

	public function clearSync():Outcome<Noise,CacheError> {
		return Success(Noise);
	}

	public function get( id:String ):Surprise<Dynamic,CacheError>
		return Future.sync( getSync(id) );

	public function set<T>( id:String, value:Futuristic<T> ):Surprise<T,CacheError>
		return value.map( function(v:T) return Success(v) );

	public function getOrSet<T>( id:String, ?fn:Void->Futuristic<T> ):Surprise<Dynamic,CacheError>
		return fn().map( function(v:T) return Success(v) );

	public function clear():Surprise<Noise,CacheError>
		return Future.sync( clearSync() );

	public function remove( id:String ):Surprise<Noise,CacheError>
		return Future.sync( removeSync(id) );
}
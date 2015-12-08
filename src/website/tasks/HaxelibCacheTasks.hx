package website.tasks;

import ufront.tasks.UFTaskSet;
import ufront.cache.DBCache;
import ufront.cache.RequestCacheMiddleware;
import website.api.ProjectApi;

class HaxelibCacheTasks extends UFTaskSet {
	@:skip @inject public var api:DBCacheApi;

	/** Set up the cache table. **/
	public function setup():Void api.setup();

	/** Clear every cached item. **/
	public function clearAll():Void api.clearAll();

	/** Clear all cached pages. **/
	public function clearPageCache() api.clearNamespace( RequestCacheMiddleware.namespace );

	/** Clear a projects zip file cache entries, and also the page caches for that project. **/
	public function clearZipCache( project:String, version:String ) {
		var namespaces = ProjectApi.cacheNames;
		var prefix = '$project:$version:%';
		api.clearItemLike( namespaces.info, prefix );
		api.clearItemLike( namespaces.dirListing, prefix );
		api.clearItemLike( namespaces.fileBytes, prefix );
		api.clearItemLike( RequestCacheMiddleware.namespace, '/p/$project/%' );
	}
}

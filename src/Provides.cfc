<cfcomponent output="false" mixin="controller">

	<cffunction name="init" access="public" output="false">
		<cfset this.version = "1.0" />
		<cfset application.provides = {} />
		<cfreturn this />
	</cffunction>
	
	<cffunction name="provides" access="public" output="false" returntype="void">
		<cfargument name="formats" required="true" type="string" />
		<cfscript>
			
			// make sure we have our application scope setup
			$checkSetApplicationScope();
			
			// append the passed in formats
			$setFormat(formats=arguments.formats);
		</cfscript>
		<cfreturn />
	</cffunction>
	
	<cffunction name="onlyProvides" access="public" output="false" returntype="void">
		<cfargument name="formats" required="true" type="string" />
		<cfargument name="action" type="string" default="#variables.params.action#" />
		<cfscript>
			// make sure we have our application scope setup
			$checkSetApplicationScope();
			
			// overwrite the formats for this action
			$setFormat(formats=arguments.formats, append=false, action=arguments.action);
		</cfscript>
	</cffunction>
	
	<cffunction name="display" access="public" output="false">
		<cfargument name="object" required="true" type="any" />
		<cfargument name="controller" required="false" type="string" default="#variables.params.controller#" />
		<cfargument name="action" required="false" type="string" default="#variables.params.action#" />
		<cfscript>
			var loc = {};
			
			loc.contentType = $requestContentType();
			
			if ((not StructKeyExists(application.provides, arguments.controller) or not StructKeyExists(application.provides[arguments.controller], "formats")) and application.wheels.environment != "production")
				$throw(type="wheels.provides.formatsNotDefined", 
						message="You are trying to use the display() method without first calling provides() or onlyProvides().",
						extendedInfo="Try calling provides() from within your controllers init() if you would like to use the display() method.");
			
			loc.acceptableFormats = application.provides[arguments.controller].formats;
			
			if (StructKeyExists(application.provides[arguments.controller], arguments.action))
				loc.acceptableFormats = application.provides[arguments.controller][arguments.action];
				
			if (not ListFindNoCase(loc.acceptableFormats, loc.contentType))
				loc.contentType = "";
			
			switch (loc.contentType) {

				case "xml": { 
					$header(name="content-type", value="text/xml",charset="utf-8"); 
					renderText($toXml(arguments.object)); 
					break; 
				}
				case "json": { 
					$header(name="content-type", value="text/json",charset="utf-8"); 
					renderText(SerializeJSON(arguments.object)); 
					break; 
				}
				case "html": { 
					loc.dump = StructDelete(arguments, "object"); 
					renderPage(argumentCollection=arguments); 
					break; 
				}
				default: { 
					$notAcceptable(); 
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="$requestContentType" access="public" output="false" returntype="string">
		<cfargument name="params" type="struct" default="#variables.params#" />
		<cfscript>
			var loc = {};
			
			// default to displaying html
			loc.format = "";
			loc.returnFormat = "";
			
			// see if we have a format param passed in
			if (StructKeyExists(arguments.params, "format"))
				loc.format = arguments.params.format;
				
			// the format argument overrides headers
			if (Len(loc.format))
				return loc.format;
			
			// check to see if we are requesting a particular format through the param or headers
			if (cgi.http_accept eq "text/xml") {
			
				loc.returnFormat = "xml";
				
			} else if (cgi.http_accept eq "text/json") {
			
				loc.returnFormat = "json";
			
			} else {
			
				loc.iEnd = ListLen(cgi.http_accept);
				for (loc.i = 1; loc.i lte loc.iEnd; loc.i++) {
				
					if (ListFindNoCase("text/html,application/xhtml+xml,*/*", Trim(ListGetAt(cgi.http_accept, loc.i)))) {
						loc.returnFormat = "html";
						break;
					}
				} 
			}
			
			return loc.returnFormat;
		</cfscript>
	</cffunction>
	
	<cffunction name="$toXml" access="public" output="false" returntype="string">
		<cfargument name="data" required="true" type="any" />
		<cfscript>
			var loc = {};
			
			loc.toXmlPath = [application.wheels.webPath, application.wheels.pluginPath, "provides", "toXml"];
			
			if (loc.toXmlPath[1] eq "/") {
				loc.dump = ArrayDeleteAt(loc.toXmlPath, 1);
			}
			
			loc.toXml = CreateObject("component", ArrayToList(loc.toXmlPath, "."));
			
			if (IsQuery(arguments.data)) {
			
				if (not StructKeyExists(arguments, "rootelement")) {
					arguments.rootelement = "query";
				}
			
				if (not StructKeyExists(arguments, "itemelement")) {
					arguments.itemelement = "row";
				}
			
				return loc.toXml.queryToXML(argumentCollection=arguments);
			} else if (IsStruct(arguments.data)) {
				if (not StructKeyExists(arguments, "rootelement")) {
					arguments.rootelement = "struct";
				}
			
				if (not StructKeyExists(arguments, "itemelement")) {
					arguments.itemelement = "item";
				}
			
				return loc.toXml.structToXML(argumentCollection=arguments);
			} else if (IsArray(arguments.data)) {
				if (not StructKeyExists(arguments, "rootelement")) {
					arguments.rootelement = "array";
				}
			
				if (not StructKeyExists(arguments, "itemelement")) {
					arguments.itemelement = "item";
				}
			
				return loc.toXml.arrayToXML(argumentCollection=arguments);
			}
			
			if (not StructKeyExists(arguments, "rootelement")) {
				arguments.rootelement = "list";
			}
		
			if (not StructKeyExists(arguments, "itemelement")) {
				arguments.itemelement = "item";
			}
			
			return loc.toXml.listToXML(argumentCollection=arguments);
		</cfscript>
	</cffunction>
	
	<cffunction name="$notAcceptable" access="public" output="false" returntype="void">
		<cfscript>
			$throw(type="Wheels.notAcceptable", message="The request type is not valid for this page.");
		</cfscript>
	</cffunction>
	
	<cffunction name="$setFormat" access="public" output="false" returntype="void">
		<cfargument name="formats" required="true" type="string" />
		<cfargument name="append" required="false" type="boolean" default="true" />
		<cfargument name="toAction" required="false" type="boolean" default="false" />
		<cfargument name="controller" required="false" type="string" default="#variables.wheels.name#" />
		<cfargument name="action" required="false" type="string" default="" />
		<cfset var loc = {} />
		<cflock name="provides" type="exclusive" timeout="5">
			<cfscript>
				loc.writeTo = "formats";
				
				if (Len(arguments.action))
					loc.writeTo = arguments.action;
				
				if (arguments.append and arguments.formats neq application.provides[arguments.controller][loc.writeTo])	
					application.provides[arguments.controller][loc.writeTo] = ListAppend(application.provides[arguments.controller][loc.writeTo], arguments.formats);
				else
					application.provides[arguments.controller][loc.writeTo] = arguments.formats;
			</cfscript>
		</cflock>
	</cffunction>
	
	<cffunction name="$checkSetApplicationScope" access="public" output="false" returntype="void">
		<cfargument name="controller" required="false" type="string" default="#variables.wheels.name#" />
		<cfargument name="action" required="false" type="string" default="" />
		<cfscript>
			if (not StructKeyExists(application, "provides"))
				application.provides = {};
				
			if (not StructKeyExists(application.provides, arguments.controller))
				application.provides[arguments.controller] = {};
			
			// default to html
			if (not StructKeyExists(application.provides[arguments.controller], "formats"))
				application.provides[arguments.controller].formats = "";	
				
			// always default the action to respond to html since we are on the web ;)
			if (Len(arguments.action) and not StructKeyExists(application.provides[arguments.controller], arguments.action))
				application.provides[arguments.controller][arguments.action] = "";	
		</cfscript>
	</cffunction>
	
</cfcomponent>

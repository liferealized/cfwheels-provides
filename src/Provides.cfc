<cfcomponent output="false" mixin="controller">

	<cffunction name="init" access="public" output="false" returntype="any">
		<cfscript>
			this.version = "1.1";
			application.provides = { directory = "provides", fileName = "provides", basePath = application.wheels.filePath };
		</cfscript>
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
	
	<cffunction name="renderWith" access="public" output="false">
		<cfargument name="object" required="true" type="any" />
		<cfargument name="controller" required="false" type="string" default="#variables.params.controller#" />
		<cfargument name="action" required="false" type="string" default="#variables.params.action#" />
		<cfscript>
			var loc = {};
			
			loc.contentType = $requestContentType();
			
			if ((not StructKeyExists(application.provides, arguments.controller) || !StructKeyExists(application.provides[arguments.controller], "formats")))
				$throw(type="wheels.provides.formatsNotDefined", 
					message="You are trying to use the renderWith() method without first calling provides() or onlyProvides().",
					extendedInfo="Try calling provides() from within your controllers init() if you would like to use the renderWith() method.");
			
			loc.acceptableFormats = application.provides[arguments.controller].formats;
			
			if (StructKeyExists(application.provides[arguments.controller], arguments.action))
				loc.acceptableFormats = application.provides[arguments.controller][arguments.action];
				
			if (not ListFindNoCase(loc.acceptableFormats, loc.contentType))
				loc.contentType = "";
				
			// try to render with a contentType template if one is provided for the action
			loc.templatePath = $generateIncludeTemplatePath($type="page", $name="#arguments.action#.#loc.contentType#", $template="#arguments.action#.#loc.contentType#");
			if (FileExists(ExpandPath(loc.templatePath)))
				loc.content = renderPage(template="#arguments.action#.#loc.contentType#", layout=false, returnAs="string");
			
			switch (loc.contentType)
			{
				case "xml":
				{
					$header(name="content-type", value="text/xml" , charset="utf-8");
					if (StructKeyExists(loc, "content"))
						renderText(loc.content);
					else
						renderText($toXml(arguments.object)); 
					break; 
				}
				case "json":
				{ 
					$header(name="content-type", value="text/json" , charset="utf-8");
					if (StructKeyExists(loc, "content"))
						renderText(loc.content);
					else
						renderText(SerializeJSON(arguments.object));
					break; 
				}
				case "csv":
				{
					if (StructKeyExists(loc, "content"))
						sendFile(file=$toCsv(data=loc.content));
					else
						sendFile(file=$toCsv(data=arguments.object));
					break; 
				}
				case "xls":
				{
					// xls rendering can only be done with a query at this time
					sendFile(file=$toSpreadsheet(data=arguments.object, type="xls"));
					break; 
				}
				case "pdf":
				{
					if (!StructKeyExists(loc, "content"))
						$throw(type="Wheels.Provides.templateMissing"
							, message="When rendering PDFs you must render your PDF html in the template #arguments.action#.pdf.cfm and the provides plugin with handle the rest.");
					
					sendFile(file=$toPdf(data=loc.content), disposition="inline");
					break; 
				}
				case "html":
				{ 
					StructDelete(arguments, "object"); 
					renderPage(argumentCollection=arguments); 
					break; 
				}
				default:
				{ 
					$notAcceptable(); 
				}
			}
		</cfscript>
	</cffunction>
	
	<cffunction name="$toPdf" access="public" output="false" returntype="string">
		<cfargument name="data" type="query" required="true" />
		<cfargument name="contentType" required="false" type="string" default="pdf" />
	</cffunction>
	
	<cffunction name="$toSpreadsheet" access="public" output="false" returntype="string">
		<cfargument name="data" required="true" type="query" />
		<cfargument name="contentType" required="false" type="string" default="xls" />
		<cfscript>
			arguments = $createPathInfo(argumentCollection=arguments);
			if (!DirectoryExists(arguments.expandedDirectory))
				$directory(action="create", directory=arguments.expandedDirectory);
			$spreadsheet(action="write", fileName=arguments.expandedPath, overwrite=true, query=arguments.data);
		</cfscript>
		<cfreturn arguments.path />
	</cffunction>
	
	<cffunction name="$toCsv" access="public" output="false" returntype="string">
		<cfargument name="data" required="true" type="any" />
		<cfargument name="contentType" required="false" type="string" default="csv" />
		<cfscript>
			arguments = $createPathInfo(argumentCollection=arguments);
			if (IsQuery(arguments.data))
			{
				loc.xlsPath = Replace(arguments.expandedPath, ".csv", ".xls", "all");
				if (!DirectoryExists(arguments.expandedDirectory))
					$directory(action="create", directory=arguments.expandedDirectory);
				$spreadsheet(action="write", fileName=loc.xlsPath, overwrite=true, query=arguments.data);
				arguments.data = $spreadsheet(action="read", src=loc.xlsPath, format=arguments.contentType);
			}
			$file(action="write", file=arguments.expandedPath, output=arguments.data);
		</cfscript>
		<cfreturn arguments.path />
	</cffunction>
	
	<cffunction name="$toXml" access="public" output="false" returntype="string">
		<cfargument name="data" required="true" type="any" />
		<cfscript>
			var loc = {};
			
			loc.toXmlPath = [application.wheels.webPath, application.wheels.pluginPath, "provides", "toXml"];
			
			if (loc.toXmlPath[1] eq "/")
				loc.dump = ArrayDeleteAt(loc.toXmlPath, 1);
			
			loc.toXml = CreateObject("component", ArrayToList(loc.toXmlPath, "."));
			
			if (IsQuery(arguments.data))
			{
				if (not StructKeyExists(arguments, "rootelement"))
					arguments.rootelement = "query";
				
				if (not StructKeyExists(arguments, "itemelement"))
					arguments.itemelement = "row";
			
				return loc.toXml.queryToXML(argumentCollection=arguments);	
			}
			else if (IsObject(arguments.data))
			{
				loc.model = Duplicate(arguments.data);
				arguments.data = arguments.data.properties();
			
				if (not StructKeyExists(arguments, "rootelement"))
					arguments.rootelement = loc.model.$classData().name;
			
				if (not StructKeyExists(arguments, "itemelement"))
					arguments.itemelement = "properties";
			
				return loc.toXml.structToXML(argumentCollection=arguments);
			}
			else if (IsStruct(arguments.data))
			{
				if (not StructKeyExists(arguments, "rootelement"))
					arguments.rootelement = "struct";
			
				if (not StructKeyExists(arguments, "itemelement"))
					arguments.itemelement = "item";
			
				return loc.toXml.structToXML(argumentCollection=arguments);
				
			}
			else if (IsArray(arguments.data))
			{
				if (not StructKeyExists(arguments, "rootelement"))
					arguments.rootelement = "array";
			
				if (not StructKeyExists(arguments, "itemelement"))
					arguments.itemelement = "item";
			
				return loc.toXml.arrayToXML(argumentCollection=arguments);
			}
			
			if (not StructKeyExists(arguments, "rootelement"))
				arguments.rootelement = "list";
		
			if (not StructKeyExists(arguments, "itemelement"))
				arguments.itemelement = "item";				
		</cfscript>
		<cfreturn loc.toXml.listToXML(argumentCollection=arguments) />
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
			if (cgi.http_accept eq "text/xml")
			{
				loc.returnFormat = "xml";	
			}
			else if (cgi.http_accept eq "text/json")
			{
				loc.returnFormat = "json";
			}
			else if (cgi.http_accept eq "text/csv")
			{
				loc.returnFormat = "csv";
			}
			else if (cgi.http_accept eq "application/vnd.ms-excel")
			{
				loc.returnFormat = "xls";
			}
			else if (cgi.http_accept eq "application/pdf")
			{
				loc.returnFormat = "pdf";
			}
			else
			{
				for (loc.i = 1; loc.i lte ListLen(cgi.http_accept); loc.i++)
				{
					if (ListFindNoCase("text/html,application/xhtml+xml,*/*", Trim(ListGetAt(cgi.http_accept, loc.i))))
					{
						loc.returnFormat = "html";
						break;
					}
				} 
			}
		</cfscript>
		<cfreturn loc.returnFormat />
	</cffunction>
	
	<cffunction name="$notAcceptable" access="public" output="false" returntype="void">
		<cfset $throw(type="Wheels.notAcceptable", message="The request type is not valid for this page.") />
	</cffunction>
	
	<cffunction name="$createPathInfo" access="public" output="false" returntype="struct">
		<cfargument name="directory" required="false" type="string" default="#application.provides.directory#" />
		<cfargument name="fileName" required="false" type="string" default="#application.provides.fileName#" />
		<cfargument name="basePath" required="false" type="string" default="#application.provides.basePath#" />
		<cfargument name="path" required="false" type="string" default="#arguments.directory#/#arguments.fileName#.#arguments.contentType#" />
		<cfargument name="expandedPath" required="false" type="string" default="#ExpandPath('#arguments.basePath#/#arguments.path#')#" />
		<cfargument name="expandedDirectory" required="false" type="string" default="#ExpandPath('#arguments.basePath#/#arguments.directory#')#" />
		<cfreturn arguments />
	</cffunction>
	
	<cffunction name="$setFormat" access="public" output="false" returntype="void">
		<cfargument name="formats" required="true" type="string" />
		<cfargument name="append" required="false" type="boolean" default="true" />
		<cfargument name="toAction" required="false" type="boolean" default="false" />
		<cfargument name="controller" required="false" type="string" default="#variables.$class.name#" />
		<cfargument name="action" required="false" type="string" default="" />
		<cfset var loc = {} />
		<cflock name="provides" type="exclusive" timeout="5">
			<cfscript>
				loc.writeTo = "formats";
				
				if (Len(arguments.action))
					loc.writeTo = arguments.action;
				
				if (arguments.append && arguments.formats != application.provides[arguments.controller][loc.writeTo])	
					application.provides[arguments.controller][loc.writeTo] = ListAppend(application.provides[arguments.controller][loc.writeTo], arguments.formats);
				else
					application.provides[arguments.controller][loc.writeTo] = arguments.formats;
			</cfscript>
		</cflock>
		<cfreturn />
	</cffunction>
	
	<cffunction name="$checkSetApplicationScope" access="public" output="false" returntype="void">
		<cfargument name="controller" required="false" type="string" default="#variables.$class.name#" />
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
			if (Len(arguments.action) && !StructKeyExists(application.provides[arguments.controller], arguments.action))
				application.provides[arguments.controller][arguments.action] = "";	
		</cfscript>
		<cfreturn />
	</cffunction>
	
	<cffunction name="$spreadsheet" access="public" output="false" returntype="any">
		<cfset var loc = {} />
		<cfif arguments.action eq "read">
			<cfset arguments.name = "loc.returnValue" />
		</cfif>
		<cfif StructKeyExists(arguments, "query")>
			<cfset arguments.data = arguments.query />
			<cfset arguments.query = "arguments.data" />
		</cfif>
		<cfspreadsheet attributeCollection="#arguments#" />
		<cfif StructKeyExists(loc, "returnValue")>
			<cfreturn loc.returnValue />
		</cfif>
	</cffunction>
	
</cfcomponent>

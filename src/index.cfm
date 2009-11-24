<h1>Provides Plugin</h1>
<p>The Provides Plugin lets you manage the data format returned by your Wheels controller.</p>
<p>Currently, three format options are supported -- HTML, XML, or JSON. Unless one of the other formats is specified, HTML is returned as the default.</p>
<p>So, how does the plugin know which format to return? Two options are available:</p>
<ul>
	<li>Examining a URL or FORM parameter named "format." For example, ?format=xml will return XML and ?format=json will return JSON.</li>
	<li>Examining the HTTP header. The plugin looks at cgi.http_accept in the request header and returns XML (text/xml) or JSON (text/json) as appropriate.</li>
</ul>

<h2>Basic Usage</h2>
<p>Add a call to the provides() function in the init() method of your controller to specify which formats your controller can return.</p>
<blockquote><p>&lt;cfset provides(formats="html,xml,json")&gt;</p></blockquote>
<p>Add a call to the renderWith() function at the bottom of any action that you want to return XML or JSON.</p>
<blockquote><p>&lt;cfset renderWith(yourModelObject)&gt;</p></blockquote>

<h2>Methods</h2>
<ul>
<li><strong>provides(formats="html,xml,json")</strong>  - use this method in your controller init() and pass in the types your would like to controller to respond to.</li>
<li><strong>onlyProvides(formats="html")</strong> - use this method in an action to say that it only provide particular formats. A good example would be for a new() action where a form is displayed. In this case, there is no data to show, so the action should only provide html.</li>
<li><strong>renderWith(object=dataToDisplay)</strong> - Call renderWith() at the bottom of every action that you want to respond to different formats. The argument object should be passed the data to transform to XML or JSON if that format is requested. Please note that you can also pass display any arguments for renderPage() and they will be passed through appropriately.</li>
</ul>
<p>The renderWith() method should be able to take lists (strings), arrays, structures, arrays of structures, queries and arrays of wheels model objects and properly display them as XML or JSON. If the request type is set to HTML, the data is ignored and renderPage() is called.</p>

<h2>Uninstallation</h2>
<p>To uninstall this plugin simply delete the <tt>/plugins/Provides-0.1.zip</tt> file.</p>

<h2>Credits</h2>
<p>This plugin was created by <a href="http://iamjamesgibson.com">James Gibson</a> and <a href="http://resultantsys.com">Clarke Bishop</a>.</p>

<p><a href="<cfoutput>#cgi.http_referer#</cfoutput>">&lt;&lt;&lt; Go Back</a></p>
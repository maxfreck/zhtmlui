function SapGuiLogger() {
	var me = this;
	var style = document.createElement("style");
	style.innerHTML =
"\
.sapLogger {\
	display: block;\
	position: fixed;\
	left: 0; right: 0;\
	bottom: 0; top: 60%;\
	background: #fafafa;\
	box-shadow: 0 0 8px #777;\
	font-size: 10pt;\
}\
.sapLogger.-hidden {\
	visibility: hidden;\
}\
.sapLogger>.controls {\
	margin:0;\
	padding:0;\
	text-align: right;\
}\
.sapLogger>.controls>.btn {\
	display: inline-block;\
	padding:0;\
	margin: 0;\
	background: transparent;\
	border-radius: 0;\
	width: 2em;\
}\
.sapLogger>.log {\
	position: absolute;\
	left:0; top: 2em;\
	right:0; bottom:0;\
	overflow: auto;\
	border-top: #aaa 1px solid;\
}\
.sapLogger>.log>.item {\
	margin: 0;\
	padding: .1em .5em;\
	color: #000;\
	background: #e2e3e5;\
	border-bottom: #aaa 1px solid;\
	font-family: monospace;\
}\
.sapLogger>.log>.item.-error{\
	background: #f8d7da;\
}\
.sapLogger>.log>.item.-warning{\
	background: #fff3cd;\
}\
.sapLogger>.log>.item.-info{\
	background: #cce5ff;\
}\
.sapLogger>.log>.item.-success{\
	background: #d4edda;\
}\
.sapLogger>.log>.item>.timestamp,\
.sapLogger>.log>.item>.text {\
	display: inline-block;\
}\
.sapLogger>.log>.item>.timestamp{\
	color: #999;\
	width: 6em;\
	text-align: center;\
}\
";
	var controls = document.createElement("div");
	controls.classList.add("controls");

	var clear = document.createElement("button");
	clear.textContent = "⌧";
	clear.title = "Clear console";
	clear.classList.add("btn");
	clear.classList.add("-clear");
	clear.onclick = function(){me.clear()}
	controls.appendChild(clear);

	var close = document.createElement("button");
	close.textContent = "✖";
	close.title = "Close console";
	close.classList.add("btn");
	close.classList.add("-close");
	close.onclick = function(){me.hide()}
	controls.appendChild(close);


	me.logarea = document.createElement("div");
	me.logarea.classList.add("log");
	me.logarea.innerHTML = '';

	me.container = document.createElement("div");
	me.container.classList.add("sapLogger");

	me.container.appendChild(controls);
	me.container.appendChild(this.logarea);
	me.container.classList.add("-hidden");
	me.hidden = true;

	if (!document.body) {
		document.addEventListener("DOMContentLoaded", function(event) {
			document.getElementsByTagName('head')[0].appendChild(style);
			document.body.appendChild(me.container);
		});
	} else {
		document.getElementsByTagName('head')[0].appendChild(style);
		document.body.appendChild(me.container);
	}

	this.labels = {"default": 0};

	//private methods
	this.timestamp = function() {
		return window.performance && window.performance.now && window.performance.timing && window.performance.timing.navigationStart ? window.performance.now() + window.performance.timing.navigationStart : Date.now();
	}

	this.time = function() {
		var d = new Date;
		return ('0'+d.getHours()).slice(-2)+":"+('0'+d.getMinutes()).slice(-2)+":"+('0'+d.getSeconds()).slice(-2);
	}

	this.write = function(level, text) {
		this.logarea.innerHTML+= '<pre class="item -'+level+'" data-timestamp="'+this.timestamp()+'"><span class="timestamp">'+this.time()+'</span><span class="text">'+text+'</span></pre>';
	}
}

SapGuiLogger.prototype.clear = function() {
	this.logarea.innerHTML="";
}

SapGuiLogger.prototype.count = function(label) {
	var label = (typeof(label) === 'undefined') ? 'default' : label.toString(); 
	if (this.labels[label]) this.labels[label]++; else this.labels[label] = 1;
	this.log(label+": "+this.labels[label]);
}

SapGuiLogger.prototype.log = function() {
	var txt = "";
	for (n = 0; n < arguments.length; n++) {
		txt+= arguments[n];
		txt+= " ";
	}
	this.write("default", txt);
}

SapGuiLogger.prototype.error = function() {
	var txt = "";
	for (n = 0; n < arguments.length; n++) {
		txt+= arguments[n];
		txt+= " ";
	}
	this.write("error", txt);
}

SapGuiLogger.prototype.warn = function() {
	var txt = "";
	for (n = 0; n < arguments.length; n++) {
		txt+= arguments[n];
		txt+= " ";
	}
	this.write("warning", txt);
}

SapGuiLogger.prototype.info = function() {
	var txt = "";
	for (n = 0; n < arguments.length; n++) {
		txt+= arguments[n];
		txt+= " ";
	}
	this.write("info", txt);
}

SapGuiLogger.prototype.success = function() {
	var txt = "";
	for (n = 0; n < arguments.length; n++) {
		txt+= arguments[n];
		txt+= " ";
	}
	this.write("success", txt);
}

SapGuiLogger.prototype.hide = function() {
	this.hidden = true;
	this.container.classList.add("-hidden");
}

SapGuiLogger.prototype.show = function() {
	this.hidden = false;
	this.container.classList.remove("-hidden");
}

SapGuiLogger.prototype.toggle = function() {
	if (this.hidden) {
		this.show();
	} else {
		this.hide();
	}
}

window.console = new SapGuiLogger();

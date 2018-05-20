/**
 * Split a string into chunks of the given size
 * @param  {Number} size is the size you of the cuts
 * @return {Array} an Array with the strings
 */
String.prototype.byChunk = function(size) {
	var re = new RegExp('.{1,' + size + '}', 'g');
	return this.match(re);
}

function SapGui() {
	var me = this;
	me.requests = {};
	me.requestId = 0;

	me.texts = {"foo": "bar"};

	me.getParams = function(params) {
		if (!params) return "";

		var ret = "";
		for (var key in params) {
			ret+= (ret) ? "&" : "?";
			ret+= key+"="+params[key];
		}
		return ret;
	}
}

SapGui.prototype.translatePage = function() {try{
	var me = this;
	me.get('translations.json',{
		fail: function(e) {console.error("Failed to load translations.json with error:", e)},
		success: function(ret) {
			if (ret === "") {
				console.warn("translations.json is empty.");
				return;
			}
			try {
				me.texts = JSON.parse(ret);
				me.applyTranslation();
			} catch (e) {
				console.error(e);
			}
		}
	});
}catch(e){console.error(e)}}


SapGui.prototype.applyTranslation = function() {try{
	var me = this;
	[].forEach.call(document.querySelectorAll('[data-text]'), function(e) {
		var tr = me.text(e.dataset.text);
		if (tr === null) {
			console.error("Translation for text "+e.dataset.text+" not found!");
		} else if (tr !== "") {
			e.innerHTML = tr;
		}
	});
}catch(e){console.error(e)}}

SapGui.prototype.text = function(id) {try{
	return (this.texts[id]) ? this.texts[id] : null;
}catch(e){console.error(e)}}

SapGui.prototype.httpRequest = function() {try{
	try {
		return new ActiveXObject("Msxml2.XMLHTTP");
	} catch (e1) {
		try {
			return new XMLHttpRequest();
		} catch (e2) {
			return null;
		}
	}
}catch(e){console.error(e)}}

SapGui.prototype.get = function(url, params) {
	var success = (params && params.success) ? params.success : null;
	var fail = (params && params.fail) ? params.fail : null;

	try{
		var xhr = this.httpRequest();
		xhr.open('GET', url);
		xhr.onreadystatechange = function () {
			if (xhr.readyState === 4 && success !== null) {
				success(xhr.responseText);
			}
		}
		xhr.send();
	} catch(e) {
		if (fail !== null) fail(e);
	}
}

SapGui.prototype.eventGet = function(action, params) {try{
	window.location = "SAPEVENT:"+action+this.getParams(params);
}catch(e){console.error(e)}}

SapGui.prototype.eventPost = function(action, params) {try{
	var isForm = (action instanceof HTMLFormElement);

	var form = isForm ? action : document.createElement("form");
	if (!isForm) {
		form.method = "POST";
		form.action = "SAPEVENT:"+action;
		form.style.visibility = "hidden";
	}
	form.innerHTML = "";

	for (var key in params) {
		var chunks = params[key].toString().replace(/'/g, "\'" ).byChunk(128);
		for(var i=0; i< chunks.length; i++) {
			form.innerHTML+= "<input name='"+key+"_%%"+i+"' value='"+chunks[i]+"'>";
		}
	}

	if (!isForm) document.body.appendChild(form);
	form.submit();
	if (!isForm) document.body.removeChild(form);
}catch(e){console.error(e)}}


SapGui.prototype.raiseException = function(str) {
	window.location = "SAPEVENT:exception?"+str;
}

SapGui.prototype.htmlspecialchars = function(text) {
	return text
		.replace(/&/g, "&amp;")
		.replace(/</g, "&lt;")
		.replace(/>/g, "&gt;")
		.replace(/"/g, "&quot;")
		.replace(/'/g, "&#039;");
}

SapGui.prototype.apiCall = function(command, params) {try{
	var me = this;
	var para = ('undefined' !== typeof params.params) ? params.params : {};
	var success = ('undefined' !== typeof params.success) ? params.success : null;
	var fail = ('undefined' !== typeof params.fail) ? params.fail : null;
	var timeout = ('undefined' !== typeof params.params) ? params.timeout : 10000;

	var id = this.requestId++;
	if (this.requestId > 65535) this.requestId = 0;

	var timerId = -1;
	if (timeout > 0){
		timerId = setTimeout(function(){
			delete(me.requests[id]);
			if (fail !== null) fail();
		}, timeout);
	}

	para["command"] = command;
	para["id"] = id;
	me.requests[id] = {
		timer: timerId,
		params: para,
		success: success,
		fail: fail,
	}

	var action = document.getElementById("form-api-request");
	if (!(action instanceof HTMLFormElement)) action = "api-request";

	me.eventPost(action, para);
}catch(e){console.error(e)}}

SapGui.prototype.apiReceive = function(id, ret) {try{
	if (!this.requests[id]) return;
	if (this.requests[id].timer > -1) clearTimeout(this.requests[id].timer);
	if (this.requests[id].success !== null) this.requests[id].success(ret);
}catch(e){console.error(e)}}

SapGui.prototype.message = function(type, text, displayLike) {try{
	this.eventGet('message', {
		"type": type.toUpperCase(),
		"text": text,
		"display-like": (typeof displayLike === 'string') ? displayLike.toUpperCase() : ''
	})
}catch(e){console.error(e)}}


window.sapgui = new SapGui();

document.addEventListener("DOMContentLoaded", function(event) {
	sapgui.translatePage();
});

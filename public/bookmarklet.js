javascript:(function() {
    var d = document;
    var links = [];
    var found = {};
    var matches = d.body.innerHTML.match(/magnet:[^"' ]+/g);
    if (matches) {
        for (var i=0; i < matches.length; i++) {
            var h = matches[i];
            if (!found[h]) {
                var t = unescape(h.match(/dn=([^&]+)/)[1]);
                links.push({title: t, href: h, type: 'magnet'});
                found[h] = true;
            }
        }
    }
    var anchors = document.getElementsByTagName("a");
    for (var i = 0; i < anchors.length; i++) {
        var h = anchors[i].href;
        if (h.match(/[.]torrent$/) && !found[h]) {
            var t = unescape(h.replace(/^.*\/([^\/]+)[.]torrent$/, "$1"));
            links.push({title: t, href: h, type: 'torrent'});
            found[h] = true;
        }
    }
    if (links.length > 0) {
        var div = d.getElementById("mediacenter-add-link");
        if (div) {
            div.parentNode.removeChild(div);
        }
        div = d.createElement("div");
        div.setAttribute("id", "mediacenter-add-link");
        div.setAttribute("style", "position:absolute;z-index:9999;top:0;left:50%;margin-left:-300px;width:600px;background:white;padding:20px;color:#333;font:16px helvetica");
        var html = [];
        for (var i=0; i < links.length; i++) {
            html.push("<div style='margin-bottom:10px'><button style='font-family:Helvetica;text-transform:uppercase;font-size:20px;font-weight:bold;padding:10px 20px;border:0;background:#009cff;color:#fff;text-align:center;border-radius:1px;display:block;width:100%;cursor:pointer' data-href='" + links[i].href + "'>" + links[i].title + "." + links[i].type + "</button></div>");
        }
        html.push("<div><button data-role='cancel' style='font-family:Helvetica;text-transform:uppercase;font-size:20px;font-weight:bold;padding:10px 20px;border:0;background:#ccc;color:#fff;text-align:center;border-radius:1px;display:block;width:100%;cursor:pointer'>Cancel</button></div>");
        div.innerHTML = html.join("\n");
        d.body.appendChild(div);
        div.scrollIntoView();
        div.onclick = function(event) {
            event.preventDefault();
            event.stopPropagation();
            var target = event.target;
            var href = target.getAttribute("data-href");
            if (target.getAttribute("data-role") == "cancel") {
                d.body.removeChild(div);
            }
            if (href) {
                var f = d.createElement("form");
                f.method = "post";
                f.action = "//localhost:9292/transfers";
                f.innerHTML = "<input type=hidden name=redirect value=1><input type=hidden name=url value='" + href + "'>";
                f.submit();
            }
        };
    } else {
        alert("No torrent links found on page");
    }
})();

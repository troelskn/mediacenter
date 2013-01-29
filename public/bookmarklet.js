javascript:(function() {
    var d = document;
    var matches = d.body.innerHTML.match(/magnet:[^"' ]+/);
    var magnetLinks = [];
    var found = {};
    if (matches) {
        for (var i=0; i < matches.length; i++) {
            var h = matches[i];
            if (!found[h]) {
                var t = unescape(h.match(/dn=([^&]+)/)[1]);
                magnetLinks.push({title: t, href: h});
                found[h] = true;
            }
        }
    }
    if (magnetLinks.length > 0) {
        var div = d.createElement("div");
        div.setAttribute("style", "position:fixed;z-index:9999;top:0;left:50%;margin-left:-300px;width:600px;background:white;padding:20px;color:#333;font:16px helvetica");
        var html = [];
        for (var i=0; i < magnetLinks.length; i++) {
            html.push("<div style='margin-bottom:10px'><button style='font-family:Helvetica;text-transform:uppercase;font-size:20px;font-weight:bold;padding:10px 20px;border:0;background:#009cff;color:#fff;text-align:center;border-radius:1px;display:block;width:100%;cursor:pointer' data-href='" + magnetLinks[i].href + "'>Download " + magnetLinks[i].title + "</button></div>");
        }
        html.push("<div><button data-role='cancel' style='font-family:Helvetica;text-transform:uppercase;font-size:20px;font-weight:bold;padding:10px 20px;border:0;background:#ccc;color:#fff;text-align:center;border-radius:1px;display:block;width:100%;cursor:pointer'>Cancel</button></div>");
        div.innerHTML = html.join("\n");
        d.body.appendChild(div);
        div.onclick = function(event) {
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

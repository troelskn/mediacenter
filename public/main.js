$(document).ready(function() {
    var fragmentTransfer = $("#fragment-transfer").clone().removeAttr("id");
    var fragmentStream = $("#fragment-stream").clone().removeAttr("id");

    var reflow = function() {
        var fullWidth = $(window).width() / 100;
        $("#transfers li").each(function() {
            var el = $(this);
            var offset = Math.round(fullWidth * el.attr("data-progress")) - 2048;
            el.css({"background-position": offset + "px 0"});
        });
    };

    var updateTransferItem = function(item) {
        var dom = $("[data-transfer-id=" + item.id + "]");
        if (!dom.get(0)) {
            dom = fragmentTransfer.clone();
            $("#transfers").append(dom);
        }
        dom.attr("data-progress", item.progress);
        dom.attr("data-transfer-id", item.id);
        dom.attr("data-status", item.status);
        dom.find(".name").text(item.name);
        dom.find(".status").text(item.status);
        dom.find(".info").text(["up " + Math.round(item.up / 1024) + " K", "down " + Math.round(item.down / 1024) + " K", item.eta].join(" / "));
        if (item.status != "stopped") {
            dom.addClass("active");
        } else {
            dom.removeClass("active");
        }
        if (item.status == "stopped") {
            dom.addClass("paused");
        } else {
            dom.removeClass("paused");
        }
    };

    var updateTransfers = function() {
        $.ajax({
            dataType: 'json',
            url: '/transfers',
            success: function(data) {
                $(data).each(function(_,item) {
                    updateTransferItem(item);
                });
                reflow();
            }
        });
    };

    var updateStreamItem = function(item) {
        var dom = $("[data-stream-id=" + item.id + "]");
        if (!dom.get(0)) {
            dom = fragmentStream.clone();
            $("#library").append(dom);
        }
        dom.attr("data-stream-id", item.id);
        dom.find(".name").text(item.title);
        dom.find(".status").text(item.status);
        dom.find(".play").attr("href", "/streams/" + item.id + "/stream.m3u8"); // TODO: Get this href from server side
        if (item.status == "complete") {
            dom.addClass("complete");
        } else {
            dom.removeClass("complete");
        }
    };

    var updateLibrary = function() {
        $.ajax({
            dataType: 'json',
            url: '/streams',
            success: function(data) {
                $(data).each(function(_,item) {
                    updateStreamItem(item);
                });
            }
        });
    };

    $(window).resize(reflow);
    updateTransfers();
    setInterval(function() {
        if ($("#menu-transfers").hasClass("selected")) {
            updateTransfers();
        }
        if ($("#menu-library").hasClass("selected")) {
            updateLibrary();
        }
    }, 5000);

    $("ul").delegate("li", "click", function(event) {
        var el = $(this);
        var target = $(event.target);
        if (!target.is(".controls, .controls > *")) {
            var selected = el.hasClass("selected");
            $("ul li").removeClass("selected");
            if (!selected) {
                el.addClass("selected").find(".controls").each(function() { this.scrollIntoView(); });
            }
        }
    });

    $("#transfers").delegate(".stop", "click", function() {
        var el = $(this).closest("li");
        $.ajax({
            type: 'PUT',
            dataType: 'json',
            url: '/transfers/' + el.attr("data-transfer-id"),
            data: { status: "stop" },
            success: function(item) {
                updateTransferItem(item);
                reflow();
            }
        });
    });

    $("#transfers").delegate(".start", "click", function() {
        var el = $(this).closest("li");
        $.ajax({
            type: 'PUT',
            dataType: 'json',
            url: '/transfers/' + el.attr("data-transfer-id"),
            data: { status: "start" },
            success: function(item) {
                updateTransferItem(item);
                reflow();
            }
        });
    });

    $("#menu-transfers").click(function() {
        $("#menu-transfers").addClass("selected");
        $("#menu-library").removeClass("selected");
        $("#transfers").show();
        $("#library").hide();
    });

    $("#menu-library").click(function() {
        updateLibrary();
        $("#menu-transfers").removeClass("selected");
        $("#menu-library").addClass("selected");
        $("#transfers").hide();
        $("#library").show();
    });

});
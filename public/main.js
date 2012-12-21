$(document).ready(function() {
    var fragmentTransfer = $("#fragment-transfer").clone().removeAttr("id");
    var fragmentMovie = $("#fragment-movie").clone().removeAttr("id");

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
        if (item.status != "stopped" && item.progress < 100) {
            dom.addClass("active");
        } else {
            dom.removeClass("active");
        }
        if (item.status == "stopped" && item.progress < 100) {
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

    var updateMovieItem = function(item) {
        var dom = $("[data-movie-id=" + item.id + "]");
        if (!dom.get(0)) {
            dom = fragmentMovie.clone();
            $("#library").append(dom);
        }
        dom.attr("data-movie-id", item.id);
        dom.find(".name").text(item.title);
        dom.find(".status").text(item.duration);
    };

    var updateLibrary = function() {
        $.ajax({
            dataType: 'json',
            url: '/movies',
            success: function(data) {
                $(data).each(function(_,item) {
                    updateMovieItem(item);
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
            var active = el.hasClass("selected");
            $("ul li").removeClass("selected");
            if (!active) {
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
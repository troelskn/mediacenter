$(document).ready(function() {
    var fragmentTransfer = $("#fragment-transfer").clone().removeAttr("id");
    var fragmentStream = $("#fragment-stream").clone().removeAttr("id");

    var reflow = function() {
        var fullWidth = $(window).width() / 100;
        $("#transfers li[data-progress]").each(function() {
            var el = $(this);
            var offset = Math.round(fullWidth * el.attr("data-progress")) - 2048;
            el.css({"background-position": offset + "px 0"});
        });
    };

    var selectTransferItems = function() {
        return $("#transfers li[data-transfer-id]");
    };

    var selectStreamItems = function() {
        return $("#library li[data-stream-id]");
    };

    var updateTransferItem = function(item) {
        var dom = $("[data-transfer-id=" + item.id + "]");
        if (!dom.get(0)) {
            dom = fragmentTransfer.clone();
            $("#transfers").prepend(dom);
        }
        dom.attr("data-progress", item.progress);
        dom.attr("data-transfer-id", item.id);
        dom.attr("data-status", item.status);
        dom.find(".name").text(item.name);
        dom.find(".status").text(item.status);
        dom.find(".info").text(["up " + Math.round(item.up / 1024) + " K", "down " + Math.round(item.down / 1024) + " K", item.eta].join(" / "));
        if (item.status == "encoding") {
            dom.addClass("encoding");
        } else {
            dom.removeClass("encoding");
        }
        if (item.status == "download") {
            dom.addClass("active");
        } else {
            dom.removeClass("active");
        }
        if (item.status == "stopped") {
            dom.addClass("paused");
        } else {
            dom.removeClass("paused");
        }
        dom.find(".disabled").each(function() {
            this.disabled = false;
            $(this).removeClass("disabled");
        });
    };

    var updateTransfers = function() {
        $.ajax({
            dataType: 'json',
            url: '/transfers',
            success: function(data) {
                var foundIds = [];
                $(data).each(function(_,item) {
                    foundIds.push(item.id);
                    updateTransferItem(item);
                });
                var removedItems = selectTransferItems().not(function() {
                    return $.inArray(parseInt($(this).attr("data-transfer-id")), foundIds) > -1;
                });
                removedItems.remove();
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
                var foundIds = [];
                $(data).each(function(_,item) {
                    foundIds.push(item.id);
                    updateStreamItem(item);
                });
                var removedItems = selectStreamItems().not(function() {
                    return $.inArray($(this).attr("data-stream-id"), foundIds) > -1;
                });
                removedItems.remove();
                reflow();
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

    $("ul").delegate("li:not(.toolbar)", "click", function(event) {
        var el = $(this);
        var target = $(event.target);
        if (!target.is(".controls, .controls > *")) {
            var selected = el.hasClass("selected");
            $("ul li").removeClass("selected");
            if (!selected) {
                el.addClass("selected"); //.find(".controls").each(function() { this.scrollIntoView(); });
            }
        }
    });

    $("#transfers").delegate(".stop", "click", function() {
        var self = $(this);
        var el = self.closest("li");
        this.disabled = true;
        self.addClass("disabled");
        $.ajax({
            type: 'PUT',
            dataType: 'json',
            url: '/transfers/' + el.attr("data-transfer-id"),
            data: { status: "stop" }
        });
    });

    $("#transfers").delegate(".start", "click", function() {
        var self = $(this);
        var el = self.closest("li");
        this.disabled = true;
        self.addClass("disabled");
        $.ajax({
            type: 'PUT',
            dataType: 'json',
            url: '/transfers/' + el.attr("data-transfer-id"),
            data: { status: "start" }
        });
    });

    $("#transfers").delegate(".delete", "click", function() {
        if (!confirm("Are you sure you want to delete this?")) {
            return;
        }
        var self = $(this);
        var el = self.closest("li");
        this.disabled = true;
        self.addClass("disabled");
        $.ajax({
            type: 'DELETE',
            dataType: 'json',
            url: '/transfers/' + el.attr("data-transfer-id")
        });
    });

    $("#library").delegate(".delete", "click", function() {
        if (!confirm("Are you sure you want to delete this?")) {
            return;
        }
        var self = $(this);
        var el = self.closest("li");
        this.disabled = true;
        self.addClass("disabled");
        $.ajax({
            type: 'DELETE',
            dataType: 'json',
            url: '/streams/' + el.attr("data-stream-id") + '/stream.m3u8'
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

    $("#add-transfer-toggle").click(function() {
        $(this).hide();
        $("#add-transfer-text").val("");
        $("#add-transfer-container").show();
    });

    $("#add-transfer-cancel").click(function() {
        $("#add-transfer-container").hide();
        $("#add-transfer-toggle").show();
    });

    $("#add-transfer-submit").click(function() {
        $.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/transfers',
            data: { url: $("#add-transfer-text").val() },
            success: function() {
                $("#add-transfer-container").hide();
                $("#add-transfer-toggle").show();
            }
        });
    });


    $("#library").delegate(".rename-toggle", "click", function(event) {
        event.stopPropagation();
        var self = $(this);
        var el = self.closest("li");
        el.find(".rename-stream-text").val(el.find(".name").text());
        el.find(".default-stream-container").hide();
        el.find(".rename-stream-container").show();
    });

    $("#library").delegate(".rename-stream-container", "click", function(event) {
        event.stopPropagation();
    });

    $("#library").delegate(".rename-stream-cancel", "click", function(event) {
        var self = $(this);
        var el = self.closest("li");
        el.find(".default-stream-container").show();
        el.find(".rename-stream-container").hide();
    });

    $("#library").delegate(".rename-stream-submit", "click", function(event) {
        var self = $(this);
        var el = self.closest("li");
        var name = el.find(".rename-stream-text").val();
        el.find(".default-stream-container").show();
        el.find(".rename-stream-container").hide();
        el.find(".rename-toggle").addClass("disabled").get(0).disabled = true;
        $.ajax({
            type: 'POST',
            dataType: 'json',
            url: '/streams/' + el.attr("data-stream-id") + '/stream.m3u8',
            data: {title: name},
            success: function() {
                el.find(".name").text(name);
                el.find(".rename-toggle").removeClass("disabled").get(0).disabled = false;
            }
        });
    });

});

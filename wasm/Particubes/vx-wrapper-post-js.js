
// MARK: - Canvas resize -

// When there is a resize, check if there is already an ongoing event & cancel it ;
// this allows to get only one event per resize & avoid spamming
function setResizeHandler(callback, timeout) {
    var timer_id = undefined;
    window.addEventListener("resize", function () {
        if (timer_id != undefined) {
            clearTimeout(timer_id);
            timer_id = undefined;
        }
        timer_id = setTimeout(function () {
            timer_id = undefined;
            callback();
        }, timeout);
    });
}

function refreshCanvas() {
    // Get size of the HTML element after window resize
    const displayWidth = canvas.clientWidth;
    const displayHeight = canvas.clientHeight;

    // Update display size if needed
    if (canvas.width !== displayWidth || canvas.height !== displayHeight) {
        canvas.width = displayWidth;
        canvas.height = displayHeight;
        return true;
    } else {
        return false;
    }
}

function resizeCallback() {
    // Notify vx-wrapper if display size was changed
    if (refreshCanvas()) {
        Module.didResize();
    }
}

// MARK: - Canvas visibility -

function getVisibilityEventAndStateKeys() {
    // Check all possible visibility keys
    var stateKey, eventKey, keys = {
        hidden: "visibilitychange",
        webkitHidden: "webkitvisibilitychange",
        mozHidden: "mozvisibilitychange",
        msHidden: "msvisibilitychange"
    };
    for (stateKey in keys) {
        if (stateKey in document) {
            eventKey = keys[stateKey];
            break;
        }
    }
    return { eventKey, stateKey };
}

function setVisibilityHandler(callback) {
    let { eventKey, stateKey } = getVisibilityEventAndStateKeys();
    document.addEventListener(eventKey, callback);
}

function visibilityCallback() {
    let { eventKey, stateKey } = getVisibilityEventAndStateKeys();
    if (document[stateKey]) {
        Module.willResignActive();
    } else {
        Module.didBecomeActive();
    }
}

// MARK: - Canvas unload -

function setUnloadHandler(callback) {
    window.addEventListener("beforeunload", callback);
}

function unloadCallback() {
    Module.willTerminate();
}

// MARK: - Initialization -
// Called from vx-wrapper main, where module is garanteed to be initialized

function init() {

    // Set canvas.width/height once in case they are not used in the HTML page
    refreshCanvas();

    // Event listeners
    setResizeHandler(resizeCallback, 100); // .1 sec resize timeout
    setVisibilityHandler(visibilityCallback);
    setUnloadHandler(unloadCallback);

    Module.hideLoadingIndicator();
}

function getSearchParameters() {
    var prmstr = window.location.search.substr(1);
    return prmstr != null && prmstr != "" ? transformToAssocArray(prmstr) : {};
}

function transformToAssocArray(prmstr) {
    var params = {};
    var prmarr = prmstr.split("&");
    for (var i = 0; i < prmarr.length; i++) {
        var tmparr = prmarr[i].split("=");
        params[tmparr[0]] = tmparr[1];
    }
    return params;
}

function get_search_parameters_as_jsonstring() {
    var params = getSearchParameters();
    return JSON.stringify(params);
}

function fs_sync_to_disk() {
    // true means storage -> emscripten FS
    // false means emscripten -> storage
    let populate = false;
    FS.syncfs(populate, function (err) {
        // on success, err is null
    });
}

/**
 * keyboard_fix.js - Mobile virtual-keyboard fix for eframe/egui WASM apps.
 *
 * Problem
 * -------
 * eframe proxies all keyboard input through a single hidden
 * <input type="text"> called the "text agent".  It focuses this element
 * from requestAnimationFrame, which iOS Safari does NOT treat as a
 * user-gesture context, so the virtual keyboard never appears.
 *
 * "Keyboard appears then immediately disappears" root cause
 * ---------------------------------------------------------
 * When input.focus() is called, the browser fires canvas.blur()
 * synchronously before the focus transfer completes.  eframe's canvas-blur
 * handler queues WindowFocused(false).  The Rust raw_input_hook in app.rs
 * collapses the resulting false/true pair so egui never clears its focused
 * widget.  As belt-and-suspenders, this script also patches canvas.focus()
 * to a no-op for ~500 ms after each touchend so the canvas cannot steal
 * focus back even if ime=None momentarily.
 *
 * Canvas lookup timing
 * --------------------
 * The <script src="keyboard_fix.js"> tag appears in <body> *before* the
 * <canvas> element, so getElementById() would return null if called at
 * load time.  The canvas lookup is therefore deferred into doAttach(),
 * which runs only once the text-agent <input> has been added by WASM --
 * at which point the full DOM (including the canvas) is available.
 *
 * Exports (for testing only -- not used at runtime in the browser)
 * ----------------------------------------------------------------
 * attach(input, canvas, options)  -- wire event listeners + patch canvas.focus
 * init(body, canvasId, options)   -- find canvas + text-agent, call attach
 */

'use strict';

/**
 * Wire the keyboard-fix event listeners onto a text-agent input and canvas.
 *
 * @param {HTMLInputElement}  input   eframe's hidden text-agent <input>
 * @param {HTMLCanvasElement} canvas  the egui canvas element
 * @param {Object}  [options]
 * @param {number}  [options.keepMs=500]  ms to block canvas.focus() after touch
 */
function attach(input, canvas, options) {
    var keepMs = (options && options.keepMs != null) ? options.keepMs : 500;
    var keep   = false;
    var timer  = null;

    /* Patch canvas.focus() to a no-op while keep=true.
     * eframe calls canvas.focus() from handle_platform_output when ime=None.
     * Blocking it prevents the canvas from stealing focus from the text-agent
     * and dismissing the virtual keyboard. */
    var _origFocus = canvas.focus.bind(canvas);
    canvas.focus = function () {
        if (!keep) { _origFocus(); }
    };

    canvas.addEventListener('touchend', function () {
        keep = true;
        clearTimeout(timer);
        input.focus();
        timer = setTimeout(function () { keep = false; }, keepMs);
    }, { passive: true });
}

/**
 * Find the canvas and text-agent input in the given document body and call
 * attach().  Safe to call before WASM initialisation: a MutationObserver
 * watches for the input to be inserted, and the canvas lookup is deferred
 * until that point so it works even when the script loads before <canvas>.
 *
 * @param {HTMLElement} body      document.body
 * @param {string}      canvasId  id of the egui canvas element
 * @param {Object}      [options] forwarded to attach()
 */
function init(body, canvasId, options) {
    /* Deferred canvas lookup: called only after the text-agent appears.
     * By that time WASM has initialised and the canvas is in the DOM. */
    function doAttach(input) {
        var doc    = body.ownerDocument || document;
        var canvas = doc.getElementById(canvasId);
        if (!canvas) { return; }
        attach(input, canvas, options);
    }

    /* Text-agent may already exist (safe fallback). */
    var existing = body.querySelector('input[type=text]');
    if (existing) { doAttach(existing); return; }

    /* Watch for eframe to append the text-agent to <body>. */
    var mo = new MutationObserver(function (list) {
        for (var i = 0; i < list.length; i++) {
            var nodes = list[i].addedNodes;
            for (var j = 0; j < nodes.length; j++) {
                var n = nodes[j];
                if (n.nodeName === 'INPUT' && n.type === 'text') {
                    mo.disconnect();
                    doAttach(n);
                    return;
                }
            }
        }
    });
    mo.observe(body, { childList: true });
}

/* -- Browser runtime entry point ----------------------------------------- */
if (typeof module === 'undefined') {
    init(document.body, 'the_canvas_id');
} else {
    /* Node.js / Jest: export for testing. */
    module.exports = { attach: attach, init: init };
}

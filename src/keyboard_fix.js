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
 * @param {number}  [options.keepMs=500]  ms to block canvas.focus() after text-agent focus
 * @param {boolean} [options.focusOnTouch=false] call input.focus() on canvas touchend
 */
function attach(input, canvas, options) {
    var keepMs       = (options && options.keepMs != null) ? options.keepMs : 500;
    var focusOnTouch = !!(options && options.focusOnTouch);
    var keep         = false;
    var timer        = null;
    var doc          = input.ownerDocument || document;

    // Ensure the hidden text-agent stays visually hidden even when focused.
    // Some browsers still paint a caret/focus ring unless we clear multiple
    // style properties (including WebKit-specific text fill).
    input.style.position = 'fixed';
    input.style.top = '0';
    input.style.left = '-10000px';
    input.style.right = 'auto';
    input.style.width = '0px';
    input.style.height = '0px';
    input.style.maxWidth = '0px';
    input.style.maxHeight = '0px';
    input.style.overflow = 'hidden';
    input.style.clip = 'rect(0 0 0 0)';
    input.style.clipPath = 'inset(50%)';
    input.style.whiteSpace = 'nowrap';
    input.style.padding = '0';
    input.style.margin = '0';
    input.style.border = '0';
    input.style.outline = 'none';
    input.style.boxShadow = 'none';
    input.style.background = 'transparent';
    input.style.pointerEvents = 'none';
    input.style.zIndex = '-1';
    input.style.opacity = '0';
    input.style.caretColor = 'transparent';
    input.style.color = 'transparent';
    input.style.setProperty('-webkit-text-fill-color', 'transparent');

    /* Patch canvas.focus() to a no-op while keep=true.
     * eframe calls canvas.focus() from handle_platform_output when ime=None.
     * Blocking it prevents the canvas from stealing focus from the text-agent
     * and dismissing the virtual keyboard. */
    var _origFocus = canvas.focus.bind(canvas);
    canvas.focus = function () {
        if (!keep) { _origFocus(); }
    };

    function openKeepWindow() {
        keep = true;
        clearTimeout(timer);
        timer = setTimeout(function () { keep = false; }, keepMs);
    }

    // Any successful focus transfer to the text-agent opens the keep window.
    // This avoids forcing keyboard popups from arbitrary canvas taps.
    input.addEventListener('focus', openKeepWindow);
    doc.addEventListener('focusin', function (evt) {
        var target = evt && evt.target;
        if (isTextAgentInput(target)) {
            openKeepWindow();
        }
    }, true);

    // Optional compatibility mode: explicitly focus the text-agent on touch.
    // Runtime keeps this disabled so keyboard opens only from editable widgets.
    if (focusOnTouch) {
        canvas.addEventListener('touchend', function () {
            input.focus();
        }, { passive: true });
    }
}

/**
 * Return true if an input looks like eframe's hidden text-agent.
 *
 * eframe creates it with inline styles:
 *   position:absolute; top:0; left:0; width:1px; height:1px; opacity:0
 * We also accept the post-attach style variants this file applies.
 */
function isTextAgentInput(input) {
    if (!input || input.nodeName !== 'INPUT') {
        return false;
    }
    if (input.type !== 'text') {
        return false;
    }
    if (!input.style) {
        return false;
    }
    var style = input.style;
    var positionOk = style.position === 'absolute' || style.position === 'fixed';

    function isNumericAtMostOne(v) {
        var n = parseFloat(v || '');
        return !isNaN(n) && n >= 0 && n <= 1;
    }

    var tinyBox = isNumericAtMostOne(style.width) && isNumericAtMostOne(style.height);
    var hiddenOpacity = parseFloat(style.opacity || '') === 0;
    var offscreenLeft = parseFloat(style.left || '') < 0;

    // Match eframe's default hidden input style and our post-attach style.
    // Keep permissive enough to survive style-order differences on refresh.
    return positionOk && (tinyBox || hiddenOpacity || offscreenLeft);
}

/**
 * Find the most recent hidden text-agent input in <body>.
 *
 * We scan from the end because dynamic UIs can append additional inputs over
 * time. Using the latest matching hidden input keeps us bound to the current
 * eframe text-agent instead of an older/stale node or unrelated visible input.
 */
function findTextAgent(body) {
    var inputs = body.querySelectorAll('input[type=text]');
    for (var i = inputs.length - 1; i >= 0; i--) {
        if (isTextAgentInput(inputs[i])) {
            return inputs[i];
        }
    }
    return null;
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
    var attached = false;
    var mo = null;

    /* Deferred canvas lookup: called only after the text-agent appears.
     * By that time WASM has initialised and the canvas is in the DOM. */
    function doAttach(input) {
        if (attached) { return; }
        var doc    = body.ownerDocument || document;
        var canvas = doc.getElementById(canvasId);
        if (!canvas) { return; }
        attach(input, canvas, options);
        attached = true;
        if (mo) { mo.disconnect(); }
    }

    function tryAttach(candidateRoot) {
        if (attached) { return; }
        var candidate = findTextAgent(candidateRoot || body);
        if (candidate) {
            doAttach(candidate);
        }
    }

    /* Text-agent may already exist (safe fallback).
     * Do not return if canvas is not yet present; continue observing so we can
     * attach later when the canvas appears (script-before-canvas load order). */
    tryAttach(body);
    if (attached) { return; }

    /* Watch for eframe to append/update/style the text-agent in <body>. */
    mo = new MutationObserver(function (list) {
        for (var i = 0; i < list.length; i++) {
            var m = list[i];
            if (m.type === 'attributes') {
                var target = m.target;
                if (target && target.nodeName === 'INPUT' && target.type === 'text') {
                    if (isTextAgentInput(target)) {
                        doAttach(target);
                        return;
                    }
                }
            } else {
                var nodes = m.addedNodes;
                for (var j = 0; j < nodes.length; j++) {
                    var n = nodes[j];
                    if (n.nodeName === 'INPUT' && n.type === 'text') {
                        if (isTextAgentInput(n)) {
                            doAttach(n);
                            return;
                        }
                        tryAttach(body);
                    }
                    if (n.querySelector) {
                        tryAttach(n);
                        if (attached) { return; }
                    }
                    // If canvas appears after an already-existing text-agent,
                    // re-check the full body so doAttach can now succeed.
                    tryAttach(body);
                    if (attached) { return; }
                }
            }
        }
    });
    mo.observe(body, { childList: true, subtree: true, attributes: true, attributeFilter: ['style'] });
}

/* -- Browser runtime entry point ----------------------------------------- */
if (typeof module === 'undefined') {
    init(document.body, 'the_canvas_id');
} else {
    /* Node.js / Jest: export for testing. */
    module.exports = { attach: attach, init: init };
}

/**
 * keyboard_fix.test.js
 *
 * Light-touch tests for the mobile virtual-keyboard fix.
 *
 * Each test simulates one distinct interactive component type:
 *   - A tracker note cell (touchend on the canvas)
 *   - The Step DragValue (touchend on the canvas, same path — both are
 *     canvas-rendered egui widgets; the JS layer treats them identically)
 *
 * The scenario under test for each component is:
 *   1. User taps an editable component  →  input.focus() is called (keyboard appears).
 *   2. eframe immediately calls canvas.focus() to reclaim focus (would dismiss
 *      the keyboard)  →  the patch blocks it during the keep window.
 *   3. After keepMs the patch expires  →  canvas.focus() works again.
 *
 * The "keyboard appears then immediately disappears" bug is reproduced by the
 * test "canvas.focus() reclaims focus if NOT patched": without the fix, calling
 * canvas.focus() after a touchend returns focus to the canvas and input is no
 * longer the active element.  With the fix applied that same call is a no-op
 * inside the keep window, so input stays focused.
 */

'use strict';

const { attach, init } = require('./keyboard_fix');

// ── helpers ──────────────────────────────────────────────────────────────────

/** Fire a synthetic touchend event on an element. */
function fireTouchEnd(el) {
    el.dispatchEvent(new Event('touchend', { bubbles: true }));
}

/**
 * Build a minimal DOM: <body> containing a <canvas> and a hidden text <input>.
 * Returns { body, canvas, input }.
 */
function makeDOM() {
    document.body.innerHTML =
        '<canvas id="the_canvas_id" tabindex="0"></canvas>' +
        '<input type="text" />';
    const canvas = document.getElementById('the_canvas_id');
    const input  = document.querySelector('input[type=text]');
    return { body: document.body, canvas, input };
}

function applyTextAgentStyles(input) {
    input.style.position = 'absolute';
    input.style.top = '0';
    input.style.left = '0';
    input.style.width = '1px';
    input.style.height = '1px';
    input.style.opacity = '0';
}

function applyEarlyTextAgentStyles(input) {
    // Simulate refresh timing where only part of the hidden-agent style
    // has been applied when MutationObserver fires.
    input.style.position = 'absolute';
    input.style.opacity = '0';
}

// ── attach() — core focus-fix behaviour ──────────────────────────────────────

describe('attach() — note cell tap', () => {
    test('tapping the canvas can focus the text-agent when focusOnTouch is enabled', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);

        expect(document.activeElement).toBe(input);
    });

    test('canvas.focus() is a no-op during the keep window (keyboard stays open)', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);       // input is now focused; keep window opens
        canvas.focus();             // eframe calls this — must be blocked

        // Input must still be active; canvas must NOT have stolen focus back.
        expect(document.activeElement).toBe(input);
    });

    test('canvas.focus() works again after keepMs expires', () => {
        jest.useFakeTimers();
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);
        jest.advanceTimersByTime(101);   // keep window closed
        canvas.focus();                  // should work now

        expect(document.activeElement).toBe(canvas);
        jest.useRealTimers();
    });
});

describe('attach() — Step DragValue tap', () => {
    // The Step component is an egui DragValue rendered on the same canvas.
    // From the JS layer it is indistinguishable from a note cell — both are
    // touchend events on the canvas element.  These tests confirm the same
    // fix applies.

    test('tapping the canvas for the Step component focuses the text-agent', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);

        expect(document.activeElement).toBe(input);
    });

    test('canvas.focus() cannot dismiss the keyboard immediately after a Step tap', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);
        canvas.focus();   // eframe reclaim attempt — must be blocked

        expect(document.activeElement).toBe(input);
    });

    test('keyboard can be closed (canvas.focus restored) after keepMs', () => {
        jest.useFakeTimers();
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);
        jest.advanceTimersByTime(101);
        canvas.focus();

        expect(document.activeElement).toBe(canvas);
        jest.useRealTimers();
    });
});

// ── The bug: without the fix the keyboard would immediately close ─────────────

describe('regression — keyboard appears then immediately disappears', () => {
    test('WITHOUT the patch canvas.focus() reclaims focus (documents the bug)', () => {
        // Demonstrates exactly what happens without keyboard_fix.js:
        // the browser fires canvas.blur/input.focus, then eframe calls
        // canvas.focus() and the keyboard disappears.
        const { canvas, input } = makeDOM();
        // Do NOT call attach() — no fix applied.

        input.focus();   // JS touchend handler would do this
        canvas.focus();  // eframe immediately reclaims focus

        // Without the fix, the canvas wins and the keyboard is dismissed.
        expect(document.activeElement).toBe(canvas);
    });

    test('WITH the patch canvas.focus() is blocked and input stays focused', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);  // opens keep window + focuses input
        canvas.focus();        // eframe reclaim — blocked by fix

        expect(document.activeElement).toBe(input);
    });

    test('focusin on hidden text-agent opens keep window even without direct focus listener firing', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: false });

        input.dispatchEvent(new FocusEvent('focusin', { bubbles: true }));
        input.focus();

        canvas.focus();
        expect(document.activeElement).not.toBe(canvas);
        expect(document.activeElement).toBe(input);
    });

    test('first touch keeps keyboard focused during short wait before reclaim attempt', () => {
        jest.useFakeTimers();
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 500, focusOnTouch: true });

        fireTouchEnd(canvas);         // first press on invisible-input path
        jest.advanceTimersByTime(250); // user pauses before next interaction
        canvas.focus();               // reclaim attempt must still be blocked

        expect(document.activeElement).toBe(input);
        jest.useRealTimers();
    });
});

// ── init() — deferred canvas lookup (the real browser load order) ─────────────

describe('init() — canvas lookup is deferred until text-agent is inserted', () => {
    test('works when init() is called before the canvas exists in the DOM', async () => {
        // Simulate the real HTML load order:
        //   <script src="keyboard_fix.js">  ← runs here, canvas not yet parsed
        //   <canvas id="the_canvas_id">     ← parsed after script
        //   WASM loads → appends <input type="text"> to <body>
        document.body.innerHTML = '';   // empty DOM — no canvas yet

        // Call init() before the canvas is present (matches the script tag).
        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        // Now add the canvas (browser parses the rest of <body>).
        const canvas = document.createElement('canvas');
        canvas.id = 'the_canvas_id';
        canvas.tabIndex = 0;
        document.body.appendChild(canvas);

        // WASM initialises and appends the text-agent <input>.
        const input = document.createElement('input');
        input.type = 'text';
        applyTextAgentStyles(input);
        document.body.appendChild(input);

        // MutationObserver callbacks run as microtasks; yield before asserting.
        await Promise.resolve();

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(input);
    });

    test('still attaches when hidden text-agent exists before canvas is parsed', async () => {
        // Simulate script running before canvas, while eframe text-agent already exists.
        document.body.innerHTML = '';
        const input = document.createElement('input');
        input.type = 'text';
        applyTextAgentStyles(input);
        document.body.appendChild(input);

        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        const canvas = document.createElement('canvas');
        canvas.id = 'the_canvas_id';
        canvas.tabIndex = 0;
        document.body.appendChild(canvas);

        await Promise.resolve();

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(input);
    });

    test('works when the text-agent already exists at init() call time', () => {
        const { body, canvas, input } = makeDOM();
        applyTextAgentStyles(input);
        init(body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        fireTouchEnd(canvas);

        expect(document.activeElement).toBe(input);
    });

    test('ignores visible text inputs and binds to hidden text-agent appended later', async () => {
        document.body.innerHTML = '<canvas id="the_canvas_id" tabindex="0"></canvas><input type="text" id="visible_input" />';
        const canvas = document.getElementById('the_canvas_id');
        const visible = document.getElementById('visible_input');

        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        const textAgent = document.createElement('input');
        textAgent.type = 'text';
        applyTextAgentStyles(textAgent);
        document.body.appendChild(textAgent);

        await Promise.resolve();

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(textAgent);
        expect(document.activeElement).not.toBe(visible);
    });

    test('binds when hidden text-agent is detected from partial early styles', async () => {
        document.body.innerHTML = '<canvas id="the_canvas_id" tabindex="0"></canvas><input type="text" id="visible_input" />';
        const canvas = document.getElementById('the_canvas_id');
        const visible = document.getElementById('visible_input');

        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        const textAgent = document.createElement('input');
        textAgent.type = 'text';
        applyEarlyTextAgentStyles(textAgent);
        document.body.appendChild(textAgent);

        await Promise.resolve();

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(textAgent);
        expect(document.activeElement).not.toBe(visible);
    });

    test('finds hidden text-agent when appended inside a nested container', async () => {
        document.body.innerHTML = '<canvas id="the_canvas_id" tabindex="0"></canvas><input type="text" id="visible_input" />';
        const canvas = document.getElementById('the_canvas_id');
        const visible = document.getElementById('visible_input');

        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        const wrapper = document.createElement('div');
        const textAgent = document.createElement('input');
        textAgent.type = 'text';
        applyEarlyTextAgentStyles(textAgent);
        wrapper.appendChild(textAgent);
        document.body.appendChild(wrapper);

        await Promise.resolve();

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(textAgent);
        expect(document.activeElement).not.toBe(visible);
    });

    test('still binds after late style mutation on existing text input', async () => {
        document.body.innerHTML = '<canvas id="the_canvas_id" tabindex="0"></canvas><input type="text" id="visible_input" />';
        const canvas = document.getElementById('the_canvas_id');
        const visible = document.getElementById('visible_input');

        init(document.body, 'the_canvas_id', { keepMs: 100, focusOnTouch: true });

        const textAgent = document.createElement('input');
        textAgent.type = 'text';
        // Not hidden yet when inserted (can happen during startup races).
        document.body.appendChild(textAgent);

        // Later style mutation should now be observed and bound.
        applyEarlyTextAgentStyles(textAgent);
        await Promise.resolve();

        visible.focus();
        expect(document.activeElement).toBe(visible);

        fireTouchEnd(canvas);
        expect(document.activeElement).toBe(textAgent);
    });
});

describe('attach() — default mode (no global keyboard popup)', () => {
    test('tapping canvas does not focus input by default', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100 });

        fireTouchEnd(canvas);

        expect(document.activeElement).not.toBe(input);
    });

    test('focusing input still opens keep window and blocks immediate canvas reclaim', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100 });

        input.focus();
        canvas.focus();

        expect(document.activeElement).toBe(input);
    });

    test('hidden input gets strict invisible styles (no visible caret/ring)', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100 });

        expect(input.style.outline).toBe('none');
        expect(input.style.opacity).toBe('0');
        expect(input.style.left).toBe('-10000px');
        expect(input.style.width).toBe('0px');
        expect(input.style.height).toBe('0px');
        expect(input.style.pointerEvents).toBe('none');
        expect(input.style.caretColor).toBe('transparent');
        expect(input.style.color).toBe('transparent');
        expect(input.style.getPropertyValue('-webkit-text-fill-color')).toBe('transparent');
    });

    test('attach() sets autocomplete/autocorrect/inputmode attributes for mobile keyboard compatibility', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100 });

        expect(input.getAttribute('autocomplete')).toBe('off');
        expect(input.getAttribute('autocorrect')).toBe('off');
        expect(input.getAttribute('autocapitalize')).toBe('off');
        expect(input.getAttribute('spellcheck')).toBe('false');
        expect(input.getAttribute('inputmode')).toBe('text');
    });
});

describe('attach() — touchstart pre-arms the keep window', () => {
    test('canvas.focus() is blocked immediately after touchstart (before touchend fires)', () => {
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 500, focusOnTouch: false });

        // Fire touchstart but NOT touchend — keep window should already be open.
        canvas.dispatchEvent(new Event('touchstart', { bubbles: true }));

        // Focus input to make it the active element, then have canvas try to reclaim.
        input.focus();
        canvas.focus(); // must be blocked — keep window was pre-armed on touchstart

        expect(document.activeElement).toBe(input);
    });

    test('touchstart keep window expires so canvas.focus() works after keepMs', () => {
        jest.useFakeTimers();
        const { canvas, input } = makeDOM();
        attach(input, canvas, { keepMs: 100, focusOnTouch: false });

        // touchstart arms the keep window; immediately after it blocks canvas reclaim.
        canvas.dispatchEvent(new Event('touchstart', { bubbles: true }));
        input.focus();
        canvas.focus();
        expect(document.activeElement).toBe(input); // blocked while keep window open

        // Advance past keepMs — keep window is now closed.
        jest.advanceTimersByTime(200);

        // canvas.focus() should now succeed without re-arming anything.
        canvas.focus();
        expect(document.activeElement).toBe(canvas);
        jest.useRealTimers();
    });
});

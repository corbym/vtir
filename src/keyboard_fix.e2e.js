/**
 * keyboard_fix.e2e.js — Playwright end-to-end tests for the mobile keyboard fix.
 *
 * Why Playwright and not Jest/jsdom?
 * jsdom does not enforce browser gesture restrictions. These tests verify
 * behaviour that only manifests in a real browser engine:
 *   - input.focus() is honoured from a touchend (user-gesture) context
 *   - canvas.focus() stealing focus back immediately after input.focus()
 *   - keep window expiry via real setTimeout
 *
 * Tests inject a minimal HTML page via page.setContent() — no WASM/trunk needed.
 *
 * Scenarios (per the bug ticket):
 *   1. Mobile tap → input is document.activeElement (keyboard should appear)
 *   2. canvas.focus() inside keep window → blocked, input stays focused
 *   3. canvas.focus() after keep window expires → canvas wins (normal close)
 *   4. Three rapid taps + eframe reclaim attempts → input holds focus (no flicker)
 *   5. Desktop (no touch) → click does NOT force input focused
 */

'use strict';

const { test, expect } = require('@playwright/test');
const fs   = require('fs');
const path = require('path');

const KEYBOARD_FIX_SRC = fs.readFileSync(
    path.join(__dirname, 'keyboard_fix.js'),
    'utf8'
);

// Replace the runtime entry-point block so attach/init are exposed on window
// without the auto-init that would fire before simulateWasmInit().
const BROWSER_SRC = KEYBOARD_FIX_SRC.replace(
    /\/\* -- Browser runtime entry point[\s\S]*$/,
    'window._kbAttach = attach;\nwindow._kbInit = init;\n'
);

function buildHtml(keepMs) {
    return [
        '<!DOCTYPE html><html>',
        '<head><meta name="viewport" content="width=device-width,initial-scale=1"/></head>',
        '<body>',
        '<canvas id="the_canvas_id" tabindex="0" style="display:block;width:100vw;height:100vh"></canvas>',
        '<script>',
        BROWSER_SRC,
        'window.simulateWasmInit = function(opts) {',
        '  var inp = document.createElement("input");',
        '  inp.type = "text"; inp.id = "text_agent";',
        '  inp.style.position = "absolute"; inp.style.top = "0"; inp.style.left = "0";',
        '  inp.style.width = "1px"; inp.style.height = "1px"; inp.style.opacity = "0";',
        '  document.body.appendChild(inp);',
        '  window._kbInit(document.body, "the_canvas_id", opts || {keepMs:' + keepMs + '});',
        '};',
        'window.simulateCanvasFocus = function() {',
        '  var c = document.getElementById("the_canvas_id"); c.focus();',
        '  return document.activeElement === c;',
        '};',
        'window.activeId = function() {',
        '  var el = document.activeElement;',
        '  return el ? (el.id || el.nodeName.toLowerCase()) : "none";',
        '};',
        'window.simulateTap = function() {',
        '  var c = document.getElementById("the_canvas_id");',
        '  c.dispatchEvent(new TouchEvent("touchstart", {bubbles:true, cancelable:true}));',
        '  c.dispatchEvent(new TouchEvent("touchend",   {bubbles:true, cancelable:true}));',
        '};',
        '</script></body></html>',
    ].join('\n');
}

async function loadPage(page, keepMs) {
    await page.setContent(buildHtml(keepMs || 500), { waitUntil: 'domcontentloaded' });
}

// ── Scenario 1 ───────────────────────────────────────────────────────────────

test('scenario 1 — mobile tap focuses input (keyboard should appear)', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-only: focusOnTouch is disabled on desktop');

    await loadPage(page, 500);
    await page.evaluate(() => window.simulateWasmInit({ keepMs: 500, focusOnTouch: true }));
    await page.evaluate(() => window.simulateTap());

    const active = await page.evaluate(() => window.activeId());
    expect(active).toBe('text_agent');
});

// ── Scenario 2 ───────────────────────────────────────────────────────────────

test('scenario 2 — canvas.focus() inside keep window is blocked (keyboard stays open)', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-only scenario');

    await loadPage(page, 2000);
    await page.evaluate(() => window.simulateWasmInit({ keepMs: 2000, focusOnTouch: true }));
    await page.evaluate(() => window.simulateTap());

    const canvasWon = await page.evaluate(() => window.simulateCanvasFocus());
    const active    = await page.evaluate(() => window.activeId());

    expect(canvasWon).toBe(false);
    expect(active).toBe('text_agent');
});

// ── Scenario 3 ───────────────────────────────────────────────────────────────

test('scenario 3 — canvas.focus() after keep window expires works normally', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-only scenario');

    await loadPage(page, 100);
    await page.evaluate(() => window.simulateWasmInit({ keepMs: 100, focusOnTouch: true }));
    await page.evaluate(() => window.simulateTap());
    await page.waitForTimeout(250); // wait for keep window to expire

    await page.evaluate(() => window.simulateCanvasFocus());
    const active = await page.evaluate(() => window.activeId());
    expect(active).toBe('the_canvas_id');
});

// ── Scenario 4 ───────────────────────────────────────────────────────────────

test('scenario 4 — rapid taps hold input focus throughout (no flicker)', async ({ page, isMobile }) => {
    test.skip(!isMobile, 'Mobile-only scenario');

    await loadPage(page, 500);
    await page.evaluate(() => window.simulateWasmInit({ keepMs: 500, focusOnTouch: true }));

    for (let i = 0; i < 3; i++) {
        await page.evaluate(() => {
            window.simulateTap();
            window.simulateCanvasFocus(); // eframe reclaim attempt between taps
        });
        const active = await page.evaluate(() => window.activeId());
        expect(active).toBe('text_agent');
    }
});

// ── Scenario 5 ───────────────────────────────────────────────────────────────

test('scenario 5 — desktop click does NOT force input focused', async ({ page, isMobile }) => {
    test.skip(!!isMobile, 'Desktop-only scenario');

    await loadPage(page, 500);
    await page.evaluate(() => window.simulateWasmInit({ keepMs: 500, focusOnTouch: false }));
    await page.evaluate(() => {
        document.getElementById('the_canvas_id')
            .dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    const active = await page.evaluate(() => window.activeId());
    expect(active).not.toBe('text_agent');
});


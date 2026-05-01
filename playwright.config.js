// @ts-check
'use strict';

const { defineConfig, devices } = require('@playwright/test');

module.exports = defineConfig({
    testDir: './src',
    testMatch: '**/*.e2e.js',
    testIgnore: ['**/*.test.js'],
    fullyParallel: false,
    forbidOnly: !!process.env.CI,
    retries: process.env.CI ? 1 : 0,
    reporter: 'list',
    use: {
        trace: 'on-first-retry',
    },
    projects: [
        {
            /* Mobile Chromium emulation — simulates touch-capable device.
             * iPhone 12 viewport/userAgent but running on Chromium (installed). */
            name: 'chromium-mobile',
            use: {
                browserName: 'chromium',
                viewport:    { width: 390, height: 844 },
                userAgent:   devices['iPhone 12'].userAgent,
                hasTouch:    true,
                isMobile:    true,
                deviceScaleFactor: 3,
            },
        },
        {
            /* Desktop Chromium — no touch. */
            name: 'chromium-desktop',
            use: {
                browserName: 'chromium',
                ...devices['Desktop Chrome'],
                hasTouch: false,
                isMobile: false,
            },
        },
    ],
});

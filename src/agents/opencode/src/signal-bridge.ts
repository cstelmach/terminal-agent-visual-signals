/**
 * TAVS - Signal Bridge
 *
 * Bridge module that connects the OpenCode plugin to the core trigger system.
 * Executes the shared trigger.sh script to send OSC escape sequences.
 */

import { execSync, spawn } from 'child_process';
import * as path from 'path';
import * as fs from 'fs';
import type { SignalState, PluginConfig } from './types';

/**
 * Find the core trigger script location
 *
 * Searches in order:
 * 1. Explicit config path
 * 2. Relative to this module (when installed in repo)
 * 3. Common installation locations
 */
function findTriggerScript(configPath?: string): string | null {
  const candidates: string[] = [];

  // 1. Explicit config path
  if (configPath) {
    candidates.push(configPath);
  }

  // 2. Relative paths (when in repo structure)
  const moduleDir = __dirname;
  candidates.push(
    path.resolve(moduleDir, '../../../core/trigger.sh'),
    path.resolve(moduleDir, '../../../../src/core/trigger.sh')
  );

  // 3. Common installation locations
  const home = process.env.HOME || process.env.USERPROFILE || '';
  candidates.push(
    path.join(home, '.claude/hooks/tavs/src/core/trigger.sh'),
    path.join(home, '.opencode/plugins/tavs/trigger.sh'),
    '/usr/local/share/tavs/trigger.sh'
  );

  // Find first existing script
  for (const candidate of candidates) {
    if (fs.existsSync(candidate)) {
      return candidate;
    }
  }

  return null;
}

/**
 * SignalBridge class
 *
 * Manages sending visual signals to the terminal via the core trigger system.
 */
export class SignalBridge {
  private triggerScript: string | null = null;
  private config: PluginConfig;
  private idleTimer: NodeJS.Timeout | null = null;
  private lastState: SignalState | null = null;

  constructor(config: PluginConfig = {}) {
    this.config = {
      enabled: true,
      idleTimeout: 30000,
      debug: false,
      ...config
    };

    this.triggerScript = findTriggerScript(config.triggerScript);

    if (this.config.debug) {
      if (this.triggerScript) {
        console.log(`[tavs] Using trigger script: ${this.triggerScript}`);
      } else {
        console.warn('[tavs] Trigger script not found - signals disabled');
      }
    }
  }

  /**
   * Send a visual signal to the terminal
   */
  sendSignal(state: SignalState): void {
    if (!this.config.enabled || !this.triggerScript) {
      return;
    }

    // Clear any pending idle timer
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }

    // Skip if same state (debounce)
    if (state === this.lastState && state !== 'processing') {
      return;
    }
    this.lastState = state;

    if (this.config.debug) {
      console.log(`[tavs] Sending signal: ${state}`);
    }

    try {
      // Use spawn for async execution (non-blocking)
      const child = spawn('bash', [this.triggerScript, state], {
        stdio: 'ignore',
        detached: true,
        timeout: 5000
      });

      // Unref to allow Node process to exit
      child.unref();
    } catch (error) {
      // Fail silently - don't break OpenCode
      if (this.config.debug) {
        console.error(`[tavs] Error sending signal:`, error);
      }
    }
  }

  /**
   * Send signal synchronously (blocks until complete)
   */
  sendSignalSync(state: SignalState): void {
    if (!this.config.enabled || !this.triggerScript) {
      return;
    }

    try {
      execSync(`bash "${this.triggerScript}" ${state}`, {
        stdio: 'ignore',
        timeout: 5000
      });
    } catch (error) {
      // Fail silently
      if (this.config.debug) {
        console.error(`[tavs] Error sending sync signal:`, error);
      }
    }
  }

  /**
   * Start the idle timer
   *
   * After completion, starts a timer that will transition to idle state.
   */
  startIdleTimer(): void {
    if (!this.config.enabled || !this.config.idleTimeout) {
      return;
    }

    // Clear existing timer
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
    }

    this.idleTimer = setTimeout(() => {
      this.sendSignal('idle');
      this.idleTimer = null;
    }, this.config.idleTimeout);
  }

  /**
   * Cancel the idle timer
   */
  cancelIdleTimer(): void {
    if (this.idleTimer) {
      clearTimeout(this.idleTimer);
      this.idleTimer = null;
    }
  }

  /**
   * Check if the bridge is operational
   */
  isAvailable(): boolean {
    return this.config.enabled === true && this.triggerScript !== null;
  }

  /**
   * Get the current configuration
   */
  getConfig(): PluginConfig {
    return { ...this.config };
  }
}

// Default singleton instance
let defaultBridge: SignalBridge | null = null;

/**
 * Get or create the default SignalBridge instance
 */
export function getSignalBridge(config?: PluginConfig): SignalBridge {
  if (!defaultBridge || config) {
    defaultBridge = new SignalBridge(config);
  }
  return defaultBridge;
}

/**
 * Convenience function to send a signal using the default bridge
 */
export function sendSignal(state: SignalState): void {
  getSignalBridge().sendSignal(state);
}

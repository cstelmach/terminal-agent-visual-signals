/**
 * TAVS - OpenCode Plugin
 *
 * Visual terminal state indicators for OpenCode (opencode.ai) sessions.
 * Changes terminal background color and title based on agent state.
 *
 * States:
 * - 🟠 Processing: Agent is working on a task
 * - 🟢 Complete: Agent finished responding
 * - 🟣 Idle: Agent waiting for input (graduated stages)
 * - Reset: Clear terminal visual state
 *
 * Note: OpenCode does not have a permission model, so the Permission (🔴)
 * and Compacting (🔄) states are not available.
 *
 * @packageDocumentation
 */

import { SignalBridge, getSignalBridge } from './signal-bridge';
import type {
  OpenCodePlugin,
  PluginConfig,
  SessionInfo,
  ToolCall,
  ToolResult,
  AgentResponse
} from './types';

// Re-export types for consumers
export * from './types';
export { SignalBridge, getSignalBridge } from './signal-bridge';

/**
 * Create the OpenCode plugin instance
 */
function createPlugin(config?: PluginConfig): OpenCodePlugin {
  const bridge = getSignalBridge(config);
  let isProcessing = false;

  return {
    name: 'tavs',

    /**
     * Session started - reset terminal state
     */
    onSessionStart(_session: SessionInfo): void {
      bridge.sendSignal('reset');
      isProcessing = false;
    },

    /**
     * Session ended - reset terminal state
     */
    onSessionEnd(_session: SessionInfo): void {
      bridge.cancelIdleTimer();
      bridge.sendSignal('reset');
      isProcessing = false;
    },

    /**
     * User submitted a prompt - start processing
     */
    onUserPrompt(_prompt: string): void {
      bridge.cancelIdleTimer();
      bridge.sendSignal('processing');
      isProcessing = true;
    },

    /**
     * Tool is being called - maintain processing state
     */
    onToolCall(_tool: ToolCall): void {
      if (!isProcessing) {
        bridge.sendSignal('processing');
        isProcessing = true;
      }
    },

    /**
     * Tool completed - maintain processing state (more tools may follow)
     */
    onToolResult(_result: ToolResult): void {
      // Stay in processing state - agent may use more tools
      if (!isProcessing) {
        bridge.sendSignal('processing');
        isProcessing = true;
      }
    },

    /**
     * Agent response received
     *
     * If done=true, transition to complete state and start idle timer.
     */
    onAgentResponse(response: AgentResponse): void {
      if (response.done) {
        bridge.sendSignal('complete');
        bridge.startIdleTimer();
        isProcessing = false;
      }
    }
  };
}

/**
 * Default plugin instance
 *
 * This is the main export that OpenCode will load.
 * Configure by adding to opencode.json or ~/.opencode/config.json:
 *
 * ```json
 * {
 *   "plugins": ["@tavs/opencode-plugin"]
 * }
 * ```
 */
const plugin = createPlugin();

export default plugin;

/**
 * Factory function for creating configured plugin instances
 *
 * Use this if you need custom configuration:
 *
 * ```typescript
 * import { createTAVSPlugin } from '@tavs/opencode-plugin';
 *
 * const plugin = createTAVSPlugin({
 *   idleTimeout: 60000,
 *   debug: true
 * });
 * ```
 */
export function createTAVSPlugin(config?: PluginConfig): OpenCodePlugin {
  return createPlugin(config);
}

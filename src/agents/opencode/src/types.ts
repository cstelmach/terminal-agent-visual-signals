/**
 * TAVS - OpenCode Plugin Types
 *
 * Type definitions for the OpenCode plugin API and internal state management.
 */

/**
 * Visual signal states that can be displayed in the terminal
 */
export type SignalState =
  | 'processing'  // Agent is working (orange)
  | 'complete'    // Agent finished (green)
  | 'idle'        // Agent waiting for input (purple, graduated)
  | 'reset';      // Clear terminal state

/**
 * OpenCode tool call information
 */
export interface ToolCall {
  name: string;
  input: Record<string, unknown>;
}

/**
 * OpenCode tool result information
 */
export interface ToolResult {
  name: string;
  output: unknown;
  error?: string;
}

/**
 * OpenCode agent response chunk
 */
export interface AgentResponse {
  content: string;
  done: boolean;
}

/**
 * OpenCode session information
 */
export interface SessionInfo {
  id: string;
  startTime: Date;
  model?: string;
}

/**
 * Plugin configuration options
 */
export interface PluginConfig {
  /** Enable/disable the plugin */
  enabled?: boolean;
  /** Path to core trigger script (auto-detected if not set) */
  triggerScript?: string;
  /** Idle timeout in milliseconds (default: 30000) */
  idleTimeout?: number;
  /** Enable debug logging */
  debug?: boolean;
}

/**
 * OpenCode plugin interface
 *
 * Defines the hooks that OpenCode will call during its lifecycle.
 */
export interface OpenCodePlugin {
  /** Plugin name for identification */
  name: string;

  /** Called when a new session starts */
  onSessionStart?(session: SessionInfo): void | Promise<void>;

  /** Called when session ends */
  onSessionEnd?(session: SessionInfo): void | Promise<void>;

  /** Called before a tool is executed */
  onToolCall?(tool: ToolCall): void | Promise<void>;

  /** Called after a tool completes */
  onToolResult?(result: ToolResult): void | Promise<void>;

  /** Called when agent produces a response (may be called multiple times for streaming) */
  onAgentResponse?(response: AgentResponse): void | Promise<void>;

  /** Called when user submits a prompt */
  onUserPrompt?(prompt: string): void | Promise<void>;
}

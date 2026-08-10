#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StreamableHTTPClientTransport } from "@modelcontextprotocol/sdk/client/streamableHttp.js";

const DEFAULT_SERVER = "microsoft-learn";
const DEFAULT_LLAMA_URL = "http://127.0.0.1:8080/v1";

function usage() {
  console.error(
    "Usage: mcp-agent [--server NAME] [--list-tools] [--call TOOL JSON] [--prompt TEXT]",
  );
  process.exit(2);
}

function parseArguments(args) {
  const result = { server: DEFAULT_SERVER };
  while (args.length > 0) {
    const argument = args.shift();
    if (argument === "--server") result.server = args.shift() ?? usage();
    else if (argument === "--list-tools") result.listTools = true;
    else if (argument === "--call") {
      result.tool = args.shift() ?? usage();
      result.arguments = args.shift() ?? usage();
    } else if (argument === "--prompt") result.prompt = args.shift() ?? usage();
    else usage();
  }
  if (Number(Boolean(result.listTools)) + Number(Boolean(result.tool)) + Number(Boolean(result.prompt)) !== 1) {
    usage();
  }
  return result;
}

async function loadConfiguration() {
  const path = process.env.MCP_CONFIG_PATH ?? "/opt/mcp/mcp.json";
  const config = JSON.parse(await readFile(path, "utf8"));
  if (!config.mcpServers || typeof config.mcpServers !== "object") {
    throw new Error(`${path} does not contain an mcpServers object`);
  }
  return config.mcpServers;
}

async function loadCredentials() {
  if (!process.env.MCP_AUTH_FILE) return {};
  return JSON.parse(await readFile(process.env.MCP_AUTH_FILE, "utf8"));
}

function tokenFor(serverName, credentials) {
  const environmentName = `MCP_AUTH_${serverName.replaceAll(/[^A-Za-z0-9]/g, "_").toUpperCase()}_TOKEN`;
  return process.env[environmentName] ?? credentials[serverName];
}

async function connect(serverName, definition, credentials) {
  if (definition.type !== "streamable-http" && definition.type !== "http") {
    throw new Error(`MCP server '${serverName}' has unsupported type '${definition.type}'`);
  }

  const token = tokenFor(serverName, credentials);
  const transport = new StreamableHTTPClientTransport(new URL(definition.url), {
    requestInit: token ? { headers: { Authorization: "Bearer " + token } } : undefined,
  });
  const client = new Client({ name: "llama-mcp-agent", version: "1.0.0" });
  await client.connect(transport);
  return { client, transport };
}

function toOpenAiTools(serverName, tools) {
  return tools.map((tool) => ({
    type: "function",
    function: {
      name: `${serverName}__${tool.name}`,
      description: tool.description,
      parameters: tool.inputSchema ?? { type: "object", properties: {} },
    },
  }));
}

async function llamaCompletion(messages, tools) {
  const baseUrl = (process.env.LLAMA_BASE_URL ?? DEFAULT_LLAMA_URL).replace(/\/$/, "");
  const model = process.env.LLAMA_MODEL_NAME ?? (await (await fetch(`${baseUrl}/models`)).json()).data?.[0]?.id;
  if (!model) throw new Error("Unable to determine the llama model; set LLAMA_MODEL_NAME");

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ model, messages, tools, tool_choice: "auto" }),
  });
  if (!response.ok) throw new Error(`llama-server returned HTTP ${response.status}: ${await response.text()}`);
  return response.json();
}

async function runAgent(serverName, client, tools, prompt) {
  const openAiTools = toOpenAiTools(serverName, tools);
  const messages = [{ role: "user", content: prompt }];

  for (let attempts = 0; attempts < 8; attempts += 1) {
    const completion = await llamaCompletion(messages, openAiTools);
    const message = completion.choices?.[0]?.message;
    if (!message) throw new Error("llama-server returned no completion message");
    messages.push(message);
    if (!message.tool_calls?.length) {
      process.stdout.write(`${message.content ?? ""}\n`);
      return;
    }

    for (const call of message.tool_calls) {
      const prefix = `${serverName}__`;
      if (!call.function.name.startsWith(prefix)) {
        throw new Error(`Model requested an unknown MCP tool '${call.function.name}'`);
      }
      const result = await client.callTool({
        name: call.function.name.slice(prefix.length),
        arguments: JSON.parse(call.function.arguments || "{}"),
      });
      messages.push({ role: "tool", tool_call_id: call.id, content: JSON.stringify(result) });
    }
  }
  throw new Error("Model exceeded the maximum of eight MCP tool-call rounds");
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  const servers = await loadConfiguration();
  const definition = servers[options.server];
  if (!definition) throw new Error(`MCP server '${options.server}' is not defined in MCP_CONFIG_PATH`);

  const credentials = await loadCredentials();
  const { client, transport } = await connect(options.server, definition, credentials);
  try {
    const { tools } = await client.listTools();
    if (options.listTools) {
      console.log(JSON.stringify({ server: options.server, tools }, null, 2));
    } else if (options.tool) {
      console.log(JSON.stringify(await client.callTool({
        name: options.tool,
        arguments: JSON.parse(options.arguments),
      }), null, 2));
    } else {
      await runAgent(options.server, client, tools, options.prompt);
    }
  } finally {
    await transport.close();
  }
}

main().catch((error) => {
  console.error(`mcp-agent: ${error.message}`);
  process.exitCode = 1;
});

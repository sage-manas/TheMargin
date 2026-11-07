import { createApp } from "./app.js";
import { loadConfig } from "./config.js";

const config = loadConfig();
const app = await createApp(config);
await app.listen(config.port);
console.log(`API listening on http://localhost:${config.port}/v1`);

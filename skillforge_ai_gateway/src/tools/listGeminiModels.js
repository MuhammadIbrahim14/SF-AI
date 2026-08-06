import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
dotenv.config({ path: path.resolve(__dirname, '../../.env'), quiet: true });

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
  console.error('GEMINI_API_KEY is not configured. Add it to skillforge_ai_gateway/.env.');
  process.exit(1);
}

const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models', {
  headers: { 'x-goog-api-key': apiKey },
});

if (!response.ok) {
  console.error(`Unable to list Gemini models. HTTP ${response.status}`);
  process.exit(1);
}

const data = await response.json();
const models = (data.models || [])
  .filter((model) => (model.supportedGenerationMethods || []).includes('generateContent'))
  .map((model) => model.name)
  .sort();

console.log(models.join('\n'));

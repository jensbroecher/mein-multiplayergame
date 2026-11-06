// Composes the game's music with ElevenLabs Music from the jobs in music.json: each job's prompt and length, always
// instrumental (forceInstrumental: the game's tracks have no vocals or lyrics), saved as MP3 at its path under the
// project. Jobs whose file exists already are skipped (--force makes them again). The key comes from the environment
// (ELEVENLABS_API_KEY, in .env.local, which git ignores): never put it in code. From the project root:
//   node --env-file=.env.local tools/elevenlabs/generate_music.mjs [--force] [--list] [name ...]
// Then import the new files (Godot --headless --path . --import) and add them to MusicManager.STAGE_TRACKS.
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { createWriteStream, existsSync, mkdirSync, readFileSync, statSync } from "fs";
import { dirname, join, resolve } from "path";
import { Readable } from "stream";
import { pipeline } from "stream/promises";
import { fileURLToPath } from "url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const jobs = JSON.parse(readFileSync(join(here, "music.json"), "utf8"));
const args = process.argv.slice(2);
const force = args.includes("--force");
const wanted = args.filter((a) => !a.startsWith("--"));

if (args.includes("--list")) {
  for (const j of jobs) {
    const out = join(root, j.path);
    console.log(`${j.name.padEnd(22)} ${existsSync(out) ? "made " : "to do"} ${j.seconds}s  ${j.path}`);
  }
  process.exit(0);
}

const client = new ElevenLabsClient();

for (const job of jobs) {
  if (wanted.length && !wanted.includes(job.name)) continue;
  const out = join(root, job.path);
  if (existsSync(out) && !force) {
    console.log(`skip ${job.name}: ${job.path} exists (--force to make it again)`);
    continue;
  }
  mkdirSync(dirname(out), { recursive: true });
  try {
    const request = {
      prompt: job.prompt,
      musicLengthMs: Math.round(job.seconds * 1000),
      forceInstrumental: true,
      outputFormat: "mp3_44100_192",
    };
    if (job.model) request.modelId = job.model;
    const audio = await client.music.compose(request);
    const source = typeof audio.pipe === "function" ? audio : Readable.fromWeb(audio);
    await pipeline(source, createWriteStream(out));
    console.log(`made ${job.name}: ${job.path} (${(statSync(out).size / 1024).toFixed(0)} KB)`);
  } catch (e) {
    console.error(`FAILED ${job.name}: ${e?.statusCode ?? ""} ${e?.message ?? e}`);
    if (e?.body) console.error(JSON.stringify(e.body).slice(0, 600));
    process.exitCode = 1;
  }
}

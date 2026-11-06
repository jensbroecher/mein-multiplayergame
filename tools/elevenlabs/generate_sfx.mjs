// Generates the game's sound effects with ElevenLabs' text to sound effects (SFX v3) from the jobs in sfx.json: each
// job's prompt, length and whether it loops (a seamless loop), saved as WAV (44.1kHz) at its path under the project.
// Jobs whose file exists already are skipped (--force makes them again). The key comes from the environment
// (ELEVENLABS_API_KEY, in .env.local, which git ignores): never put it in code. From the project root:
//   node --env-file=.env.local tools/elevenlabs/generate_sfx.mjs [--force] [--list] [name ...]
// Then import the new files (Godot --headless --path . --import) and measure their levels before using them
// (scratch/measure_clip_rms.gd).
import { ElevenLabsClient } from "@elevenlabs/elevenlabs-js";
import { createWriteStream, existsSync, mkdirSync, readFileSync, statSync } from "fs";
import { dirname, join, resolve } from "path";
import { Readable } from "stream";
import { pipeline } from "stream/promises";
import { fileURLToPath } from "url";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..", "..");
const jobs = JSON.parse(readFileSync(join(here, "sfx.json"), "utf8"));
const args = process.argv.slice(2);
const force = args.includes("--force");
const wanted = args.filter((a) => !a.startsWith("--"));

if (args.includes("--list")) {
  for (const j of jobs) {
    const out = join(root, j.path);
    console.log(`${j.name.padEnd(18)} ${existsSync(out) ? "made " : "to do"} ${j.duration}s${j.loop ? " loop" : ""}  ${j.path}`);
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
    const audio = await client.textToSoundEffects.convert({
      text: job.text,
      modelId: "eleven_text_to_sound_v3",
      durationSeconds: job.duration,
      promptInfluence: job.influence ?? 0.3,
      loop: Boolean(job.loop),
      outputFormat: "wav_44100",
    });
    // The SDK hands back a stream (a web one in recent versions, a Node one in older).
    const source = typeof audio.pipe === "function" ? audio : Readable.fromWeb(audio);
    await pipeline(source, createWriteStream(out));
    console.log(`made ${job.name}: ${job.path} (${(statSync(out).size / 1024).toFixed(0)} KB)`);
  } catch (e) {
    console.error(`FAILED ${job.name}: ${e?.statusCode ?? ""} ${e?.message ?? e}`);
    process.exitCode = 1;
  }
}

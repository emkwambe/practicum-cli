// Generates content/ids.lock.json and content/manifest.json.
//
// IDs are <course-slug>/<type>/<slug>, e.g. linux-foundations/lesson/pwd.
// They must never change once published: progress_state rows key on them.
//
// Permanence lives in content/ids.lock.json (id -> current path), not in the
// file layout. The generator:
//   1. reads the lock,
//   2. carries every existing ID forward, updating only its path,
//   3. mints IDs only for files it has never seen,
//   4. fails hard on any within-course collision.
// A moved or renamed file keeps its ID as long as its course, type and slug
// are unchanged; a file that disappears is kept in the lock and marked
// missing, so its historical progress rows stay meaningful.
//
// Run: npm run manifest

import { readdirSync, statSync, readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const COURSES_DIR = join(ROOT, "courses");
const LOCK_PATH = join(ROOT, "content", "ids.lock.json");
const MANIFEST_PATH = join(ROOT, "content", "manifest.json");

const dirs = (p) => {
  try {
    return readdirSync(p).filter((f) => statSync(join(p, f)).isDirectory());
  } catch {
    return [];
  }
};
const files = (p) => {
  try {
    return readdirSync(p).filter((f) => statSync(join(p, f)).isFile());
  } catch {
    return [];
  }
};

const dayNum = (d) => Number.parseInt(d.replace(/^day/, ""), 10) || 0;
const lessonSlug = (file) => file.replace(/\.txt$/, "").replace(/^lesson\d+_?/, "") || file.replace(/\.txt$/, "");

const lessonTitle = (path, slug) => {
  try {
    for (const line of readFileSync(path, "utf8").split(/\r?\n/).slice(0, 12)) {
      const m = line.match(/^#\s+(?:Lesson:\s*)?(.+?)\s*$/);
      if (m) return m[1];
    }
  } catch { /* fall through to slug */ }
  return slug;
};

const courseNames = (() => {
  const names = {};
  try {
    const src = readFileSync(join(ROOT, "lib", "lessons.sh"), "utf8");
    const block = src.slice(src.indexOf("get_course_name()"));
    for (const m of block.matchAll(/^\s*([a-z0-9][a-z0-9-]*)\)\s*echo\s+"([^"]+)"/gm)) names[m[1]] = m[2];
  } catch { /* fall back to slugs */ }
  return names;
})();

const dayTitles = (courseDir) => {
  const titles = {};
  try {
    readFileSync(join(courseDir, "day_titles.txt"), "utf8").split(/\r?\n/).forEach((line, i) => {
      if (line.trim()) titles[i + 1] = line.trim();
    });
  } catch { /* optional file */ }
  return titles;
};

const LAB_KINDS = [
  { match: /^final_capstone_test\.sh$/, slug: "final-capstone", title: "Final Capstone" },
  { match: /^capstone_test\.sh$/, slug: "capstone", title: "Capstone" },
  { match: /^assess2_test\.sh$/, slug: "assessment-2", title: "Assessment 2" },
  { match: /^assess(?:ment)?1?_test\.sh$/, slug: "assessment-1", title: "Assessment 1" },
];

// --- 1. walk the content -----------------------------------------------------

const discovered = []; // { course, type, slug, id, path, title, day }

for (const course of dirs(COURSES_DIR).sort()) {
  const courseDir = join(COURSES_DIR, course);
  for (const day of dirs(courseDir).filter((d) => /^day\d+$/.test(d)).sort((a, b) => dayNum(a) - dayNum(b))) {
    const dayDir = join(courseDir, day);

    for (const f of files(dayDir).filter((f) => /^lesson\d+.*\.txt$/.test(f)).sort()) {
      const slug = lessonSlug(f);
      discovered.push({
        course, type: "lesson", slug,
        id: `${course}/lesson/${slug}`,
        path: `courses/${course}/${day}/${f}`,
        title: lessonTitle(join(dayDir, f), slug),
        day: dayNum(day),
      });
    }

    for (const f of files(dayDir).filter((f) => f.endsWith(".sh")).sort()) {
      const kind = LAB_KINDS.find((k) => k.match.test(f));
      const slug = kind ? kind.slug : f.replace(/\.sh$/, "");
      discovered.push({
        course, type: "lab", slug,
        id: `${course}/lab/${slug}`,
        path: `courses/${course}/${day}/${f}`,
        title: kind ? kind.title : slug,
        day: dayNum(day),
      });
    }
  }
}

// --- 2. collision report -----------------------------------------------------

const byId = new Map();
for (const item of discovered) {
  if (!byId.has(item.id)) byId.set(item.id, []);
  byId.get(item.id).push(item);
}
const collisions = [...byId.entries()].filter(([, items]) => items.length > 1);

console.log(`scanned ${discovered.length} content files across ${new Set(discovered.map((d) => d.course)).size} courses`);
if (collisions.length) {
  console.error(`\nCOLLISION REPORT — ${collisions.length} id(s) claimed by more than one file:\n`);
  for (const [id, items] of collisions) {
    console.error(`  ${id}`);
    for (const i of items) console.error(`      ${i.path}`);
  }
  console.error(
    `\nIDs are permanent, so this cannot be auto-resolved: rename one of the files,\n` +
    `or give it a distinct slug, then re-run. Nothing was written.\n`,
  );
  process.exit(1);
}
console.log("collision report: none");

// --- 3. lock: carry IDs forward, mint only for new files ---------------------

const lock = existsSync(LOCK_PATH)
  ? JSON.parse(readFileSync(LOCK_PATH, "utf8"))
  : { version: 1, note: "id -> path. IDs are permanent; never edit or delete an entry by hand.", ids: {} };

const seen = new Set();
let carried = 0, minted = 0, moved = 0;

for (const item of discovered) {
  seen.add(item.id);
  const existing = lock.ids[item.id];
  if (!existing) {
    lock.ids[item.id] = { path: item.path, type: item.type, course: item.course, first_seen: new Date().toISOString().slice(0, 10) };
    minted++;
  } else {
    if (existing.path !== item.path) {
      existing.previous_path = existing.path;
      existing.path = item.path;
      moved++;
    }
    delete existing.missing_since;
    carried++;
  }
}

// An ID whose file is gone stays in the lock: old progress rows still refer to it.
let missing = 0;
for (const [id, entry] of Object.entries(lock.ids)) {
  if (!seen.has(id)) {
    if (!entry.missing_since) entry.missing_since = new Date().toISOString().slice(0, 10);
    missing++;
  }
}

mkdirSync(dirname(LOCK_PATH), { recursive: true });
writeFileSync(LOCK_PATH, JSON.stringify(lock, null, 2) + "\n", "utf8");

// --- 4. manifest, built from the lock ---------------------------------------

const courses = [];
for (const course of [...new Set(discovered.map((d) => d.course))].sort()) {
  const courseDir = join(COURSES_DIR, course);
  const titles = dayTitles(courseDir);
  const items = discovered.filter((d) => d.course === course);
  const days = [];

  for (const day of [...new Set(items.map((i) => i.day))].sort((a, b) => a - b)) {
    const inDay = items.filter((i) => i.day === day);
    days.push({
      day,
      title: titles[day] || `day${day}`,
      lessons: inDay.filter((i) => i.type === "lesson").map(({ id, title, path }) => ({ id, title, file: lock.ids[id].path ?? path })),
      labs: inDay.filter((i) => i.type === "lab").map(({ id, title, path }) => ({ id, title, file: lock.ids[id].path ?? path })),
    });
  }

  courses.push({ id: course, title: courseNames[course] || course, free: course === "00-cli-immersion", days });
}

const counts = courses.reduce(
  (a, c) => {
    a.lessons += c.days.reduce((n, d) => n + d.lessons.length, 0);
    a.labs += c.days.reduce((n, d) => n + d.labs.length, 0);
    return a;
  },
  { courses: courses.length, lessons: 0, labs: 0 },
);

writeFileSync(
  MANIFEST_PATH,
  JSON.stringify({ version: 1, generated_from: "content/ids.lock.json", counts, courses }, null, 2) + "\n",
  "utf8",
);

console.log(`lock: ${carried} carried, ${minted} minted, ${moved} path updated, ${missing} missing`);
console.log(`manifest: ${counts.courses} courses, ${counts.lessons} lessons, ${counts.labs} labs`);
console.log("\n10 sample IDs:");
for (const item of discovered.filter((_, i) => i % Math.floor(discovered.length / 10) === 0).slice(0, 10)) {
  console.log(`  ${item.id.padEnd(46)} ${item.path}`);
}

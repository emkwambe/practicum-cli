// Generates content/manifest.json — the single source of stable content IDs.
//
// The repo has no IDs today: lessons are identified only by file path, and 9
// lesson basenames repeat across courses. IDs are therefore derived from
// course + day + lesson slug, which is unique and stable as long as a file is
// not renamed or moved. Once published these IDs are permanent: renaming a
// lesson file is a breaking change to learner progress.
//
//   course   <course-slug>                        e.g. linux-foundations
//   lesson   <course-slug>/dayN/lesson/<slug>     e.g. linux-foundations/day1/lesson/pwd
//   lab      <course-slug>/dayN/lab/<slug>        e.g. linux-foundations/day5/lab/capstone
//
// The type segment is load-bearing: shell-mastery/day8 holds both
// lesson2_capstone.txt and capstone_test.sh, which would otherwise share an ID.
//
// Run: npm run manifest

import { readdirSync, statSync, readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const COURSES_DIR = join(ROOT, "courses");
const OUT = join(ROOT, "content", "manifest.json");

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

// "lesson3_cd.txt" → "cd";  "lesson1_actions_intro.txt" → "actions_intro"
const lessonSlug = (file) => file.replace(/\.txt$/, "").replace(/^lesson\d+_?/, "") || file.replace(/\.txt$/, "");

// First "# Lesson: ..." or "# ..." heading, else the slug.
const lessonTitle = (path, slug) => {
  try {
    for (const line of readFileSync(path, "utf8").split(/\r?\n/).slice(0, 12)) {
      const m = line.match(/^#\s+(?:Lesson:\s*)?(.+?)\s*$/);
      if (m) return m[1];
    }
  } catch { /* fall through to slug */ }
  return slug;
};

// Course display names, read from the CLI's own mapping so the two never drift.
const courseNames = (() => {
  const names = {};
  try {
    const src = readFileSync(join(ROOT, "lib", "lessons.sh"), "utf8");
    const block = src.slice(src.indexOf("get_course_name()"));
    for (const m of block.matchAll(/^\s*([a-z0-9][a-z0-9-]*)\)\s*echo\s+"([^"]+)"/gm)) {
      names[m[1]] = m[2];
    }
  } catch { /* fall back to slugs */ }
  return names;
})();

const dayTitles = (courseDir) => {
  const titles = {};
  try {
    const lines = readFileSync(join(courseDir, "day_titles.txt"), "utf8").split(/\r?\n/);
    lines.forEach((line, i) => {
      if (line.trim()) titles[i + 1] = line.trim();
    });
  } catch { /* optional file */ }
  return titles;
};

// Lab-type content: the assessment and capstone scripts that gate a course.
const LAB_KINDS = [
  { match: /^capstone_test\.sh$/, slug: "capstone", title: "Capstone" },
  { match: /^final_capstone_test\.sh$/, slug: "final-capstone", title: "Final Capstone" },
  { match: /^assess2_test\.sh$/, slug: "assessment-2", title: "Assessment 2" },
  { match: /^assess(?:ment)?1?_test\.sh$/, slug: "assessment-1", title: "Assessment 1" },
];

const courses = [];
for (const slug of dirs(COURSES_DIR).sort()) {
  const courseDir = join(COURSES_DIR, slug);
  const titles = dayTitles(courseDir);
  const days = [];

  for (const day of dirs(courseDir).filter((d) => /^day\d+$/.test(d)).sort((a, b) => dayNum(a) - dayNum(b))) {
    const dayDir = join(courseDir, day);
    const entry = { day: dayNum(day), title: titles[dayNum(day)] || day, lessons: [], labs: [] };

    for (const f of files(dayDir).filter((f) => /^lesson\d+.*\.txt$/.test(f)).sort()) {
      const s = lessonSlug(f);
      entry.lessons.push({
        id: `${slug}/${day}/lesson/${s}`,
        title: lessonTitle(join(dayDir, f), s),
        file: `courses/${slug}/${day}/${f}`,
      });
    }

    for (const f of files(dayDir).filter((f) => f.endsWith(".sh")).sort()) {
      const kind = LAB_KINDS.find((k) => k.match.test(f));
      const s = kind ? kind.slug : f.replace(/\.sh$/, "");
      entry.labs.push({
        id: `${slug}/${day}/lab/${s}`,
        title: kind ? kind.title : s,
        file: `courses/${slug}/${day}/${f}`,
      });
    }

    if (entry.lessons.length || entry.labs.length) days.push(entry);
  }

  if (days.length) {
    courses.push({ id: slug, title: courseNames[slug] || slug, free: slug === "00-cli-immersion", days });
  }
}

const counts = courses.reduce(
  (a, c) => {
    a.lessons += c.days.reduce((n, d) => n + d.lessons.length, 0);
    a.labs += c.days.reduce((n, d) => n + d.labs.length, 0);
    return a;
  },
  { courses: courses.length, lessons: 0, labs: 0 },
);

// Fail loudly rather than publish colliding IDs — progress rows key on them.
const seen = new Set();
const dupes = [];
for (const c of courses) {
  for (const d of c.days) {
    for (const item of [...d.lessons, ...d.labs]) {
      if (seen.has(item.id)) dupes.push(item.id);
      seen.add(item.id);
    }
  }
}
if (dupes.length) {
  console.error(`Duplicate content IDs: ${dupes.join(", ")}`);
  process.exit(1);
}

mkdirSync(dirname(OUT), { recursive: true });
writeFileSync(OUT, JSON.stringify({ version: 1, generated_from: "courses/", counts, courses }, null, 2) + "\n", "utf8");
console.log(`manifest: ${counts.courses} courses, ${counts.lessons} lessons, ${counts.labs} labs → content/manifest.json`);

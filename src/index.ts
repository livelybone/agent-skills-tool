#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import os from "node:os";
import { spawn } from "node:child_process";
import { Command } from "commander";
import matter from "gray-matter";
import semver from "semver";
import inquirer from "inquirer";

type InstallOptions = {
  skillPath: string | undefined;
  subdir?: string;
  ref?: string;
  destinationProjectPath?: string;
  force: boolean;
  merge: boolean;
};

type InstallTarget = {
  label: string;
  baseDir: string;
};

type RepoSpec = {
  repoUrl: string;
  ref?: string;
  subdir?: string;
};

type ResolveResult = {
  skillDir: string;
  cleanup?: () => Promise<void>;
};

const program = new Command();

program
  .name("agent-skills-tool")
  .description("Install Agent Skills into Codex, Claude Code, and Gemini scopes")
  .option("-i, --install <skillPath>", "Path to a skill directory (or SKILL.md)")
  .option("--subdir <path>", "Skill directory within a repository")
  .option("--ref <ref>", "Git ref when installing from a repository")
  .option("--force", "Overwrite existing skill directories")
  .option("--merge", "Merge into existing skill directories, overwriting files")
  .argument("[destinationProjectPath]", "Project root path for project-scoped install")
  .action(async (destinationProjectPath: string | undefined, options) => {
    try {
      await runInstall({
        skillPath: options.install,
        subdir: options.subdir,
        ref: options.ref,
        destinationProjectPath,
        force: Boolean(options.force),
        merge: Boolean(options.merge)
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`Error: ${message}`);
      process.exit(1);
    }
  });

program.parse(process.argv);

async function runInstall({
  skillPath,
  subdir,
  ref,
  destinationProjectPath,
  force,
  merge
}: InstallOptions): Promise<void> {
  if (!skillPath) {
    program.help({ error: true });
    return;
  }

  if (force && merge) {
    throw new Error("--force and --merge cannot be used together");
  }

  const resolvedSkillPath: string = skillPath;
  const skillInput = isRepoLike(resolvedSkillPath)
    ? resolvedSkillPath
    : path.resolve(resolvedSkillPath);
  const { skillDir, cleanup } = await resolveSkillSource(skillInput, { subdir, ref });

  try {
    const skillFile = path.join(skillDir, "SKILL.md");
    const skillContents = await fs.readFile(skillFile, "utf8");
    const { data: frontmatter } = matter(skillContents);

    validateFrontmatter(frontmatter, skillFile);

    const skillName = String(frontmatter.name).trim();
    const skillDirName = path.basename(skillDir);
    if (skillDirName !== skillName) {
      console.warn(
        `Warning: skill directory name "${skillDirName}" does not match SKILL.md name "${skillName}". Using SKILL.md name for install.`
      );
    }

    const targets = getInstallTargets(destinationProjectPath);

    for (const target of targets) {
      const targetRoot = target.baseDir;
      const targetSkillDir = path.join(targetRoot, skillName);

      await fs.mkdir(targetRoot, { recursive: true });

      const exists = await pathExists(targetSkillDir);
      let action: "overwrite" | "merge" | "skip" = "overwrite";

      if (exists && !force && !merge) {
        action = await promptConflictAction(target.label, targetSkillDir);
      } else if (exists && merge) {
        action = "merge";
      } else if (exists && force) {
        action = "overwrite";
      } else if (!exists) {
        action = "overwrite";
      }

      if (action === "skip") {
        console.log(`Skipped ${target.label}: ${targetSkillDir}`);
        continue;
      }

      if (action === "overwrite") {
        await fs.rm(targetSkillDir, { recursive: true, force: true });
        await copyDir(skillDir, targetSkillDir);
        console.log(`Installed (${target.label}) -> ${targetSkillDir}`);
        continue;
      }

      if (action === "merge") {
        await copyDir(skillDir, targetSkillDir);
        console.log(`Merged (${target.label}) -> ${targetSkillDir}`);
        continue;
      }
    }
  } finally {
    if (cleanup) {
      await cleanup();
    }
  }
}

async function resolveSkillSource(
  resolvedSkillPath: string,
  { subdir, ref }: { subdir?: string; ref?: string }
): Promise<ResolveResult> {
  const repoSpec = parseRepoSpec(resolvedSkillPath);
  if (repoSpec) {
    if (subdir && repoSpec.subdir) {
      throw new Error("Provide either --subdir or a repo URL with a path, not both");
    }
    const repoSubdir = repoSpec.subdir || subdir || "";
    const cloneDir = await fs.mkdtemp(path.join(os.tmpdir(), "agent-skill-"));
    await cloneRepo(repoSpec.repoUrl, cloneDir, ref || repoSpec.ref);
    const skillDir = await resolveSkillDirFromBase(
      cloneDir,
      repoSubdir ? repoSubdir : null
    );
    return {
      skillDir,
      cleanup: async () => {
        await fs.rm(cloneDir, { recursive: true, force: true });
      }
    };
  }

  const stat = await fs.stat(resolvedSkillPath).catch(() => null);
  if (!stat) {
    throw new Error(`Skill path not found: ${resolvedSkillPath}`);
  }

  if (stat.isFile()) {
    if (path.basename(resolvedSkillPath) !== "SKILL.md") {
      throw new Error("Skill file must be named SKILL.md");
    }
    return { skillDir: path.dirname(resolvedSkillPath) };
  }

  if (!stat.isDirectory()) {
    throw new Error("Skill path must be a directory or SKILL.md file");
  }

  const skillDir = await resolveSkillDirFromBase(resolvedSkillPath, subdir || null);
  return { skillDir };
}

async function resolveSkillDirFromBase(
  baseDir: string,
  subdir: string | null
): Promise<string> {
  const skillDir = subdir ? path.join(baseDir, subdir) : baseDir;
  const skillFile = path.join(skillDir, "SKILL.md");
  const skillFileStat = await fs.stat(skillFile).catch(() => null);
  if (!skillFileStat || !skillFileStat.isFile()) {
    const extra = subdir ? ` (subdir: ${subdir})` : "";
    throw new Error(`SKILL.md not found in ${skillDir}${extra}`);
  }
  return skillDir;
}

function validateFrontmatter(
  frontmatter: Record<string, unknown>,
  skillFile: string
): void {
  if (!frontmatter || typeof frontmatter !== "object") {
    throw new Error(`Missing YAML frontmatter in ${skillFile}`);
  }

  const name = String(frontmatter.name || "").trim();
  const description = String(frontmatter.description || "").trim();
  const metadata =
    frontmatter.metadata && typeof frontmatter.metadata === "object"
      ? (frontmatter.metadata as Record<string, unknown>)
      : null;
  const version = String(metadata?.version || "").trim();

  if (!name) {
    throw new Error(`Missing required frontmatter field "name" in ${skillFile}`);
  }

  if (!description) {
    throw new Error(`Missing required frontmatter field "description" in ${skillFile}`);
  }

  if (!version) {
    throw new Error(
      `Missing required frontmatter field "metadata.version" in ${skillFile}`
    );
  }

  if (!semver.valid(version)) {
    throw new Error(`Invalid semver "metadata.version" in ${skillFile}: ${version}`);
  }
}

function getInstallTargets(destinationProjectPath?: string): InstallTarget[] {
  const targets: InstallTarget[] = [];

  if (destinationProjectPath) {
    const projectRoot = path.resolve(destinationProjectPath);

    targets.push({
      label: "codex-project",
      baseDir: path.join(projectRoot, ".codex", "skills")
    });
    targets.push({
      label: "claude-project",
      baseDir: path.join(projectRoot, ".claude", "skills")
    });
    targets.push({
      label: "gemini-project",
      baseDir: path.join(projectRoot, ".gemini", "skills")
    });

    return targets;
  }

  const homeDir = os.homedir();
  const codexHome = process.env.CODEX_HOME
    ? path.resolve(process.env.CODEX_HOME)
    : path.join(homeDir, ".codex");

  targets.push({
    label: "codex-user",
    baseDir: path.join(codexHome, "skills")
  });
  targets.push({
    label: "claude-user",
    baseDir: path.join(homeDir, ".claude", "skills")
  });
  targets.push({
    label: "gemini-user",
    baseDir: path.join(homeDir, ".gemini", "skills")
  });

  return targets;
}

async function promptConflictAction(
  label: string,
  targetSkillDir: string
): Promise<"overwrite" | "merge" | "skip"> {
  const answers = await inquirer.prompt<{ action: "overwrite" | "merge" | "skip" }>([
    {
      type: "list",
      name: "action",
      message: `Conflict detected for ${label}: ${targetSkillDir}`,
      choices: [
        { name: "Overwrite (delete existing and reinstall)", value: "overwrite" },
        { name: "Merge (overwrite files, keep extra files)", value: "merge" },
        { name: "Cancel for this target", value: "skip" }
      ]
    }
  ]);

  return answers.action;
}

async function copyDir(sourceDir: string, targetDir: string): Promise<void> {
  await fs.mkdir(targetDir, { recursive: true });
  await fs.cp(sourceDir, targetDir, {
    recursive: true,
    force: true,
    errorOnExist: false
  });
}

async function pathExists(targetPath: string): Promise<boolean> {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

function isRepoLike(input: string): boolean {
  if (!input) {
    return false;
  }
  if (input.startsWith("http://") || input.startsWith("https://")) {
    return true;
  }
  if (input.endsWith(".git")) {
    return true;
  }
  return /^[\w.-]+\/[\w.-]+$/.test(input);
}

function parseRepoSpec(input: string): RepoSpec | null {
  if (!input) {
    return null;
  }

  if (input.startsWith("http://") || input.startsWith("https://")) {
    try {
      const url = new URL(input);
      if (url.hostname === "github.com") {
        const githubSpec = parseGitHubUrl(url);
        if (githubSpec) {
          return githubSpec;
        }
      }
      return { repoUrl: input };
    } catch {
      return null;
    }
  }

  if (input.endsWith(".git")) {
    return { repoUrl: input };
  }

  if (/^[\w.-]+\/[\w.-]+$/.test(input)) {
    return { repoUrl: `https://github.com/${input}.git` };
  }

  return null;
}

function parseGitHubUrl(url: URL): RepoSpec | null {
  const segments = url.pathname.replace(/^\//, "").split("/");
  if (segments.length < 2) {
    return null;
  }

  const owner = segments[0];
  const repo = segments[1];
  let ref: string | undefined;
  let subdir: string | undefined;

  if (segments[2] === "tree" || segments[2] === "blob") {
    ref = segments[3];
    subdir = segments.slice(4).join("/");
    if (subdir && subdir.endsWith("SKILL.md")) {
      subdir = path.posix.dirname(subdir);
    }
  }

  return {
    repoUrl: `https://github.com/${owner}/${repo}.git`,
    ref,
    subdir
  };
}

async function cloneRepo(repoUrl: string, targetDir: string, ref?: string): Promise<void> {
  const args = ["clone", "--depth", "1"];
  if (ref) {
    args.push("--branch", ref, "--single-branch");
  }
  args.push(repoUrl, targetDir);
  await runGit(args);
}

function runGit(args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn("git", args, { stdio: "inherit" });
    child.on("error", (error) => {
      if ((error as NodeJS.ErrnoException).code === "ENOENT") {
        reject(new Error("git is required to install from a repository"));
        return;
      }
      reject(error);
    });
    child.on("close", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`git exited with code ${code}`));
    });
  });
}

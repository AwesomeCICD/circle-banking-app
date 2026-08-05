#!/usr/bin/env python3
"""Assert safety properties of `circleci config process` output.

Uses only the Python standard library: the processed config is parsed by a
minimal YAML-subset reader that covers the block mappings, block sequences and
block scalars the CircleCI CLI emits.
"""

import sys


def _indent_of(line):
    return len(line) - len(line.lstrip(" "))


def _scalar(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "'\"":
        return text[1:-1]
    return text


class _Reader:
    def __init__(self, text):
        self.lines = text.splitlines()
        self.i = 0

    def _skip_blanks(self):
        while self.i < len(self.lines):
            stripped = self.lines[self.i].strip()
            if stripped == "" or stripped.startswith("#"):
                self.i += 1
            else:
                return

    def _block_scalar(self, indent):
        collected = []
        while self.i < len(self.lines):
            line = self.lines[self.i]
            if line.strip() == "":
                collected.append("")
                self.i += 1
                continue
            if _indent_of(line) <= indent:
                break
            collected.append(line)
            self.i += 1
        if not collected:
            return ""
        body = [ln for ln in collected if ln.strip() != ""]
        strip = min(_indent_of(ln) for ln in body)
        return "\n".join(ln[strip:] if ln.strip() else "" for ln in collected)

    def parse(self, indent):
        self._skip_blanks()
        if self.i >= len(self.lines):
            return None
        if self.lines[self.i].lstrip(" ").startswith("- "):
            return self._sequence(indent)
        return self._mapping(indent)

    def _sequence(self, indent):
        items = []
        while True:
            self._skip_blanks()
            if self.i >= len(self.lines):
                break
            line = self.lines[self.i]
            if _indent_of(line) != indent or not line.lstrip(" ").startswith("- "):
                break
            content = line[indent + 2 :]
            if ":" in content and not content.lstrip().startswith("#"):
                key, _, rest = content.partition(":")
                if rest.strip() == "" or rest.startswith(" "):
                    self.lines[self.i] = " " * (indent + 2) + content
                    items.append(self._mapping(indent + 2))
                    continue
            self.i += 1
            items.append(_scalar(content))
        return items

    def _mapping(self, indent):
        result = {}
        while True:
            self._skip_blanks()
            if self.i >= len(self.lines):
                break
            line = self.lines[self.i]
            if _indent_of(line) < indent:
                break
            if _indent_of(line) > indent or line.lstrip(" ").startswith("- "):
                break
            key, _, rest = line.strip().partition(":")
            key = _scalar(key)
            rest = rest.strip()
            self.i += 1
            if rest in ("|", "|-", ">", ">-"):
                result[key] = self._block_scalar(indent)
            elif rest == "":
                nested = self._peek_nested(indent)
                result[key] = nested
            else:
                result[key] = _scalar(rest)
        return result

    def _peek_nested(self, indent):
        self._skip_blanks()
        if self.i >= len(self.lines):
            return None
        line = self.lines[self.i]
        child_indent = _indent_of(line)
        if child_indent < indent:
            return None
        if line.lstrip(" ").startswith("- ") and child_indent == indent:
            return self._sequence(indent)
        if child_indent <= indent:
            return None
        if line.lstrip(" ").startswith("- "):
            return self._sequence(child_indent)
        return self._mapping(child_indent)


def load(path):
    with open(path, encoding="utf-8") as handle:
        return _Reader(handle.read()).parse(0)


FAILURES = []


def check(condition, message):
    if not condition:
        FAILURES.append(message)


def workflow_jobs(config, workflow):
    entries = config.get("workflows", {}).get(workflow, {}).get("jobs", []) or []
    jobs = {}
    for entry in entries:
        if isinstance(entry, str):
            jobs[entry] = {}
        elif isinstance(entry, dict):
            for name, attrs in entry.items():
                jobs[name] = attrs if isinstance(attrs, dict) else {}
    return jobs


def transitive_requires(jobs, name, seen=None):
    seen = set() if seen is None else seen
    for dep in jobs.get(name, {}).get("requires", []) or []:
        if dep in seen:
            continue
        seen.add(dep)
        transitive_requires(jobs, dep, seen)
    return seen


def run_commands(config):
    commands = []
    for job_name, job in (config.get("jobs") or {}).items():
        if not isinstance(job, dict):
            continue
        for step in job.get("steps", []) or []:
            if not isinstance(step, dict):
                continue
            run = step.get("run")
            if isinstance(run, str):
                commands.append((job_name, run))
            elif isinstance(run, dict) and isinstance(run.get("command"), str):
                commands.append((job_name, run["command"]))
    return commands


def environments(config):
    values = []
    for job in (config.get("jobs") or {}).values():
        if not isinstance(job, dict):
            continue
        for step in job.get("steps", []) or []:
            run = step.get("run") if isinstance(step, dict) else None
            if isinstance(run, dict) and isinstance(run.get("environment"), dict):
                values.extend(str(v) for v in run["environment"].values())
    return values


def main():
    deploy_only_path, default_path, malicious = sys.argv[1:4]
    deploy_only = load(deploy_only_path)
    default = load(default_path)

    jobs = workflow_jobs(deploy_only, "deploy-only")

    check(
        jobs.get("approve-deploy-only", {}).get("type") == "approval",
        "approve-deploy-only is not declared as type: approval",
    )

    deploy_deps = transitive_requires(jobs, "deploy-existing-artifact")
    check(
        "approve-deploy-only" in deploy_deps,
        "deploy-existing-artifact does not require approve-deploy-only "
        f"(resolved requires: {sorted(deploy_deps)})",
    )

    verify_deps = transitive_requires(jobs, "verify-deployed-artifact")
    check(
        "deploy-existing-artifact" in verify_deps,
        "verify-deployed-artifact does not require deploy-existing-artifact "
        f"(resolved requires: {sorted(verify_deps)})",
    )

    deploy_attrs = jobs.get("deploy-existing-artifact", {})
    lock_jobs = {n for n, a in jobs.items() if a.get("type") in ("lock", "unlock")}
    serialized = bool(deploy_attrs.get("serial-group")) or bool(
        deploy_attrs.get("serial-group-ids")
    ) or bool(lock_jobs & (deploy_deps | {"deploy-existing-artifact"}))
    check(serialized, "deploy-existing-artifact is not serialized (no serial-group or lock job)")

    for job_name, command in run_commands(deploy_only):
        check(
            malicious not in command,
            f"malicious parameter content leaked into shell command of job {job_name}",
        )
        check(
            "<< pipeline.parameters" not in command,
            f"unexpanded pipeline parameter interpolation in shell command of job {job_name}",
        )

    check(
        any(malicious in value for value in environments(deploy_only)),
        "malicious parameter content was not passed through a run step environment map",
    )

    default_jobs = set((default.get("jobs") or {}).keys())
    deploy_only_jobs = set((deploy_only.get("jobs") or {}).keys())
    check(
        "java-test-and-code-cov" in default_jobs,
        "default config is missing java-test-and-code-cov",
    )
    check(
        "validate-deploy-request" not in default_jobs,
        "default config unexpectedly contains validate-deploy-request",
    )
    for job in (
        "validate-deploy-request",
        "deploy-existing-artifact",
        "verify-deployed-artifact",
    ):
        check(job in deploy_only_jobs, f"deploy-only config is missing {job}")
    check(
        "approve-deploy-only" in jobs,
        "deploy-only workflow is missing approve-deploy-only",
    )
    check(
        "java-test-and-code-cov" not in deploy_only_jobs,
        "deploy-only config unexpectedly contains java-test-and-code-cov",
    )

    if FAILURES:
        for failure in FAILURES:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("PASS: processed config safety properties")
    return 0


if __name__ == "__main__":
    sys.exit(main())

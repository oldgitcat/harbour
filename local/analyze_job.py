#!/usr/bin/env python3
"""Summarize OpenCode tool durations and token usage for a Harbor job."""

from __future__ import annotations

import collections
import json
import statistics
import sys
from pathlib import Path


def analyze_log(path: Path) -> dict:
    tools: dict[str, dict[str, float]] = collections.defaultdict(
        lambda: {"calls": 0, "total_ms": 0.0, "durations": []}
    )
    tokens = collections.Counter()
    cost = 0.0
    timestamps: list[float] = []

    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        timestamp = event.get("timestamp")
        if isinstance(timestamp, (int, float)):
            timestamps.append(float(timestamp))

        if event.get("type") == "tool_use":
            part = event.get("part") or {}
            state = part.get("state") or {}
            timing = state.get("time") or {}
            start, end = timing.get("start"), timing.get("end")
            if not isinstance(start, (int, float)) or not isinstance(end, (int, float)):
                continue
            name = str(part.get("tool") or "unknown")
            duration = max(0.0, float(end) - float(start))
            tools[name]["calls"] += 1
            tools[name]["total_ms"] += duration
            tools[name]["durations"].append(duration)

        if event.get("type") == "step_finish":
            part = event.get("part") or {}
            token_data = part.get("tokens") or {}
            for key in ("input", "output", "reasoning", "total"):
                value = token_data.get(key)
                if isinstance(value, (int, float)):
                    tokens[key] += int(value)
            cache = token_data.get("cache") or {}
            for key in ("read", "write"):
                value = cache.get(key)
                if isinstance(value, (int, float)):
                    tokens[f"cache_{key}"] += int(value)
            value = part.get("cost")
            if isinstance(value, (int, float)):
                cost += float(value)

    wall_ms = (max(timestamps) - min(timestamps)) if len(timestamps) >= 2 else 0.0
    tool_ms = sum(item["total_ms"] for item in tools.values())
    return {
        "log": str(path),
        "tool_calls": sum(item["calls"] for item in tools.values()),
        "tool_time_ms": round(tool_ms, 1),
        "wall_time_ms": round(wall_ms, 1),
        "non_tool_time_ms": round(max(0.0, wall_ms - tool_ms), 1),
        "tokens": dict(tokens),
        "cost_usd": round(cost, 8),
        "tools": {
            name: {
                "calls": item["calls"],
                "total_ms": round(item["total_ms"], 1),
                "avg_ms": round(statistics.mean(item["durations"]), 1),
                "max_ms": round(max(item["durations"]), 1),
            }
            for name, item in sorted(tools.items())
        },
    }


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {Path(sys.argv[0]).name} <job-directory>", file=sys.stderr)
        return 2

    job_dir = Path(sys.argv[1]).resolve()
    if not job_dir.is_dir():
        print(f"not a directory: {job_dir}", file=sys.stderr)
        return 2

    results = []
    for log_path in sorted(job_dir.glob("*/agent/opencode.txt")):
        result = analyze_log(log_path)
        result["trial"] = log_path.parents[1].name
        results.append(result)

    if not results:
        print(f"no agent/opencode.txt files under {job_dir}", file=sys.stderr)
        return 1

    output_path = job_dir / "tool_usage.json"
    output_path.write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")

    print(f"\nTool usage: {output_path}")
    print(f"{'trial':<48} {'calls':>5} {'tool_s':>8} {'wall_s':>8}")
    for result in results:
        print(
            f"{result['trial']:<48} {result['tool_calls']:>5} "
            f"{result['tool_time_ms'] / 1000:>8.2f} "
            f"{result['wall_time_ms'] / 1000:>8.2f}"
        )

    aggregate: dict[str, dict[str, float]] = collections.defaultdict(
        lambda: {"calls": 0, "total_ms": 0.0}
    )
    for result in results:
        for name, item in result["tools"].items():
            aggregate[name]["calls"] += item["calls"]
            aggregate[name]["total_ms"] += item["total_ms"]

    print("\nTools:")
    for name, item in sorted(aggregate.items()):
        print(
            f"  {name:<20} {int(item['calls']):>3} calls  "
            f"{item['total_ms'] / 1000:>7.2f}s"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

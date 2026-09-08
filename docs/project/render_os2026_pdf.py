# -*- coding: utf-8 -*-
"""Render OS2026 作品介绍 Markdown to print HTML, then Edge PDF."""
from __future__ import annotations

import base64
import html
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MD_PATH = ROOT / "os2026-作品介绍.md"
HTML_PATH = ROOT / "os2026-作品介绍.html"
PDF_PATH = ROOT / "os2026-作品介绍.pdf"
FIG1 = ROOT / "os2026-figures" / "fig1-call-chain.svg"
FIG2 = ROOT / "os2026-figures" / "fig2-dual-channel.svg"
FIG3 = ROOT / "os2026-figures" / "fig3-storage.png"
FIG4 = ROOT / "os2026-figures" / "fig4-audit.png"
EDGE = Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe")
if not EDGE.exists():
    EDGE = Path(r"C:\Program Files\Microsoft\Edge\Application\msedge.exe")

FIG1_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 300" role="img" aria-label="fig1">
  <style>
    .box { fill: #f7f9fc; stroke: #1e3a5f; stroke-width: 1.4; }
    .box-core { fill: #eef3f8; stroke: #1e3a5f; stroke-width: 1.6; }
    .box-fact { fill: #e8f0e8; stroke: #2d5a2d; stroke-width: 1.3; }
    .box-llm { fill: #f4eee6; stroke: #6a4b1f; stroke-width: 1.3; }
    .t { font-family: SimHei, Microsoft YaHei, sans-serif; fill: #1a1a1a; }
    .arrow { stroke: #1e3a5f; stroke-width: 1.6; fill: none; marker-end: url(#arr); }
  </style>
  <defs>
    <marker id="arr" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 z" fill="#1e3a5f"/>
    </marker>
  </defs>
  <rect x="8" y="18" width="170" height="56" rx="4" class="box"/>
  <text x="93" y="42" text-anchor="middle" class="t" font-size="13">agent1-web</text>
  <text x="93" y="60" text-anchor="middle" class="t" font-size="11">Vue 3 SPA</text>
  <line x1="178" y1="46" x2="228" y2="46" class="arrow"/>
  <rect x="232" y="18" width="190" height="56" rx="4" class="box"/>
  <text x="327" y="42" text-anchor="middle" class="t" font-size="13">Agent1.Api</text>
  <text x="327" y="60" text-anchor="middle" class="t" font-size="11">ASP.NET Core 8</text>
  <line x1="422" y1="46" x2="472" y2="46" class="arrow"/>
  <rect x="476" y="8" width="268" height="76" rx="4" class="box-core"/>
  <text x="610" y="38" text-anchor="middle" class="t" font-size="13">Agent1 \u6838\u5fc3\u5e93</text>
  <text x="610" y="58" text-anchor="middle" class="t" font-size="11">C# / .NET 8 \u00b7 \u53cc\u901a\u9053</text>
  <line x1="560" y1="84" x2="560" y2="108" class="arrow"/>
  <line x1="660" y1="84" x2="660" y2="108" class="arrow"/>
  <rect x="476" y="112" width="128" height="50" rx="4" class="box-fact"/>
  <text x="540" y="133" text-anchor="middle" class="t" font-size="12">\u4e8b\u5b9e\u901a\u9053</text>
  <text x="540" y="150" text-anchor="middle" class="t" font-size="11">C# \u786e\u5b9a\u6027\u4ee3\u7801</text>
  <rect x="616" y="112" width="128" height="50" rx="4" class="box-llm"/>
  <text x="680" y="133" text-anchor="middle" class="t" font-size="12">\u89e3\u91ca\u901a\u9053</text>
  <text x="680" y="150" text-anchor="middle" class="t" font-size="11">LLM \u89e3\u8bfb\u5efa\u8bae</text>
  <rect x="8" y="210" width="228" height="56" rx="4" class="box"/>
  <text x="122" y="234" text-anchor="middle" class="t" font-size="12">PostgreSQL 16 + pgvector</text>
  <text x="122" y="252" text-anchor="middle" class="t" font-size="11">\u5b58\u50a8\u4e0e\u5411\u91cf\u68c0\u7d22</text>
  <rect x="260" y="210" width="228" height="56" rx="4" class="box"/>
  <text x="374" y="234" text-anchor="middle" class="t" font-size="12">llama.cpp</text>
  <text x="374" y="252" text-anchor="middle" class="t" font-size="11">\u5b8c\u6574\u90e8\u7f72 \u00b7 \u8fd0\u884c\u65f6\u81ea\u5907</text>
  <rect x="512" y="210" width="232" height="56" rx="4" class="box-fact"/>
  <text x="628" y="234" text-anchor="middle" class="t" font-size="12">\u89c4\u5219\u5f15\u64ce</text>
  <text x="628" y="252" text-anchor="middle" class="t" font-size="11">\u65e0 GPU \u6f14\u793a \u00b7 \u4e0d\u542f\u63a8\u7406</text>
  <text x="20" y="198" class="t" font-size="10" fill="#444">\u5165\u53e3\uff1aWeb SPA \u00b7 REST API \u00b7 \u63a7\u5236\u53f0\uff08\u8bc4\u59d4\u7528 Web + API\uff09</text>
</svg>
"""

FIG2_SVG = """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 760 390" role="img" aria-label="fig2">
  <style>
    .box { fill: #f7f9fc; stroke: #1e3a5f; stroke-width: 1.3; }
    .warn { fill: #f8ecec; stroke: #8a3030; stroke-width: 1.4; }
    .ok { fill: #e8f0e8; stroke: #2d5a2d; stroke-width: 1.3; }
    .llm { fill: #f4eee6; stroke: #6a4b1f; stroke-width: 1.3; }
    .t { font-family: SimHei, Microsoft YaHei, sans-serif; fill: #1a1a1a; }
    .arrow { stroke: #1e3a5f; stroke-width: 1.5; fill: none; marker-end: url(#arr2); }
  </style>
  <defs>
    <marker id="arr2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto">
      <path d="M0,0 L8,4 L0,8 z" fill="#1e3a5f"/>
    </marker>
  </defs>
  <rect x="250" y="8" width="260" height="40" rx="4" class="box"/>
  <text x="380" y="33" text-anchor="middle" class="t" font-size="13">IntentRouter.Route()</text>
  <line x1="380" y1="48" x2="380" y2="68" class="arrow"/>
  <rect x="200" y="70" width="360" height="44" rx="4" class="box"/>
  <text x="380" y="89" text-anchor="middle" class="t" font-size="13">Semantic Kernel Auto Function Calling</text>
  <text x="380" y="106" text-anchor="middle" class="t" font-size="11">\u9009\u62e9\u5408\u89c4\u5de5\u5177\uff08\u7981\u914d / \u7c7b\u522b / \u8ddd\u79bb\uff09</text>
  <line x1="380" y1="114" x2="380" y2="136" class="arrow"/>
  <rect x="220" y="138" width="320" height="40" rx="4" class="box"/>
  <text x="380" y="163" text-anchor="middle" class="t" font-size="13">toolCalls \u662f\u5426\u4e3a\u7a7a\uff1f</text>
  <line x1="220" y1="158" x2="90" y2="158" class="arrow"/>
  <line x1="540" y1="158" x2="670" y2="158" class="arrow"/>
  <text x="128" y="150" class="t" font-size="11" fill="#8a3030">\u4e3a\u7a7a \u00b7 \u8fdd\u7ea6</text>
  <text x="548" y="150" class="t" font-size="11" fill="#2d5a2d">\u6709\u5de5\u5177\u8fd4\u56de</text>
  <rect x="8" y="180" width="200" height="88" rx="4" class="warn"/>
  <text x="108" y="206" text-anchor="middle" class="t" font-size="12">\u4e22\u5f03\u5168\u90e8 LLM \u8f93\u51fa</text>
  <text x="108" y="226" text-anchor="middle" class="t" font-size="12">\u786e\u5b9a\u6027\u515c\u5e95</text>
  <text x="108" y="248" text-anchor="middle" class="t" font-size="11">DeterministicRuleEngine</text>
  <rect x="552" y="180" width="200" height="88" rx="4" class="ok"/>
  <text x="652" y="204" text-anchor="middle" class="t" font-size="12">\u4e8b\u5b9e\u901a\u9053</text>
  <text x="652" y="222" text-anchor="middle" class="t" font-size="11">Extractor \u2192 Sanitizer</text>
  <text x="652" y="238" text-anchor="middle" class="t" font-size="11">\u2192 FactAssembler</text>
  <text x="652" y="256" text-anchor="middle" class="t" font-size="11">RegulationRefs \u767d\u540d\u5355</text>
  <rect x="276" y="196" width="208" height="56" rx="4" class="llm"/>
  <text x="380" y="220" text-anchor="middle" class="t" font-size="12">\u89e3\u91ca\u901a\u9053\uff08LLM\uff09</text>
  <text x="380" y="238" text-anchor="middle" class="t" font-size="11">\u4e13\u4e1a\u89e3\u8bfb / \u5efa\u8bae / \u6ce8\u610f</text>
  <line x1="108" y1="268" x2="108" y2="310" class="arrow"/>
  <line x1="380" y1="252" x2="380" y2="310" class="arrow"/>
  <line x1="652" y1="268" x2="652" y2="310" class="arrow"/>
  <line x1="108" y1="318" x2="652" y2="318" stroke="#1e3a5f" stroke-width="1.3" fill="none"/>
  <rect x="230" y="332" width="300" height="46" rx="4" class="box"/>
  <text x="380" y="351" text-anchor="middle" class="t" font-size="13">ResponseMerger \u5408\u5e76\u8f93\u51fa</text>
  <text x="380" y="368" text-anchor="middle" class="t" font-size="11">\u65e0 GPU\uff1aLLM_OPTIONAL=true\uff0c\u4e0d\u542f llama.cpp</text>
</svg>
"""


CSS = r"""
@page {
  size: A4;
  margin: 1.8cm 2.5cm 1.8cm 2.5cm;
}
* { box-sizing: border-box; }
html, body {
  margin: 0;
  padding: 0;
  font-family: SimSun, "Songti SC", serif;
  font-size: 12pt;
  line-height: 1.3;
  color: #1a1a1a;
}
h1, h2, h3 {
  font-family: SimHei, "Microsoft YaHei", sans-serif;
  font-weight: normal;
  page-break-after: avoid;
  line-height: 1.35;
}
h1 { font-size: 16pt; text-align: center; margin: 0 0 8pt; }
h2 { font-size: 13.5pt; margin: 9pt 0 5pt; border-bottom: 0.6pt solid #1e3a5f; padding-bottom: 2pt; }
h3 { font-size: 12pt; margin: 9pt 0 5pt; }
p { margin: 0 0 6pt; text-align: justify; }
ul, ol { margin: 0 0 8pt; padding-left: 1.6em; }
li { margin-bottom: 3pt; }
strong { font-family: SimHei, "Microsoft YaHei", sans-serif; font-weight: normal; }
a { color: inherit; text-decoration: none; }
code {
  font-family: Consolas, "Courier New", monospace;
  font-size: 10pt;
  background: #f3f3f3;
  padding: 0 2pt;
}
pre {
  font-family: Consolas, "Courier New", monospace;
  font-size: 9pt;
  line-height: 1.32;
  background: #f6f6f6;
  border: 0.4pt solid #ccc;
  padding: 6pt 8pt;
  white-space: pre-wrap;
  word-break: break-all;
  page-break-inside: auto;
  margin: 0 0 8pt;
}
pre code { background: none; padding: 0; font-size: inherit; }
table {
  width: 100%;
  border-collapse: collapse;
  margin: 0 0 8pt;
  font-size: 10pt;
  page-break-inside: auto;
}
th, td {
  border: 0.4pt solid #555;
  padding: 4pt 6pt;
  vertical-align: top;
  text-align: left;
}
th {
  font-family: SimHei, "Microsoft YaHei", sans-serif;
  background: #eef2f6;
}
.cover {
  page-break-after: auto;
  padding-top: 6mm;
  text-align: center;
}
.cover .kicker {
  font-family: SimHei, "Microsoft YaHei", sans-serif;
  font-size: 11pt;
  margin-bottom: 8pt;
  letter-spacing: 0;
}
.cover h1 { font-size: 18pt; line-height: 1.35; margin: 8pt 0 6pt; }
.cover .sub { font-size: 13pt; margin-bottom: 8pt; }
.cover .tagline {
  margin: 8pt auto 10pt;
  max-width: 94%;
  text-align: center;
  line-height: 1.55;
}
.cover table { text-align: left; margin-top: 8pt; font-size: 10.5pt; }
.cover th { width: 26%; }
.toc { page-break-after: auto; margin-top: 8pt; }
.toc h2 { margin-top: 2pt; }
.toc ul { font-size: 11pt; margin: 0 0 6pt; columns: 2; column-gap: 16pt; }
.figure {
  margin: 6pt 0 8pt;
  page-break-inside: avoid;
  text-align: center;
}
.figure svg { width: 100%; height: auto; max-height: 40mm; }
.figure img { width: 100%; height: auto; max-height: 88mm; object-fit: contain; border: 0.4pt solid #bbb; }
.caption {
  font-size: 10.5pt;
  margin-top: 4pt;
  text-align: center;
  font-family: SimHei, "Microsoft YaHei", sans-serif;
}
.fig-note { font-size: 10pt; color: #333; text-align: justify; margin: 0 0 10pt; }
.placeholder {
  border: 0.8pt dashed #666;
  background: #fafafa;
  min-height: 16mm;
  display: flex;
  flex-direction: column;
  justify-content: center;
  align-items: center;
  padding: 6pt;
  margin: 3pt 0 2pt;
}
.placeholder .ph-title {
  font-family: SimHei, "Microsoft YaHei", sans-serif;
  font-size: 12pt;
  margin-bottom: 6pt;
}
.placeholder .ph-body { font-size: 10.5pt; color: #444; }
hr.sep { border: none; border-top: 0.4pt solid #ccc; margin: 14pt 0; }
"""


def inline_md(text: str) -> str:
    text = html.escape(text)

    def code_repl(m: re.Match[str]) -> str:
        return f"<code>{m.group(1)}</code>"

    text = re.sub(r"`([^`]+)`", code_repl, text)
    text = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", text)
    text = re.sub(
        r"(https://gitee\.com/liuchao_yue/agent-system)",
        r'<a href="\1">\1</a>',
        text,
    )
    return text


def parse_table(lines: list[str]) -> str:
    rows = []
    for line in lines:
        if re.match(r"^\s*\|?\s*-{2,}", line.replace("|", " | ")):
            if set(line.replace("|", "").replace(":", "").replace("-", "").replace(" ", "")) == set():
                continue
        if "---" in line and re.match(r"^\s*\|?\s*:?-{2,}", line):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        rows.append(cells)
    if not rows:
        return ""
    out = ["<table>"]
    for i, cells in enumerate(rows):
        tag = "th" if i == 0 else "td"
        out.append("<tr>" + "".join(f"<{tag}>{inline_md(c)}</{tag}>" for c in cells) + "</tr>")
    out.append("</table>")
    return "\n".join(out)


def is_table_line(line: str) -> bool:
    return line.strip().startswith("|") and line.strip().endswith("|")


def fig_html(num: int, title: str, inner: str, note: str | None = None) -> str:
    parts = [
        '<div class="figure">',
        inner,
        f'<div class="caption">图 {num}　{html.escape(title)}</div>',
        "</div>",
    ]
    if note:
        parts.append(f'<p class="fig-note">图注：{inline_md(note)}</p>')
    return "\n".join(parts)


def img_file(path: Path, alt: str) -> str:
    raw = path.read_bytes()
    b64 = base64.b64encode(raw).decode("ascii")
    return f'<img src="data:image/png;base64,{b64}" alt="{html.escape(alt)}"/>'


def placeholder(title: str, body: str) -> str:
    return (
        '<div class="placeholder">'
        f'<div class="ph-title">{html.escape(title)}</div>'
        f'<div class="ph-body">{html.escape(body)}</div>'
        "</div>"
    )


def convert(md: str) -> str:
    fig1 = FIG1_SVG
    fig2 = FIG2_SVG
    lines = md.replace("\r\n", "\n").split("\n")
    # drop trailing horizontal rules used as md separators between chapters
    body_html: list[str] = []
    i = 0
    n = len(lines)
    skip_next_ascii_fig1 = False
    cover_done = False
    toc_mode = False

    def flush_para(buf: list[str]) -> None:
        text = "".join(buf).strip()
        if text:
            body_html.append(f"<p>{inline_md(text)}</p>")

    while i < n:
        line = lines[i]
        stripped = line.strip()

        if stripped == "---":
            i += 1
            continue

        if stripped.startswith("**【图 1"):
            body_html.append(
                fig_html(
                    1,
                    "系统调用链",
                    fig1,
                    "Web 到 API 再到核心库；事实通道与解释通道分离；演示档用规则引擎，完整部署才加载 llama.cpp。",
                )
            )
            skip_next_ascii_fig1 = True
            i += 1
            continue

        if stripped.startswith("**【图 2"):
            body_html.append(
                fig_html(
                    2,
                    "双通道与 Function Calling 违约处理",
                    fig2,
                    "事实通道与解释通道分离；toolCalls 为空则丢弃全部 LLM 输出并改确定性兜底；无 GPU 时直接进入规则引擎。",
                )
            )
            i += 1
            # skip following 图注 line; already in caption
            if i < n and lines[i].strip().startswith("图注："):
                i += 1
            continue

        if stripped.startswith("**【图 3"):
            inner = (
                img_file(FIG3, "储存兼容性：甲醇与硝酸禁止同库，GB 15603")
                if FIG3.exists()
                else placeholder(
                    "储存兼容性页（演示截图占位）",
                    "甲醇 × 硝酸　禁止同库　GB 15603",
                )
            )
            note = "演示环境截图，种子库规则引擎，非生产数据。"
            if i + 1 < n and "图注：" in lines[i + 1]:
                raw = lines[i + 1].split("图注：", 1)[-1].strip()
                # keep required phrase at front
                if "演示环境截图，种子库规则引擎，非生产数据" in raw:
                    note = raw
                i += 1
            body_html.append(fig_html(3, "储存兼容性页", inner, note))
            i += 1
            continue

        if stripped.startswith("**【图 4") or "**【图 4" in stripped:
            inner = (
                img_file(FIG4, "审计日志与哈希链")
                if FIG4.exists()
                else placeholder("审计日志或登录角色（演示截图占位）", "admin 登录后的 /audit")
            )
            note = "演示环境截图，非生产数据。本稿为占位，交稿前替换为 demo 真实截图。"
            if stripped.startswith("**【图 4"):
                i += 1
                while i < n and not lines[i].strip():
                    i += 1
                if i < n and lines[i].strip().startswith("图注："):
                    note = lines[i].split("图注：", 1)[-1].strip()
                    i += 1
            body_html.append(fig_html(4, "审计日志或登录角色", inner, note))
            continue

        if stripped.startswith("图注：") and body_html and "figure" in body_html[-1]:
            i += 1
            continue

        if stripped.startswith("```"):
            lang = stripped[3:].strip()
            i += 1
            code_lines: list[str] = []
            while i < n and not lines[i].strip().startswith("```"):
                code_lines.append(lines[i])
                i += 1
            if i < n:
                i += 1
            if skip_next_ascii_fig1:
                skip_next_ascii_fig1 = False
                continue
            code = html.escape("\n".join(code_lines))
            body_html.append(f'<pre><code class="{html.escape(lang)}">{code}</code></pre>')
            continue

        if stripped.startswith("## "):
            title = stripped[3:].strip()
            if title == "目录":
                toc_mode = True
                body_html.append('<div class="toc"><h2>目录</h2>')
            else:
                if toc_mode:
                    body_html.append("</div>")
                    toc_mode = False
                body_html.append(f"<h2>{inline_md(title)}</h2>")
            i += 1
            continue

        if stripped.startswith("### "):
            body_html.append(f"<h3>{inline_md(stripped[4:].strip())}</h3>")
            i += 1
            continue

        if stripped.startswith("# "):
            # cover title already handled if first; keep as h1 only on cover
            if not cover_done:
                cover_done = True
            i += 1
            continue

        if is_table_line(stripped):
            tbl = [stripped]
            i += 1
            while i < n and is_table_line(lines[i].strip()):
                tbl.append(lines[i].strip())
                i += 1
            body_html.append(parse_table(tbl))
            continue

        if re.match(r"^\d+\.\s+", stripped):
            items: list[str] = []
            while i < n:
                s = lines[i]
                st = s.strip()
                m = re.match(r"^(\d+)\.\s+(.*)$", st)
                if m and not s.startswith(" "):
                    items.append(m.group(2))
                    i += 1
                    continue
                if items and (s.startswith("   ") or s.startswith("\t")) and st.startswith("- "):
                    extra = st[2:]
                    if items[-1].endswith(("：", ":", "；", ";", "。")):
                        items[-1] += extra
                    else:
                        items[-1] += "；" + extra
                    i += 1
                    continue
                break
            body_html.append(
                "<ol>" + "".join(f"<li>{inline_md(it)}</li>" for it in items) + "</ol>"
            )
            continue

        if stripped.startswith("- "):
            items = []
            while i < n and lines[i].strip().startswith("- "):
                items.append(lines[i].strip()[2:])
                i += 1
            body_html.append("<ul>" + "".join(f"<li>{inline_md(it)}</li>" for it in items) + "</ul>")
            continue

        if not stripped:
            i += 1
            continue

        # paragraph: join wrapped lines until blank
        buf = [stripped]
        i += 1
        while i < n:
            nxt = lines[i]
            ns = nxt.strip()
            if not ns or ns.startswith("#") or ns.startswith("```") or ns.startswith("|") or ns.startswith("- ") or re.match(r"^\d+\.\s+", ns) or ns == "---" or ns.startswith("**【图"):
                break
            if ns.startswith("图注："):
                break
            buf.append(ns)
            i += 1
        text = " ".join(buf)
        body_html.append(f"<p>{inline_md(text)}</p>")

    if toc_mode:
        body_html.append("</div>")

    return "\n".join(body_html)


def build_cover_and_body(md: str) -> str:
    """Split cover fields from rest; rest starts at ## 目录."""
    idx = md.find("## 目录")
    rest = md[idx:]
    inner = convert(rest)
    cover = f"""
<div class="cover">
  <div class="kicker">2026 上海开源软件应用创新大赛　OS2026</div>
  <h1>仓卫 — 化工园区危化品合规审查 AI Agent</h1>
  <div class="sub">作品介绍</div>
  <p>赛道：AI+工业软件　·　开源协议：MIT　·　默认分支：master</p>
  <p class="tagline">法规条款、储存禁忌和安全距离由确定性代码给出，大模型只解释和建议。<br>
  LLM 不可用时，门卫 + 责任链 + 规则引擎仍给出可审计结论。</p>
  <table>
    <tr><th>作品中文名</th><td>仓卫 — 化工园区危化品合规审查 AI Agent</td></tr>
    <tr><th>赛道</th><td>AI+工业软件</td></tr>
    <tr><th>开源协议</th><td>MIT（仓库根目录 LICENSE）</td></tr>
    <tr><th>代码仓库</th><td>https://gitee.com/liuchao_yue/agent-system</td></tr>
    <tr><th>默认分支</th><td>master</td></tr>
    <tr><th>演示视频</th><td>https://gitee.com/liuchao_yue/agent-system/releases/tag/os2026-demo</td></tr>
    <tr><th>团队负责人</th><td>刘超越</td></tr>
    <tr><th>团队成员</th><td>个人项目，招募中</td></tr>
  </table>
</div>
"""
    return cover + inner


def wrap_html(inner: str) -> str:
    return f"""<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8"/>
<title>仓卫 作品介绍 · OS2026 AI+工业软件</title>
<style>{CSS}</style>
</head>
<body>
{inner}
</body>
</html>
"""


def fix_ordered_lists(md_html: str) -> str:
    return md_html


def print_pdf(html_path: Path, pdf_path: Path) -> None:
    if not EDGE.exists():
        raise SystemExit(f"Edge not found: {EDGE}")
    tmp_html = ROOT / "_os2026_print.html"
    tmp_pdf = ROOT / "_os2026_print.pdf"
    tmp_html.write_bytes(html_path.read_bytes())
    if tmp_pdf.exists():
        tmp_pdf.unlink()
    html_uri = tmp_html.resolve().as_uri()
    user_dir = Path(tempfile.mkdtemp(prefix="edge-pdf-"))
    cmd = [
        str(EDGE),
        "--headless=new",
        "--disable-gpu",
        "--no-first-run",
        "--no-pdf-header-footer",
        f"--user-data-dir={user_dir}",
        f"--print-to-pdf={tmp_pdf}",
        "--virtual-time-budget=20000",
        html_uri,
    ]
    print("Edge print-to-pdf ...")
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if r.returncode != 0:
        print(r.stdout)
        print(r.stderr, file=sys.stderr)
        raise SystemExit(r.returncode)
    if not tmp_pdf.exists() or tmp_pdf.stat().st_size < 1000:
        raise SystemExit(
            f"PDF missing or too small: {tmp_pdf} "
            f"{tmp_pdf.stat().st_size if tmp_pdf.exists() else 0}"
        )
    pdf_path.write_bytes(tmp_pdf.read_bytes())
    tmp_html.unlink(missing_ok=True)
    tmp_pdf.unlink(missing_ok=True)


def stamp_header_footer(pdf_path: Path) -> None:
    try:
        import pymupdf as fitz
    except ImportError:
        import fitz  # type: ignore

    header = "仓卫 作品介绍 · OS2026 AI+工业软件"
    footer = "gitee.com/liuchao_yue/agent-system"
    fontfile = Path(r"C:\Windows\Fonts\simhei.ttf")
    if not fontfile.exists():
        fontfile = Path(r"C:\Windows\Fonts\msyh.ttc")

    doc = fitz.open(pdf_path)
    for i, page in enumerate(doc, start=1):
        r = page.rect
        left, right = 71, r.width - 71
        gray = (0.2, 0.2, 0.2)
        page.draw_line(
            fitz.Point(left, 32),
            fitz.Point(right, 32),
            color=gray,
            width=0.4,
        )
        page.insert_text(
            fitz.Point(left, 24),
            header,
            fontsize=9,
            fontfile=str(fontfile) if fontfile.exists() else None,
            fontname="helv" if not fontfile.exists() else "fhei",
            color=gray,
        )
        page.draw_line(
            fitz.Point(left, r.height - 32),
            fitz.Point(right, r.height - 32),
            color=gray,
            width=0.4,
        )
        page.insert_text(
            fitz.Point(left, r.height - 22),
            footer,
            fontsize=8,
            fontname="helv",
            color=gray,
        )
        label = f"{i} / {len(doc)}"
        page.insert_text(
            fitz.Point(right - 36, r.height - 22),
            label,
            fontsize=8,
            fontname="helv",
            color=gray,
        )
    try:
        doc.subset_fonts()
    except Exception:
        pass
    tmp = pdf_path.with_name("_os2026_stamped.pdf")
    doc.save(tmp, garbage=4, deflate=True, clean=True)
    doc.close()
    pdf_path.write_bytes(tmp.read_bytes())
    tmp.unlink(missing_ok=True)


def main() -> None:
    (ROOT / "os2026-figures").mkdir(exist_ok=True)
    FIG1.write_text(FIG1_SVG, encoding="utf-8")
    FIG2.write_text(FIG2_SVG, encoding="utf-8")
    md = MD_PATH.read_text(encoding="utf-8")
    inner = build_cover_and_body(md)
    html_doc = wrap_html(inner)
    HTML_PATH.write_text(html_doc, encoding="utf-8")
    print("Wrote", HTML_PATH)
    print_pdf(HTML_PATH, PDF_PATH)
    stamp_header_footer(PDF_PATH)
    print("Wrote", PDF_PATH, "size", PDF_PATH.stat().st_size)


if __name__ == "__main__":
    main()

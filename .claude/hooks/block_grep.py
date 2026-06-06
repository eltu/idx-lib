#!/usr/bin/env python3
"""Hook PreToolUse: bloqueia grep/rg/ag/awk/sed para buscas em arquivos do projeto.
Permite uso em pipes (cmd | grep) pois esses não são buscas de conteúdo.
"""
import json
import re
import sys

BLOCKED = re.compile(r"(?<!\|)\s*\b(grep|rg|\bag\b|ack|awk|sed)\b(?!\s*['\"])")
PIPE_USE = re.compile(r"\|\s*(grep|awk|sed)\b")

data = json.load(sys.stdin)
cmd = data.get("tool_input", {}).get("command", "")

if BLOCKED.search(cmd) and not PIPE_USE.search(cmd):
    print(json.dumps({
        "continue": False,
        "stopReason": (
            "Use idx search para buscar conteúdo em arquivos do projeto.\n"
            "Exemplo: idx search --compact -e go \"termo\"\n"
            "Flags úteis: -p <path>, --hits, --any, -l"
        )
    }))
else:
    print(json.dumps({"continue": True}))

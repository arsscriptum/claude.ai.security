#!/usr/bin/env bash

# Usage: ./check_claude_security.sh /path/to/projects

set -euo pipefail

PROJECTS_ROOT="${1:?Usage: $0 <projects_root>}"
COMPROMISED_AXIOS=("1.14.1" "0.30.4")
MALICIOUS_DEP="plain-crypto-js"
LOCKFILES=("package-lock.json" "yarn.lock" "bun.lockb")
ISSUES=()

RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m'

# ── 1. Claude Code installation check ────────────────────────────────────────
echo -e "\n${CYAN}=== Claude Code Installation ===${NC}"

if command -v claude &>/dev/null; then
    CLAUDE_PATH=$(command -v claude)
    CLAUDE_VER=$(claude --version 2>&1 || true)
    echo -e "${YELLOW}[FOUND] Claude Code at: ${CLAUDE_PATH}${NC}"
    echo         "        Version : ${CLAUDE_VER}"

    if echo "${CLAUDE_PATH}" | grep -qE 'npm|node_modules'; then
        echo -e "${YELLOW}[WARN]  Installed via npm. Switch to the native installer:${NC}"
        echo    "        curl -fsSL https://claude.ai/install.sh | bash"
        ISSUES+=("Claude Code installed via npm (use native installer instead)")
    else
        echo -e "${GREEN}[OK]    Not npm-based install.${NC}"
    fi
else
    echo -e "${GREEN}[OK]    Claude Code not installed.${NC}"
fi

# ── 2. Lockfile scan ─────────────────────────────────────────────────────────
echo -e "\n${CYAN}=== Scanning lockfiles under: ${PROJECTS_ROOT} ===${NC}"

LOCKFILE_PATTERN=$(IFS='|'; echo "${LOCKFILES[*]}" | sed 's/|/\\|/g')

mapfile -t FOUND_LOCKFILES < <(
    find "${PROJECTS_ROOT}" -type f \( \
        -name "package-lock.json" -o \
        -name "yarn.lock"         -o \
        -name "bun.lockb"         \
    \) 2>/dev/null
)

if [[ ${#FOUND_LOCKFILES[@]} -eq 0 ]]; then
    echo -e "${GREEN}[OK]    No lockfiles found.${NC}"
fi

for lf in "${FOUND_LOCKFILES[@]}"; do
    echo -e "${GRAY}[SCAN]  ${lf}${NC}"
    clean=true

    for ver in "${COMPROMISED_AXIOS[@]}"; do
        if grep -qF "${ver}" "${lf}" 2>/dev/null; then
            msg="Compromised axios ${ver} in: ${lf}"
            echo -e "${RED}[!!!]   ${msg}${NC}"
            ISSUES+=("${msg}")
            clean=false
        fi
    done

    if grep -qF "${MALICIOUS_DEP}" "${lf}" 2>/dev/null; then
        msg="Malicious dep '${MALICIOUS_DEP}' in: ${lf}"
        echo -e "${RED}[!!!]   ${msg}${NC}"
        ISSUES+=("${msg}")
        clean=false
    fi

    if [[ "${clean}" == true ]]; then
        echo -e "${GREEN}[OK]    Clean.${NC}"
    fi
done

# ── 3. Summary ───────────────────────────────────────────────────────────────
echo -e "\n${CYAN}=== Summary ===${NC}"

if [[ ${#ISSUES[@]} -eq 0 ]]; then
    echo -e "${GREEN}[OK]    No issues found.${NC}"
else
    echo -e "${RED}[!!!]   ${#ISSUES[@]} issue(s) found:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "${RED}        - ${issue}${NC}"
    done
    echo -e "\n${RED}[ACTION REQUIRED]${NC}"
    echo    "  1. Treat the machine as fully compromised"
    echo    "  2. Rotate ALL credentials, tokens, and secrets immediately"
    echo    "  3. Consider a clean OS reinstall"
fi
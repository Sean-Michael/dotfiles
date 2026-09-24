eval "$(oh-my-posh init zsh --config ~/repos/dotfiles/oh-my-posh/powerlevel10k_rainbow.omp.json)"

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/smr/.lmstudio/bin"
# End of LM Studio CLI section

export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH=/Users/smr/.opencode/bin:$PATH

# bun completions
[ -s "/Users/smr/.bun/_bun" ] && source "/Users/smr/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export PATH=$PATH:$HOME/.maestro/bin
# ---- ai: local LLM command assistant ----
# Hits Ollama on caliban via Tailscale. Falls back to localhost if unreachable.
# Usage: ai <natural language description>
# Example: ai find all docker volumes not attached to a container

_AI_MODEL="qwen2.5-coder:1.5b"
_AI_REMOTE="caliban:11434"   # Tailscale hostname
_AI_LOCAL="localhost:11434"

_ai_pick_host() {
  if curl -s --connect-timeout 1 "http://${_AI_REMOTE}" > /dev/null 2>&1; then
    echo "$_AI_REMOTE"
  else
    echo "$_AI_LOCAL"
  fi
}

ai() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: ai <describe the command you want>"
    return 1
  fi

  local query="$*"
  local host=$(_ai_pick_host)
  local ctx="OS: $(uname -s), Shell: zsh, CWD: $(pwd)"
  local prompt="Return ONLY a shell command, no explanation, no markdown, no backticks. Context: ${ctx}. Task: ${query} /no_think"

  local result
  result=$(curl -s "http://${host}/api/generate" \
    -d "{\"model\": \"${_AI_MODEL}\", \"prompt\": $(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$prompt"), \"stream\": true, \"keep_alive\": \"60m\"}" \
    | python3 -c "
import json, sys, re
in_think = False
buf = []
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        d = json.loads(line)
    except:
        continue
    chunk = d.get('response', '')
    if '<think>' in chunk:
        in_think = True
    if not in_think:
        buf.append(chunk)
    if '</think>' in chunk:
        in_think = False
        buf = []
result = ''.join(buf).strip()
result = re.sub(r'\`\`\`[a-z]*', '', result).replace('\`', '').strip()
print(result)
")

  if [[ -z "$result" ]]; then
    echo "ai: no response (host: $host, model: $_AI_MODEL)" >&2
    return 1
  fi

  echo "$result"

  # Uncomment to also copy to clipboard:
  # echo "$result" | pbcopy  # macOS
  # echo "$result" | xclip -selection clipboard  # Linux
}
# ---- end ai ----
# Merge the main config + every file in ~/.kube/configs/ into KUBECONFIG.
# Note: a glob can't go straight into the assignment — the RHS of `VAR=...`
# isn't globbed, and KUBECONFIG is colon-separated (globs are space-separated).
# So build an array and join it with ':'. Glob qualifier (.N): regular files
# only, and no error when the dir is empty.
typeset -a _kubeconfigs
_kubeconfigs=( $HOME/.kube/config $HOME/.kube/configs/*(.N) )
export KUBECONFIG="${(j.:.)_kubeconfigs}"
unset _kubeconfigs

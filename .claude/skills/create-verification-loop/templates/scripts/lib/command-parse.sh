# Parsing a Claude Code hook payload, shared by the PreToolUse guards. Source it; it defines
# functions only. No jq or node: in a fresh worktree neither may be on PATH yet.
#
# A guard reads stdin into `payload` first:   IFS= read -r -d '' payload || true
#
#   payload_command    set `cmd` to the Bash command, JSON-decoded, with its data stripped
#                      (quoted strings and heredoc bodies), and `raw_cmd` to it unstripped;
#                      return 1 when the payload has no command
#   payload_field K    print the payload's string field K ("tool_name", "file_path", "cwd")
#   target_checkout    the top of the checkout the payload's cwd is in, else of the current
#                      directory; nothing (return 1) outside any repository
#
# One parser, so a command that only *mentions* something inside quotes or a heredoc body
# (`grep "pnpm install" README.md`, an issue body that says "then gh pr create") is judged
# the same way by every guard: as data, not as a command.

shopt -s extglob
json_string='"(([^"\\]|\\.)*)"'

# Drops what the shell passes as data: quoted strings and heredoc bodies, keeping any $(…) or
# `…` inside double quotes. Context stack, one letter each: c command, s '…', d "…", p (…),
# b `…`. Each step jumps a whole run by regex (bash 3.2's ${s:i:1} is O(i)).
strip_data() {
  local LC_ALL=C rest=$1$'\n' out='' stack=c pending='' nl=$'\n' tab=$'\t' c d k head
  local run_s="^[^']*" run_d="^([^\"\\\\\$\`]|\\\\.)*" run_c="^[^'\"\\\\\`()<$nl]*"
  local heredoc_re="^<<(-?)[[:space:]]*[\\\\\"']?([[:alnum:]_]+)[\"']?"
  while [[ -n $rest ]]; do
    case $stack in
      *s) [[ $rest =~ $run_s ]] ;;
      *d) [[ $rest =~ $run_d ]] ;;
      *) [[ $rest =~ $run_c ]] && out+=${BASH_REMATCH[0]} ;;
    esac
    rest=${rest:${#BASH_REMATCH[0]}}
    c=${rest:0:1} k=1
    case "${stack: -1}$c" in
      "s'" | 'd"') stack=${stack%?} ;;
      'd$') [[ ${rest:1:1} == '(' ]] && stack+=p k=2 ;;
      'd`') stack+=b ;;
      s* | d*) ;;
      *'\') out+=${rest:0:2} k=2 ;;
      *"'") stack+=s ;;
      *'"') stack+=d ;;
      'b`') stack=${stack%?} out+=' ' ;;
      *'`') stack+=b out+=' ' ;;
      *'(') stack+=p out+=$c ;;
      'p)') stack=${stack%?} out+=$c ;;
      *'<')
        if [[ $rest == '<<<'* ]]; then
          out+='<<<' k=3
        elif [[ $rest =~ $heredoc_re ]]; then
          pending+=" ${BASH_REMATCH[1]}${BASH_REMATCH[2]}" out+='<<' k=${#BASH_REMATCH[0]}
        else
          out+=$c
        fi
        ;;
      *"$nl")
        out+=$c
        for d in $pending; do
          if [[ $d == -* ]]; then
            head=${rest%%$nl*($tab)"${d#-}"$nl*}
          else
            head=${rest%%"$nl$d$nl"*}
          fi
          rest=${rest:${#head}+1}
          rest=$nl${rest#*$nl}
        done
        pending=''
        ;;
      *) out+=$c ;;
    esac
    rest=${rest:k}
  done
  printf '%s' "$out"
}

json_decode_into() { # json_decode_into VAR RAW: VAR gets RAW with JSON escapes decoded
  local part out='' value
  local -a parts
  printf -v value '%b.' "$2"
  IFS='"' read -r -d '' -a parts < <(printf '%s' "$value")
  for part in "${parts[@]}"; do out+=${part%\\}\"; done
  printf -v "$1" '%s' "${out%.\"}"
}

payload_command() {
  local command_re="\"command\"[[:space:]]*:[[:space:]]*${json_string}"
  [[ $payload =~ $command_re ]] || return 1
  json_decode_into raw_cmd "${BASH_REMATCH[1]}"
  cmd="$(strip_data "$raw_cmd")"
}

payload_field() {
  # Not `out`: json_decode_into has a local of that name, which would take the value.
  local field_re="\"$1\"[[:space:]]*:[[:space:]]*${json_string}" field_value
  [[ $payload =~ $field_re ]] || return 1
  json_decode_into field_value "${BASH_REMATCH[1]}"
  printf '%s' "$field_value"
}

target_checkout() {
  local cwd top
  if cwd="$(payload_field cwd)" && [ -n "$cwd" ]; then
    top="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" && { echo "$top"; return 0; }
  fi
  git rev-parse --show-toplevel 2>/dev/null
}

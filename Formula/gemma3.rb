# frozen_string_literal: true

class Gemma3 < Formula
  desc "Google Gemma 3 AI with Metal GPU acceleration and friendly chat UI for macOS"
  homepage "https://ai.google.dev/gemma"
  # HEAD-only formula: install via `brew install --HEAD lordhammer11/tap/gemma3`
  head "https://github.com/lordhammer11/homebrew-tap.git", branch: "main"
  license "MIT"
  version "3.1.0"

  bottle :unneeded

  depends_on :macos => :ventura
  depends_on "ollama"

  def install
    # Write the main launcher
    (bin/"gemma3").write <<~BASH
      #!/bin/bash
      exec "#{libexec}/gemma3_chat.py" "$@"
    BASH
    chmod 0755, bin/"gemma3"

    # Write the Python UI script
    (libexec/"gemma3_chat.py").write gemma3_ui_script
    chmod 0755, libexec/"gemma3_chat.py"
  end

  def gemma3_ui_script
    <<~'PYTHON'
      #!/usr/bin/env python3
      """Gemma 3 chat UI — Metal GPU accelerated via Ollama."""

      import os
      import sys
      import subprocess
      import time
      import readline  # noqa: F401  enables history/arrow keys in input()
      from datetime import datetime

      # ── ANSI colours ──────────────────────────────────────────────────────────
      R  = "\033[0m"
      B  = "\033[1m"
      D  = "\033[2m"
      CY = "\033[96m"
      GR = "\033[92m"
      YL = "\033[93m"
      BL = "\033[94m"
      MG = "\033[95m"
      RD = "\033[91m"

      BANNER = f"""
      {CY}{B}
        ╔══════════════════════════════════════════════╗
        ║   Gemma 3  ·  Metal GPU  ·  macOS           ║
        ║   Powered by Ollama  ·  lordhammer11/tap    ║
        ╚══════════════════════════════════════════════╝
      {R}"""

      MODELS = {
          "1": ("gemma3:1b",  "~900 MB",  "Fastest — great for quick tasks"),
          "2": ("gemma3:4b",  "~2.5 GB",  "Balanced ← Recommended"),
          "3": ("gemma3:12b", "~7.5 GB",  "More capable"),
          "4": ("gemma3:27b", "~16 GB",   "Most capable — needs 32 GB RAM"),
      }

      # ── Helpers ───────────────────────────────────────────────────────────────

      def clear():
          os.system("clear")

      def print_banner():
          print(BANNER)

      def ollama_running() -> bool:
          try:
              r = subprocess.run(["ollama", "list"], capture_output=True, timeout=5)
              return r.returncode == 0
          except (FileNotFoundError, subprocess.TimeoutExpired):
              return False

      def start_ollama():
          print(f"{YL}Starting Ollama service…{R}")
          subprocess.Popen(
              ["ollama", "serve"],
              stdout=subprocess.DEVNULL,
              stderr=subprocess.DEVNULL,
          )
          for _ in range(10):
              time.sleep(1)
              if ollama_running():
                  return True
          return False

      def model_present(name: str) -> bool:
          r = subprocess.run(["ollama", "list"], capture_output=True, text=True)
          tag = name if ":" in name else name
          return any(tag in line or name.split(":")[0] in line for line in r.stdout.splitlines())

      def pull_model(name: str) -> bool:
          if model_present(name):
              print(f"{GR}✓ Model {name} already downloaded{R}")
              return True
          print(f"{YL}Downloading {name} — this may take a few minutes…{R}")
          r = subprocess.run(["ollama", "pull", name])
          return r.returncode == 0

      def select_model() -> str:
          print(f"\n{B}Choose a Gemma 3 model:{R}\n")
          for k, (model, size, desc) in MODELS.items():
              print(f"  {CY}[{k}]{R}  {model:<16} {D}{size:<9} {desc}{R}")
          print(f"\n  {D}Press Enter for default (4B){R}")
          choice = input(f"\n{YL}Your choice [1-4]: {R}").strip()
          return MODELS.get(choice, MODELS["2"])[0]

      def print_help():
          print(f"""
      {B}Commands:{R}
        {CY}/help{R}            Show this help
        {CY}/model{R}           Switch model
        {CY}/clear{R}           Clear screen and history
        {CY}/save{R}            Save conversation to a file
        {CY}/system <msg>{R}    Update the system prompt
        {CY}/quit{R}  or Ctrl+C  Exit
      """)

      def save_conversation(history: list, model: str):
          if not history:
              print(f"{D}No conversation to save.{R}\n")
              return
          fname = f"gemma3_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
          with open(fname, "w") as f:
              f.write(f"# Gemma 3 conversation — model: {model}\n\n")
              for msg in history:
                  label = "You" if msg["role"] == "user" else "Gemma 3"
                  f.write(f"{label}:\n{msg['content']}\n\n")
          print(f"{GR}✓ Saved to {fname}{R}\n")

      def run_inference(model: str, history: list, system: str) -> str:
          """Call ollama and return the response text."""
          lines = [f"System: {system}\n"]
          for msg in history:
              label = "User" if msg["role"] == "user" else "Assistant"
              lines.append(f"{label}: {msg['content']}")
          prompt = "\n".join(lines)
          r = subprocess.run(
              ["ollama", "run", model, "--nowordwrap", prompt],
              capture_output=True,
              text=True,
          )
          return r.stdout.strip()

      # ── Main chat loop ─────────────────────────────────────────────────────────

      def chat(model: str) -> str:
          history: list = []
          system = "You are a helpful AI assistant. Be clear and concise."

          print(f"\n{GR}✓ Connected to {model} — Metal GPU active{R}")
          print(f"{D}Type /help for commands. Ctrl+C or /quit to exit.{R}\n")

          while True:
              try:
                  user_input = input(f"{B}{BL}You:{R} ").strip()
              except (EOFError, KeyboardInterrupt):
                  print(f"\n{D}Goodbye!{R}")
                  return "quit"

              if not user_input:
                  continue

              # ── slash commands ──
              if user_input.startswith("/"):
                  parts = user_input.split(" ", 1)
                  cmd = parts[0].lower()

                  if cmd == "/quit":
                      print(f"\n{D}Goodbye!{R}")
                      return "quit"
                  elif cmd == "/help":
                      print_help()
                  elif cmd == "/clear":
                      history = []
                      clear()
                      print_banner()
                      print(f"{GR}✓ Connected to {model} — Metal GPU active{R}")
                      print(f"{D}History cleared.{R}\n")
                  elif cmd == "/model":
                      return "switch"
                  elif cmd == "/save":
                      save_conversation(history, model)
                  elif cmd == "/system" and len(parts) > 1:
                      system = parts[1]
                      print(f"{D}System prompt updated.{R}\n")
                  else:
                      print(f"{D}Unknown command. Type /help for a list.{R}\n")
                  continue

              # ── inference ──
              history.append({"role": "user", "content": user_input})
              print(f"\n{MG}{B}Gemma 3:{R} ", end="", flush=True)

              try:
                  response = run_inference(model, history, system)
              except KeyboardInterrupt:
                  print(f"\n{D}[interrupted]{R}\n")
                  history.pop()
                  continue

              print(response)
              print()
              history.append({"role": "assistant", "content": response})

      # ── Entry point ────────────────────────────────────────────────────────────

      def main():
          clear()
          print_banner()

          # Ensure Ollama is running
          if not ollama_running():
              if not start_ollama():
                  print(
                      f"{RD}Error: Could not start Ollama.\n"
                      f"Run `brew services start ollama` and try again.{R}"
                  )
                  sys.exit(1)

          print(f"{GR}✓ Ollama running — Metal GPU acceleration enabled{R}\n")

          while True:
              model = select_model()

              if not pull_model(model):
                  print(f"{RD}Download failed. Check your internet connection.{R}\n")
                  continue

              clear()
              print_banner()

              result = chat(model)
              if result != "switch":
                  break

      if __name__ == "__main__":
          main()
    PYTHON
  end

  def caveats
    <<~EOS
      Gemma 3 runs via Ollama with Metal GPU acceleration on Apple Silicon.

      First run:
        gemma3

      The launcher will:
        1. Start Ollama if it is not already running
        2. Let you choose a Gemma 3 model size (1B / 4B / 12B / 27B)
        3. Download the model weights on first use
        4. Open an interactive chat UI

      To start Ollama automatically at login:
        brew services start ollama

      Metal GPU notes:
        • Apple Silicon (M1 and later) uses Metal automatically via Ollama.
        • Intel Macs fall back to CPU; performance will be slower.
        • Check GPU usage in Activity Monitor → GPU History.
    EOS
  end

  test do
    assert_predicate bin/"gemma3", :exist?
    assert_predicate libexec/"gemma3_chat.py", :exist?
  end
end

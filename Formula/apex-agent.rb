class ApexAgent < Formula
  desc "Apex Agent — unified daemon for BYOH Mac hosts"
  homepage "https://github.com/danmartell-ventures/apex-agent"
  version "0.1.0"
  license "MIT"

  url "https://github.com/danmartell-ventures/apex-agent/releases/download/v0.1.0/apex-agent_0.1.0_darwin_universal.tar.gz"
  sha256 "5afde5cb13e1c63e77539a542b61e24297dd6fd80631298dde31ba84687ac17f"

  def install
    bin.install "apex-agent"
  end

  test do
    assert_match "apex-agent", shell_output("#{bin}/apex-agent version")
  end
end

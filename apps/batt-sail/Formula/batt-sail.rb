class BattSail < Formula
  desc "Battery sailing and charge limit manager for macOS"
  homepage "https://github.com/USERNAME/batt-sail"
  url "https://github.com/USERNAME/batt-sail/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_REAL_SHA256"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release"
    bin.install ".build/release/batt-sail"
  end

  test do
    assert_match "Battery sailing", shell_output("#{bin}/batt-sail --help")
  end
end

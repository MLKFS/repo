class BattSail < Formula
  desc "Battery sailing and charge limit manager for macOS"
  homepage "https://github.com/MLKFS/repo/tree/main/apps/batt-sail"
  head "https://github.com/MLKFS/repo.git", branch: "main"
  license "MIT"

  depends_on macos: :monterey
  depends_on xcode: ["14.0", :build]

  def install
    cd "apps/batt-sail" do
      system "swift", "build", "-c", "release", "--disable-sandbox"
      bin.install ".build/release/batt-sail"
    end
  end

  test do
    assert_match "Battery sailing", shell_output("#{bin}/batt-sail --help")
  end
end

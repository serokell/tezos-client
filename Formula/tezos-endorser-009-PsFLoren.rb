# SPDX-FileCopyrightText: 2021 TQ Tezos <https://tqtezos.com/>
#
# SPDX-License-Identifier: LicenseRef-MIT-TQ

class TezosEndorser009Psfloren < Formula
  @all_bins = []

  class << self
    attr_accessor :all_bins
  end
  homepage "https://gitlab.com/tezos/tezos"

  url "https://gitlab.com/tezos/tezos.git", :tag => "v9.4", :shallow => false

  version "v9.4-1"

  build_dependencies = %w[pkg-config autoconf rsync wget opam rustup-init]
  build_dependencies.each do |dependency|
    depends_on dependency => :build
  end

  dependencies = %w[gmp hidapi libev libffi]
  dependencies.each do |dependency|
    depends_on dependency
  end

  desc "Daemon for endorsing"

  bottle do
    root_url "https://github.com/serokell/tezos-packaging/releases/download/#{TezosEndorser009Psfloren.version}/"
    sha256 cellar: :any, mojave: "7f2baf83c1ec2b42e59b40e050be7a3b566eb40b82395b95fc5b2887f45af03e"
    sha256 cellar: :any, catalina: "f66162ec30777189ad95156aae9731399d7145b13e1e5a115b5544422624f527"
  end

  def make_deps
    ENV.deparallelize
    ENV["CARGO_HOME"]="./.cargo"
    system "rustup-init", "--default-toolchain", "1.44.0", "-y"
    system "opam", "init", "--bare", "--debug", "--auto-setup", "--disable-sandboxing"
    system ["source .cargo/env",  "make build-deps"].join(" && ")
  end

  def install_template(dune_path, exec_path, name)
    bin.mkpath
    self.class.all_bins << name
    system ["eval $(opam env)", "dune build #{dune_path}", "cp #{exec_path} #{name}"].join(" && ")
    bin.install name
  end


  def install
    startup_contents =
      <<~EOS
      #!/usr/bin/env bash

      set -euo pipefail

      endorser="#{bin}/tezos-endorser-009-PsFLoren"

      endorser_dir="$DATA_DIR"

      endorser_config="$endorser_dir/config"
      mkdir -p "$endorser_dir"

      if [ ! -f "$endorser_config" ]; then
          "$endorser" --base-dir "$endorser_dir" \
                      --endpoint "$NODE_RPC_ENDPOINT" \
                      config init --output "$endorser_config" >/dev/null 2>&1
      else
          "$endorser" --base-dir "$endorser_dir" \
                      --endpoint "$NODE_RPC_ENDPOINT" \
                      config update >/dev/null 2>&1
      fi

      launch_endorser() {
          exec "$endorser" --base-dir "$endorser_dir" \
              --endpoint "$NODE_RPC_ENDPOINT" \
              run "$@"
      }

      if [[ -z "$ENDORSER_ACCOUNT" ]]; then
          launch_endorser
      else
          launch_endorser "$ENDORSER_ACCOUNT"
      fi
    EOS
    File.write("tezos-endorser-009-PsFLoren-start", startup_contents)
    bin.install "tezos-endorser-009-PsFLoren-start"
    make_deps
    install_template "src/proto_009_PsFLoren/bin_endorser/main_endorser_009_PsFLoren.exe",
                     "_build/default/src/proto_009_PsFLoren/bin_endorser/main_endorser_009_PsFLoren.exe",
                     "tezos-endorser-009-PsFLoren"
  end

  plist_options manual: "tezos-endorser-009-PsFLoren run"
  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN"
      "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>Program</key>
          <string>#{opt_bin}/tezos-endorser-009-PsFLoren-start</string>
          <key>EnvironmentVariables</key>
            <dict>
              <key>DATA_DIR</key>
              <string>#{var}/lib/tezos/client</string>
              <key>NODE_RPC_ENDPOINT</key>
              <string>http://localhost:8732</string>
              <key>ENDORSER_ACCOUNT</key>
              <string></string>
          </dict>
          <key>RunAtLoad</key><true/>
          <key>StandardOutPath</key>
          <string>#{var}/log/#{name}.log</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/#{name}.log</string>
        </dict>
      </plist>
    EOS
  end
  def post_install
    mkdir "#{var}/lib/tezos/client"
  end
end

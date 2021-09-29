# SPDX-FileCopyrightText: 2019-2020 TQ Tezos <https://tqtezos.com/>
#
# SPDX-License-Identifier: LicenseRef-MIT-TQ

{ pkgs ? import (import ../nix/nix/sources.nix {}).nixpkgs { } }:
with pkgs;
mkShell {
  buildInputs = [ coreutils gh git rename gnupg ];
}

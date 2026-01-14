{
  description = "The Ultimate tmux Status Bar Framework";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      forAllSystems = function:
        nixpkgs.lib.genAttrs [
          "x86_64-linux"
          "aarch64-linux"
          "x86_64-darwin"
          "aarch64-darwin"
        ]
        (system: function nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        default = pkgs.tmuxPlugins.mkTmuxPlugin {
          pluginName = "tmux-powerkit";
          version = "unstable-2026-01-12";
          src = builtins.path {
            path = ./.;
            name = "source";
          };
          rtpFilePath = "tmux-powerkit.tmux";

          meta = with pkgs.lib; {
            description = "The Ultimate tmux Status Bar Framework";
            longDescription = ''
              A comprehensive status bar framework for tmux with 42 production-ready plugins,
              37 themes with 61 variants, and 9 separator styles. Features smart caching
              with Stale-While-Revalidate lazy loading.
            '';
            homepage = "https://github.com/fabioluciano/tmux-powerkit";
            license = licenses.mit;
            platforms = platforms.unix;
            maintainers = [ ];
          };
        };
      });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          buildInputs = [ pkgs.tmux ];
        };
      });
    };
}

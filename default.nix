{ lib, tmuxPlugins }:

tmuxPlugins.mkTmuxPlugin {
  pluginName = "tmux-powerkit";
  version = "unstable-2026-01-12";

  src = ./.;

  rtpFilePath = "tmux-powerkit.tmux";

  meta = with lib; {
    description = "The Ultimate tmux Status Bar Framework";
    longDescription = ''
      A comprehensive status bar framework for tmux with 42 production-ready plugins,
      32 themes with 56 variants, and 9 separator styles. Features smart caching
      with Stale-While-Revalidate lazy loading.
    '';
    homepage = "https://github.com/fabioluciano/tmux-powerkit";
    license = licenses.mit;
    platforms = platforms.unix;
    maintainers = [ ];
  };
}

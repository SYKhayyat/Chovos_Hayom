{
  description = "A build environment for the Chovos Hayom Linux target.";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          name = "chovos-hayom-linux-build";

          nativeBuildInputs = with pkgs; [
            # `clang` for the compiler, `clang-tools` for what CMake looks for on
            # a path that is not a distro's. `clang-tools` alone is a common
            # mistake: it ships lldb and scan-build, and `clang` is not there.
            clang
            clang-tools
            cmake
            ninja
            pkg-config

            # GTK3, not GTK4: this is a Material 2 app on Flutter's stable Linux
            # embedder, which is a GTK3 client. Choosing GTK4 would be a rewrite
            # of the runner rather than a build flag.
            gtk3
            glib
            cairo
            pango
            libglvnd

            # Not obviously part of "a GTK app", and all three are load-bearing:
            # the Flutter engine's own .so links them, and they are what the
            # missing-symbol and "not found" linker errors are about.
            libepoxy
            fontconfig
            freetype
            libxkbcommon

            # An EGL implementation, and the GL driver behind it. Without these
            # the app builds perfectly and then aborts on the first frame with
            # `No provider of eglGetPlatformDisplayEXT found`, which reads like
            # a Flutter bug and is not one: there is no EGL in the closure at
            # all, so the engine has nothing to open a display with. Mesa also
            # brings llvmpipe, which is what makes this work on a machine with
            # no GPU — the app then runs at a few frames a second, which is
            # plenty for a harness that waits for things to settle.
            mesa
            libGL
          ];

          # **The two lines that make the link work.** nix sets `NIX_LDFLAGS` to
          # the whole closure, and neither CMake nor `ld` reads that name — they
          # read `LDFLAGS`. Without this the build gets all the way to the final
          # link of the runner and then fails on `libepoxy.so.0, needed by
          # libflutter_linux_gtk.so, not found`, because the *prebuilt* engine
          # .so that the Flutter tool downloaded is linked against libraries
          # nothing has told the linker where to find. The message names a
          # library rather than a missing flag, so it reads like a missing
          # package; it is not.
          shellHook = ''
            export LDFLAGS="''${LDFLAGS:-$NIX_LDFLAGS}"

            # Register Mesa as the EGL vendor.
            #
            # libglvnd is the *dispatcher*: it provides eglGetProcAddress and
            # friends, and it finds the real implementation by reading a JSON
            # file in `egl_vendor.d/`. Nobody in this closure drops that file
            # into a place libglvnd looks, so with Mesa merely on the library
            # path the app still aborts with `No provider of
            # eglGetPlatformDisplayEXT found` — the dispatcher is there and has
            # nothing to dispatch to. Pointing the dispatcher straight at Mesa's
            # manifest is the one missing line between "it built" and "it runs".
            export EGL_VENDOR_LIBRARY_FILENAMES="${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
            echo "chovos hayom: linux build shell — clang $(clang --version | head -1 | grep -o '[0-9.]*' | head -1), gtk $(pkg-config --modversion gtk+-3.0)"
          '';
        };
      });
    };
}

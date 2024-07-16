# Informed

_Simplified Distribution of the Inform Ecosystem_

This is not a project you clone so much as you simply download and then use as if it was something you installed. More specifically, you would not want to put any of your specific projects within this project structure. The whole point of this repository is to get you a working installation of the primary Inform ecosystem of tools but without having to go through the process of building all of it from source.

## Inweb

When you have this project on your machine, you will want to get two files in place for your particular operating system. The operating system specific files are in the `_os-specific` directory. You will want to copy the appropriate Inweb program and the appropriate platform makefile for your operating system.

So, for example, if you are on Windows, do the following:

- Copy `inweb.exe` from `_os-specific` to `inweb/Tangled`.
- Copy `platform-settings-WIN.mk` to the root of the `inweb` directory.
- Rename `platform-settings-WIN.mk` to `platform-settings.mk`.

For Mac, you would do the same thing with the relevant files.

Once you have the executable program in place, you will want to make sure that your operating system has the `inweb/Tangled` directory on your `PATH`.

Once you have the Inweb executable on your path, you can have Inweb report where it is executing from.

```shell
inweb -verbose
```

That should provide a directory that matches where you have the executable file.

### External Tooling

Inweb relies on certain tooling to provide artifacts. For example, to generate PDF documentation, you have to have access to `pdftex`. On Windows, if you are using MSYS2, you can get this via the TexLive distribution:

```shell
pacman -S mingw-w64-x86_64-texlive-bin
```

If you aren't using MSYS2, I recommend [MiKTeX](https://miktex.org/).

For Mac, your best bet is to install BasicTeX.

```shell
brew install --cask basictex
```

To generate an ebook, in epub format, you will also need a `zip` program. On Windows, for MSYS2, you can get this easily:

```shell
pacman -S zip
```

If you aren't using MSYS2, you might want to just grab [Zip for Windows](https://gnuwin32.sourceforge.net/packages/zip.htm).

You will likely have this already on a Mac.

## Intest

When you have this project on your machine, you will want to get the executable program in place for your operating system. The operating system specific files are in the `_os-specific` directory. You will want to copy the appropriate Intest program and place it in your `intest/Tangled` directory. Once you have the executable program in place, you will want to make sure that your operating system has the `intest/Tangled` directory on your `PATH`.

To see that it's running, you can try running a test on Inweb:

```shell
intest inweb empy
```

You should see the following result:

```
[1] empty passed
```

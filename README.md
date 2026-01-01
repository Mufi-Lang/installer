# The Official MufiZ Installer

The official installer for the MufiZ programming language.

## 🌐 Website

Visit our installation website for an easy, interactive experience:

**[https://install.mufi-lang.org](https://install.mufi-lang.org)**

The website provides:
- One-click command copying
- Interactive installation guide
- Multiple installation options
- Cross-platform support information

## Installation

### Quick Install

To install MufiZ on Unix systems, run the following command:

```bash
# Install MufiZ and mufizup
curl -fsSL https://install.mufi-lang.org/installer.sh | sudo sh -s install
```

### Alternative Methods

You can also use the raw GitHub URL:

```bash
curl -fsSL https://raw.githubusercontent.com/Mufi-Lang/installer/main/installer.sh | sudo sh -s install
```

### After Installation

After installation, you can use mufizup directly:

```bash
sudo mufizup update           # Update MufiZ to latest version
sudo mufizup remove           # Remove MufiZ and mufizup
sudo mufizup install-version  # Install specific version
sudo mufizup list-versions    # List available versions
```

## Features

- **Easy Installation**: One-command install process
- **Version Management**: Install, update, and switch between versions
- **Clean Removal**: Complete uninstallation when needed
- **Cross-Platform**: Supports Unix, Linux, and macOS
- **Safe**: Backup and restore functionality

## Usage

The installer provides several commands:

- `install` - Install latest MufiZ and MufiZUp
- `update` - Update to latest version  
- `remove` - Uninstall MufiZ completely
- `install-version VER` - Install specific version
- `list-versions` - Show available versions

Example:
```bash
sudo mufizup install-version 0.10.0
```

## GitHub Pages Website

This repository includes a modern, responsive website hosted on GitHub Pages. The website is built with:

- **Static HTML/CSS/JS**: No build process required
- **Responsive Design**: Works on all device sizes
- **Copy-to-Clipboard**: Easy command copying
- **SEO Optimized**: Proper meta tags and structure
- **Fast Loading**: Optimized assets and minimal dependencies

### Website Development

The website source is in the `docs/` directory:

```
docs/
├── index.html     # Main page
├── style.css      # Styles  
├── script.js      # JavaScript
├── installer.sh   # Installer script
└── ...           # Config and other files
```

To develop locally:
1. Navigate to `docs/` directory
2. Serve with any static server: `python -m http.server 8000`
3. Open `http://localhost:8000`

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Test the installer script
5. Submit a pull request

## License

GPL v2.0 - Copyright 2024 MoKa Reads. All rights reserved.
